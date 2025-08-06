<#
.SYNOPSIS
Installs the specified modules if not already installed.

.DESCRIPTION

.NOTES
Author:			Simon Elms
Requires:		Windows PowerShell 5.1, or cross-platform PowerShell
Version:		1.1.0 
Date:			17 Jun 2025

#>

#region Requirements *******************************************************************************************************

# "#Requires" is not a comment, it's a Requires directive.  It will throw an error if the conditions are not met.

# Minimum PowerShell version, not exact version.
#Requires -Version 5.1

#endregion Requirements ****************************************************************************************************

#region Configuration ******************************************************************************************************

$_moduleRepository = 'PSGallery'
$_proxyServerUrl = ''

$_detailsOfModulesToInstall = @(
    @{ ModuleName = 'Pester'; MinimumVersion = '5.5.0'; MaximumVersion = '5.6.1' }
    @{ ModuleName = 'Pslogg'; RequiredVersion = '3.1.0' }
)

#endregion Configuration ***************************************************************************************************

#region Functions **********************************************************************************************************

<#
.SYNOPSIS
Returns a copy of the specified hashtable.

.DESCRIPTION
The function assumes the hashtable to copy contains only value types, nested hashtables or arrays.  It will perform a deep 
copy for those data types.  For reference types it will perform a shallow copy.

.NOTES
#>
function Copy-HashTable ([hashtable]$HashTable)
{
    if ($HashTable -eq $Null)
    {
        return $Null
    }

    if ($HashTable.Keys.Count -eq 0)
    {
        return @{}
    }

    $copy = @{}
    foreach ($key in $HashTable.Keys)
    {
        $value = $HashTable[$key]
        if ($value -is [Collections.Hashtable])
        {
            $copy[$key] = (Copy-HashTable $value)
        }
        else
        {
            # Assumes the value of the hashtable element is a value type, not a reference type.
            # Works also if the value is an array of values types (ie does a deep copy of the array).
            $copy[$key] = $value
        }
    }

    return $copy
}

<#
.SYNOPSIS
Checks whether the specified module is already installed and installs it if it isn't.

.DESCRIPTION
If the specified module is not already installed the function will attempt to install it 
assuming it has direct access to the repository.  If that fails it will attempt to install the 
module via a proxy server.

If this function installs a module it will be installed for the current user only, not for all 
users of the computer.

