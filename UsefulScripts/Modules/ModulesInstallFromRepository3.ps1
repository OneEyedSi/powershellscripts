<#
.SYNOPSIS
Installs the specified modules if not already installed.

.DESCRIPTION

.NOTES
Author:			Simon Elms
Requires:		Windows PowerShell 5.1, or cross-platform PowerShell
Version:		1.0.0 
Date:			18 Dec 2024

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
    @{ Name = 'Pester'; MinimumVersion = '5.5.0'; MaximumVersion = '5.6.1' }
    @{ Name = 'Pslogg'; RequiredVersion = '3.1.0' }
)

#endregion Configuration ***************************************************************************************************

#region Functions **********************************************************************************************************

<#
.SYNOPSIS
Copies a specified hashtable.

.DESCRIPTION
Copies a specified hashtable.  It will only copy simple values, such as value types or strings.  It is not able to copy 
values that are reference types.

.NOTES
#>
function Copy-Hashtable ([hashtable]$HashtableToCopy)
{
    if ($Null -eq $HashtableToCopy)
    {
        return $Null
    }
    
    $newHashTable = @{}
    foreach($key in $HashtableToCopy.Keys)
    {
        $newHashTable[$key] = $HashtableToCopy[$key]
    }

    return $newHashTable
}

<#
.SYNOPSIS
Checks whether the specified module is already installed and installs it if it isn't.

.DESCRIPTION
If the specified module is not already installed the function will attempt to install it assuming it has direct access to 
the repository.  If that fails it will attempt to install the module via a proxy server.

If this function installs a module it will be installed for the current user only, not for all users of the computer.

The function accepts input from the pipeline, allowing it to install multiple modules.

.PARAMETER ModuleDetails
A hashtable with the details of the module to be installed.  The hashtable keys must match the parameter names of the 
Install-Module cmdlet.  The following keys must be present in the hashtable:
    1. Name: the name of the module to install.
Any additional keys are optional.  They will be ignored if they do not match parameter names from Install-Module.  

If 'AllowClobber' is added as a key it will be ignored: The function checks if the module is already installed and will 
exit if it is, so there will never be an opportunity to overwrite an existing module.

.PARAMETER RepositoryName
The name of the repository the module will be installed from.

.PARAMETER ProxyUrl
The URL of a proxy server.  This is only required if this script, when run, is behind a proxy server and doesn't have 
direct access to the internet.

.INPUTS
Hashtable

.NOTES
#>
function Install-RequiredModule (

    [Parameter(Mandatory = $true)]
    [string]$RepositoryName, 

    [Parameter(Mandatory = $false)]
    [string]$ProxyUrl,

    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [Hashtable]$ModuleDetails
)
{
    process 
    {
        if (-not $ModuleDetails.ContainsKey('Name'))
        {
            throw "No module name specified.  Exiting."
        }

        $moduleName = $ModuleDetails.Name

        Write-Host "Checking whether PowerShell module '$moduleName' is installed..."

        $installModuleArguments = Copy-Hashtable $ModuleDetails
        if (-not $ModuleDetails.MinimumVersion -and -not $ModuleDetails.MaximumVersion `
            -and -not $ModuleDetails.RequiredVersion)
        {
            $installModuleArguments.AllVersions = $true
        }
        
        $installModuleArguments.ErrorAction = 'SilentlyContinue'
        $installModuleArguments.WarningAction = 'SilentlyContinue'

        # Get-InstalledModule has many of the same parameter names as Install-Module.
        # Get-InstalledModule will throw a non-terminating error if the module is not installed.  
        # Don't want to display the error so silently continue.
        $argumentsToTestInstallation = Copy-Hashtable $installModuleArguments

        if (Get-InstalledModule @argumentsToTestInstallation)
        {
            Write-Host "Module '$moduleName' is installed."
            return
        }
        
        Write-Host "Installing PowerShell module '$moduleName'..."

        $installModuleArguments.Repository = $RepositoryName 

        # Repository probably has too many modules to enumerate them all to find the name.  So call 
        # "Find-Module -Repository $RepositoryName -Name $ModuleName" which will raise a non-terminating error if the 
        # module isn't found.

        # Silently continue on error because the error message isn't user friendly.  We'll display our own error message if 
        # needed.
        if ((Find-Module @installModuleArguments).Count -eq 0)
        {
            throw "Module '$moduleName' not found in repository '$RepositoryName'.  Exiting."
        }

        try
        {
            # Ensure the repository is trusted otherwise the user will get an "untrusted repository" warning message.
            $repositoryInstallationPolicy = (Get-PSRepository -Name $RepositoryName |
                Select-Object -ExpandProperty InstallationPolicy)
            if ($repositoryInstallationPolicy -ne 'Trusted')
            {
                Set-PSRepository -Name $RepositoryName -InstallationPolicy Trusted
            }
        }
        catch 
        {
            throw "Unable to set installation policy for repository '$RepositoryName'.  Exiting."
        }
        
        try
        {     
            # If Install-Module fails because it's behind a proxy we want to fail silently, without displaying any message 
            # to scare the user.  
            # Errors from Install-Module are non-terminating.  They won't be caught using try - catch unless ErrorAction is 
            # set to Stop. 
            $installModuleArguments.ErrorAction = 'Stop'
            $installModuleArguments.Scope = 'CurrentUser'

            Install-Module @installModuleArguments
        }
        catch 
        {
            # Try again, this time with proxy details, if we have them.

            if ([string]::IsNullOrWhiteSpace($ProxyUrl))
            {
                throw "Unable to install module '$moduleName' directly and no proxy server details supplied.  Exiting."
            }

            $proxyCredential = Get-Credential -Message 'Please enter credentials for proxy server'
            $installModuleArguments.Proxy = $ProxyUrl
            $installModuleArguments.ProxyCredential = $proxyCredential

            # No need to Silently Continue this time.  We want to see the error details.  Convert 
            # non-terminating errors to terminating via ErrorAction Stop.   

            Install-Module @installModuleArguments
        }

        if (-not (Get-InstalledModule @argumentsToTestInstallation))
        {
            throw "Unknown error installing module '$moduleName' from repository '$RepositoryName'.  Exiting."
        }

        Write-Host "Module '$moduleName' successfully installed."
    }
}

#endregion Functions *******************************************************************************************************

#region Main script ********************************************************************************************************

$_detailsOfModulesToInstall | Install-RequiredModule -RepositoryName $_moduleRepository -ProxyUrl $_proxyServerUrl

#endregion Main script *****************************************************************************************************