<#
.SYNOPSIS
Installs the specified module from the specified repository.

.DESCRIPTION
This script will first attempt to install the module assuming it has direct access to the 
internet.  If that fails it will then attempt to install the module via a proxy server.

To avoid alarming the user with warnings and errors if the "direct access" install fails, the 
error and warning preferences will be temporarily changed to silently continue on error and 
warning.

.NOTES
Must be run under administrator privileges.

#>

#$moduleName = 'AssertExceptionThrown'
$moduleName = 'Pslogg'

$repository = 'PSGallery'
$allowClobber = $True

$proxyUrl = 'xxx'
$proxyUserName = 'yyy'

# -------------------------------------------------------------------------------------------------
# NO NEED TO CHANGE ANYTHING BELOW THIS POINT, THE REMAINDER OF THE CODE IS GENERIC.
# -------------------------------------------------------------------------------------------------
# Following line is not a comment, it's a requires directive.  It will throw an error if the 
# script is not run with Administrator privileges.
#Requires -RunAsAdministrator

function Install-ModuleFromRepository (
        [string]$ModuleName,
        [string]$Repository, 
        [string]$ProxyUrl,
        [string]$ProxyUserName,
        [switch]$AllowClobber
    )
{
    # Can't catch any errors from being behind proxy using try - catch because such errors are 
    # non-terminating.  So check $Error instead.

    # Clear errors so know if one shows up it must have been due to Install-Module.
    $Error.Clear()

    # Want to fail silently, without displaying anything in console to scare the user.  Hence 
    # error and warning actions.  Have to do it for both errors and warnings as if Install-Module 
    # fails for being called from behind a proxy it will result in a warning as well as an error.
    Install-Module -Name $ModuleName -Repository $Repository -AllowClobber:$AllowClobber `
        -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

    if ($Error.Count -eq 0)
    {
        return
    }

    $proxyCredentials = Get-Credential -Message 'Please enter credentials for proxy server' `
        -UserName $ProxyUserName

    Install-Module -Name $ModuleName -Repository $Repository -AllowClobber:$AllowClobber `
        -Proxy $ProxyUrl -ProxyCredential $proxyCredentials
}

Install-ModuleFromRepository -ModuleName $moduleName -Repository $repository `
    -ProxyUrl $proxyUrl -ProxyUserName $proxyUserName -AllowClobber:$allowClobber