.NOTES
Cannot include logging in this function because it will be used to install the logging module 
if it's not already installed.
#>
function Install-RequiredModule (
    [Parameter(Position = 0, Mandatory = $true)]
    [string]$RepositoryName,

    [Parameter(Position = 1, Mandatory = $false)]
    [string]$ProxyUrl,

    [Parameter(ValueFromPipeline = $true, Mandatory = $true, ParameterSetName = 'ModuleName')]
    [string]$ModuleName,

    [Parameter(ValueFromPipeline = $true, Mandatory = $true, ParameterSetName = 'ModuleDetails')]
    [hashtable]$ModuleDetails
)
{
    process 
    {
        $moduleText = "'$ModuleName'"
        $moduleVersionInfo = @{}

        if ($ModuleDetails)
        {
            $ModuleName = $ModuleDetails.ModuleName
            $moduleText = "'$ModuleName'"
            $moduleVersionTextPrefix = ' with '

            foreach($key in $ModuleDetails.Keys)
            {
                if ($key -in 'MinimumVersion', 'MaximumVersion', 'RequiredVersion')
                {
                    $moduleVersionInfo[$key] = $ModuleDetails[$key]
                    $moduleText += $moduleVersionTextPrefix + "$key " + $moduleVersionInfo[$key]
                    $moduleVersionTextPrefix = ' and '
                }
            }
        }

        Write-Host "Checking whether PowerShell module $moduleText is installed..."

        # "Get-InstalledModule -Name <module name>" will throw a non-terminating error if the module 
        # is not installed.  Don't want to display the error so silently continue.
        $installedModuleInfo = Get-InstalledModule -Name $ModuleName `
            -ErrorAction 'SilentlyContinue' -WarningAction 'SilentlyContinue' @moduleVersionInfo
        if ($installedModuleInfo)
        {
            Write-Host "Version $($installedModuleInfo.Version) of module '$moduleName' is already installed."
            return
        }

        # A module may not be visible via Get-InstalledModule in PowerShell Core (6+) if it was installed via 
        # PowerShell 5.1.  So try Get-Module as well.
        $getModuleParameters = @{ Name = $ModuleName }
        if ($moduleVersionInfo.Count -gt 0)
        {
            $fullyQualifiedParameters = Copy-HashTable $moduleVersionInfo
            # Unfortunately parameter 'MinimumVersion' for Get-InstalledModule doesn't exist for Get-Module; it's 
            # called 'ModuleVersion' instead (they are exactly equivalent in meaning).
            if ($fullyQualifiedParameters.MinimumVersion)
            {
                $fullyQualifiedParameters.ModuleVersion = $fullyQualifiedParameters.MinimumVersion
                # Get-Module will throw an error if we include a non-existent parameter name, so remove it.
                $fullyQualifiedParameters.Remove('MinimumVersion')
            }
            $fullyQualifiedParameters.ModuleName = $ModuleName
            $getModuleParameters = @{ FullyQualifiedName = $fullyQualifiedParameters }
        }

        $moduleInfo = Get-Module @getModuleParameters -ListAvailable
        if ($moduleInfo)
        {
            Write-Host "Version $($moduleInfo.Version) of module '$moduleName' found."
            return
        }
        
        Write-Host "Installing PowerShell module $moduleText..."

        # Repository probably has too many modules to enumerate them all to find the name.  So call 
        # "Find-Module -Repository $RepositoryName -Name $ModuleName" which will raise a 
        # non-terminating error if the module isn't found.

        # Silently continue on error because the error message isn't user friendly.  We'll display 
        # our own error message if needed.
        if ((Find-Module -Repository $RepositoryName -Name $ModuleName `
                    -ErrorAction 'SilentlyContinue' -WarningAction 'SilentlyContinue' @moduleVersionInfo).Count -eq 0)
        {
            throw "Module $moduleText not found in repository '$RepositoryName'.  Exiting."
        }

        try
        {
            # Ensure the repository is trusted otherwise the user will get an "untrusted repository"
            # warning message.
            $repositoryInstallationPolicy = (Get-PSRepository -Name $RepositoryName |
                Select-Object -ExpandProperty InstallationPolicy)
            if ($repositoryInstallationPolicy -ne 'Trusted')
            {
                Set-PSRepository -Name $RepositoryName -InstallationPolicy Trusted
            }
        }
        catch 
        {
            throw "Module repository '$RepositoryName' not found.  Exiting."
        }

        $optionalInstallParameters = Copy-HashTable $moduleVersionInfo
        if ($moduleVersionInfo.Keys.Count -gt 0)
        {
            # Set the Force and AllowClobber parameters so Install-Module will install the specified version even if there 
            # are previously installed versions.
            $optionalInstallParameters.Force = $true
            $optionalInstallParameters.AllowClobber = $true
        }     
        
        try
        {   
            # If Install-Module fails because it's behind a proxy we want to fail silently, without 
            # displaying any message to scare the user.  
            # Errors from Install-Module are non-terminating.  They won't be caught using try - catch 
            # unless ErrorAction is set to Stop. 
            Install-Module -Name $ModuleName -Repository $RepositoryName `
                -Scope 'CurrentUser' -ErrorAction 'Stop' -WarningAction 'SilentlyContinue' @optionalInstallParameters
        }
        catch 
        {
            # Try again, this time with proxy details, if we have them.

            if ([string]::IsNullOrWhiteSpace($ProxyUrl))
            {
                throw "Unable to install module $moduleText directly and no proxy server details supplied.  Exiting."
            }

            $proxyCredential = Get-Credential -Message 'Please enter credentials for proxy server'

            # No need to Silently Continue this time.  We want to see the error details.  Convert 
            # non-terminating errors to terminating via ErrorAction Stop.   
            Install-Module -Name $ModuleName -Repository $RepositoryName `
                -Proxy $ProxyUrl -ProxyCredential $proxyCredential `
                -Scope 'CurrentUser' -ErrorAction 'Stop' @optionalInstallParameters
        }

        $installedModuleInfo = Get-InstalledModule -Name $ModuleName -ErrorAction 'SilentlyContinue' @moduleVersionInfo

        if (-not $installedModuleInfo)
        {
            throw "Unknown error installing module $moduleText from repository '$RepositoryName'.  Exiting."
        }

        Write-Host "Version $($installedModuleInfo.Version) of module '$moduleName' successfully installed."
    }
}

#endregion Functions *******************************************************************************************************

#region Main script ********************************************************************************************************

# Ensure main script doesn't auto-run when dot sourced into a Pester test script.
if($InTestContext)
{
    return
}

$_detailsOfModulesToInstall | Install-RequiredModule -RepositoryName $_moduleRepository -ProxyUrl $_proxyServerUrl

#endregion Main script *****************************************************************************************************