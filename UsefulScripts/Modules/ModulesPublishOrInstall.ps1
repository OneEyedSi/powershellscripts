<#
.SYNOPSIS
Functions to publish or install modules, primarily to internal PowerShell repositories.

.DESCRIPTION
The functions use the PowerShellGet module.  If that module is not imported this script 
will fail.

.NOTES
The function to install a module must be run under administrator privileges.

Several of the functions in this script will fail if the script is run from behind a 
proxy server.

#>
#$repositoryInfo = @{
#                            Name='PSModules'
#                            # URL is needed to register the repository if it's not already 
#                            # registered.
#                            Url='aaa'
#                            ApiKey='xxxx'
#                        }
$repositoryInfo = @{
                            Name='PSGallery'
                            # Assume PSGallery already registered so no need of the URL.
                            Url=$Null
                            # Get the API key from KeePass > Internet > PowerShell Gallery
                            ApiKey='xxxx'
                        }

# Set either Name or Path, not both.
$moduleToPublish = @{
                        Name='Pslogg'
                        Path='C:\Pslogg_PowerShellLogger\Modules\Pslogg'
                    }

$moduleNameToInstall = 'Pslogg'

$proxyInfo = @{
                    Url='xxx'
                    UserName='yyy'
                }

# -------------------------------------------------------------------------------------------------
# NO NEED TO CHANGE ANYTHING BELOW THIS POINT, THE REMAINDER OF THE CODE IS GENERIC.
# -------------------------------------------------------------------------------------------------

<#
.SYNOPSIS
Ensures that the PowerShellGet module is imported.

.DESCRIPTION
Checks whether the PowerShellGet module is imported and exits the running script with a failure 
code of 2 if it isn't.

If the PowerShellGet module is imported the function will not return any value.
#>
function Test-PowerShellGet ()
{
    $module = (Get-Module -Name PowerShellGet)

    if (-not $module)
    {
        Write-Error 'PowerShellGet module not found.  Exiting.'
        exit 2
    }
}

<#
.SYNOPSIS
Ensures the specified repository is registered, and registers it if it isn't.
#>
function Set-Repository (
    [string]$RepositoryName,
    [string]$RepositoryUrl
    )
{
    # Throws error if try "Get-PSRepository -Name <repo name>" and it doesn't exist so execute 
    # without -Name and check output.
    if (-not (Get-PSRepository).Name -contains $RepositoryName)
    {   
        # ASSUMPTION: That source and publish locations will use the same URL.
        Register-PSRepository -Name $RepositoryName -SourceLocation $RepositoryUrl `
            -PublishLocation $RepositoryUrl -InstallationPolicy Trusted
    }
}

<#
.SYNOPSIS
Checks whether the specified module exists in the specified repository, and publishes it if it 
doesn't.
#>
function Publish-ModuleIfRequired (
    [string]$ModuleName,
    [string]$ModulePath,
    [string]$RepositoryName,
    [string]$RepositoryApiKey
    )
{
    # Throws error if try "Find-Module -Name <module name> -Repository <repo name>" and module 
    # doesn't exist in repository so execute without -Name and check output.
    if (-not (Find-Module -Repository $RepositoryName).Name -contains $ModuleName)
    {    
        Publish-Module -Path $ModulePath -Repository $RepositoryName -NuGetApiKey $RepositoryApiKey
    }    
}

<#
.SYNOPSIS
Checks whether the specified module is already installed and installs it if it isn't.

.DESCRIPTION
If the specified module is not already installed the function will attempt to install it 
assuming it has direct access to the repository.  If that fails it will attempt to install the 
module via a proxy server.

.NOTES
This function to install a module must be run under administrator privileges.

#>
function Install-ModuleIfRequired (
    [string]$ModuleName,
    [string]$RepositoryName, 
    [hashtable]$ProxyInfo
    )
{
    # "Get-InstalledModule -Name <module name>" will throw a non-terminating error if the module 
    # is not installed.  Don't want to display the error so silently continue.
    if (Get-InstalledModule -Name $ModuleName `
        -ErrorAction SilentlyContinue -WarningAction SilentlyContinue)
    {
        return
    }
    
    # Repository probably has too many modules to enumerate them all to find the name.  So call 
    # "Find-Module -Repository $RepositoryName -Name $ModuleName" which will raise a 
    # non-terminating error if the module isn't found.

    # Silently continue on error because the error message isn't user friendly.  We'll display 
    # our own error message if needed.
    if ((Find-Module -Repository $RepositoryName -Name $ModuleName `
        -ErrorAction SilentlyContinue -WarningAction SilentlyContinue).Count -eq 0)
    {
        Write-Error "Module '$ModuleName' not found in repository '$RepositoryName'.  Exiting."
        exit 3
    }
    
    # Errors from Install-Module (eg thrown because it can't connect to the repository because 
    # this script is being run from behind a proxy) are non-terminating.  They won't be caught 
    # using try - catch.  So check $Error instead.

    # Clear errors so we know if one shows up it must have been due to Install-Module.
    $Error.Clear()

    # Want to fail silently, without displaying anything in console to scare the user.  Hence 
    # silently continue.  Have to do it for both errors and warnings because if Install-Module 
    # fails from being called from behind a proxy it will result in a warning as well as an error.
    Install-Module -Name $ModuleName -Repository $RepositoryName `
        -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

    if ($Error.Count -eq 0)
    {
        return
    }

    # There was an error so try again, this time with proxy details.

    $proxyCredential = Get-Credential -Message 'Please enter credentials for proxy server' `
        -UserName $ProxyInfo.UserName

    # No need to Silently Continue this time.  We want to see the error details.
    $Error.Clear()

    Install-Module -Name $ModuleName -Repository $RepositoryName `
        -Proxy $ProxyInfo.Url -ProxyCredential $proxyCredential

    if ($Error.Count -gt 0)
    {
        exit 4
    }

    if (-not (Get-InstalledModule -Name $ModuleName))
    {
        Write-Error "Unknown error installing module '$ModuleName' from repository '$RepositoryName'.  Exiting."
        exit 5
    }

    Write-Output "Module '$ModuleName' successfully installed from repository '$RepositoryName'."
}

Clear-Host

Test-PowerShellGet 

Install-ModuleIfRequired -ModuleName $moduleNameToInstall -RepositoryName $repositoryInfo.Name `
    -ProxyInfo $proxyInfo