<#
.SYNOPSIS
Proof of concept for creating a website in IIS with an https binding.

.DESCRIPTION

.NOTES
Author:			Simon Elms
Requires:		* Windows 10 or 11 operating system (NOT Windows Server)
                * Windows PowerShell 5.1 or cross-platform PowerShell 6+, running as Administrator
                * PowerShell modules:
                    - IISAdministration, version 1.1.0.0 or greater
Version:		2.0.0 
Date:			7 Aug 2025

The following methods worked:
    * Add-WebsiteWithCertificate
    * Add-WebsiteThenCertificate4
    * Add-WebsiteWithDynamicInvocation
    * Add-WebsiteWithDynamicInvocation2

All have disadvantages:
    * Add-WebsiteWithCertificate: Have to use two calls to the Sites.Add method, for sites with HTTP and 
        HTTPS bindings.
    * Add-WebsiteThenCertificate4: Creates the site with an HTTPS binding without certificate information.  
        Then removes the binding and re-adds it with the certificate information.  A real hack.
    * Add-WebsiteWithDynamicInvocation: Created an array of arguments, and a matching array of argument types.
        To create websites with HTTP and HTTPS bindings you would have to assemble different arrays, since 
        the order of the arguments is different for HTTP and HTTPS bindings.
    * Add-WebsiteWithDynamicInvocation2: Simplified version of Add-WebsiteWithDynamicInvocation, without 
        explicitly creating the array of argument types.  Still requires different arrays of arguments
        for HTTP and HTTPS bindings.

While I hate to code up two different calls to the Sites.Add method, for HTTPS bindings and for other 
bindings, I don't think the other methods are any better:
    * The dynamic invocation method requires two different arrays of arguments so it's not really any 
        better than the two calls to the Sites.Add method.
    * Removing and re-adding the binding feels hacky and requires about as much extra code as two calls to 
        Sites.Add.
#>

#region Configuration ***************************************************************************************

$physicalPath = 'C:\Temp\TestSite'
$websiteName = 'Test'
# ASSUMPTION: App pool already exists.
$appPoolName = 'Test'
$bindingInfo = @{ Protocol = 'https'; BindingInformation = '*:4000:' }
[byte[]]$certificateHash = 204,219,71,236,31,111,36,12,228,97,184,227,116,172,225,48,123,184,38,197
$certificateInfo = @{ 
    Name = 'IIS Express Development Certificate'
    StoreName = 'My'
    Location = 'Cert:\LocalMachine\My'   
    Hash = $certificateHash
    Thumbprint = 'CCDB47EC1F6F240CE461B8E374ACE1307BB826C5'
}

# Determines which function is called.
[scriptblock]$functionToRun = ${function:AddTwoWebsitesWithDifferentBindings}
# TRAP FOR YOUNG PLAYERS: There cannot be any leading or trailing spaces between the braces and the function.
# For example:
#   [scriptblock]$functionToRun = ${ function:Add-WebsiteWithCertificate }
#                                   ^                                   ^
#                                   ^                                   ^
#   If there are leading and/or trailing spaces the following error is thrown:
#       "You cannot call a method on a null-valued expression."

#endregion Configuration ************************************************************************************

# -----------------------------------------------------------------------------------------------------------
# No changes needed below this point; the remaining code is generic.
# -----------------------------------------------------------------------------------------------------------

#region Requirements ****************************************************************************************

#Requires -RunAsAdministrator
#Requires -Version 5.1
#Requires -Modules @{ ModuleName='IISAdministration'; ModuleVersion='1.1.0.0' }

#endregion Requirements *************************************************************************************

#region Functions *******************************************************************************************

function Add-WebsiteWithCertificate (
    [string]$WebsiteName,
    [string]$PhysicalPath,
    [string]$AppPoolName,
    [hashtable]$BindingInfo,
    [hashtable]$CertificateInfo
) 
{
    # Works but you have to add the certificate information at the time the site is created.
    # This means you can't use the same code for creating websites with an http binding and with an 
    # https binding.
    Write-Host 'Running function Add-WebsiteWithCertificate...'

    $iisServerManager = Get-IISServerManager

    $webSite = $iisServerManager.Sites.Add(
        $WebsiteName, 
        $BindingInfo.BindingInformation, 
        $PhysicalPath,
        $CertificateInfo.Hash,
        $CertificateInfo.StoreName)

    $rootWebApp = $webSite.Applications['/']
    $rootWebApp.ApplicationPoolName = $AppPoolName

    $iisServerManager.CommitChanges()

    Write-Host 'Finished function Add-WebsiteWithCertificate.'
}

function Add-WebsiteThenCertificate (
    [string]$WebsiteName,
    [string]$PhysicalPath,
    [string]$AppPoolName,
    [hashtable]$BindingInfo,
    [hashtable]$CertificateInfo
) 
{
    # Doesn't work.
    Write-Host 'Running function Add-WebsiteThenCertificate...'

    $iisServerManager = Get-IISServerManager

    $webSite = $iisServerManager.Sites.Add(
        $WebsiteName, 
        $bindingInfo.Protocol, 
        $BindingInfo.BindingInformation, 
        $PhysicalPath)

    $configuredBinding = $webSite.Bindings[0]
    $configuredBinding.CertificateHash = $CertificateInfo.Hash
    $configuredBinding.CertificateStoreName = $CertificateInfo.StoreName

    $rootWebApp = $webSite.Applications['/']
    $rootWebApp.ApplicationPoolName = $AppPoolName

    $iisServerManager.CommitChanges()

    Write-Host 'Finished function Add-WebsiteThenCertificate.'
}

function Add-WebsiteThenCertificate2 (
    [string]$WebsiteName,
    [string]$PhysicalPath,
    [string]$AppPoolName,
    [hashtable]$BindingInfo,
    [hashtable]$CertificateInfo
) 
{
    # Doesn't work.  Same as Add-WebsiteThenCertificate but commits the change before adding the certificate.
    Write-Host 'Running function Add-WebsiteThenCertificate2...'

    $iisServerManager = Get-IISServerManager

    $webSite = $iisServerManager.Sites.Add(
        $WebsiteName, 
        $bindingInfo.Protocol, 
        $BindingInfo.BindingInformation, 
        $PhysicalPath)

    $rootWebApp = $webSite.Applications['/']
    $rootWebApp.ApplicationPoolName = $AppPoolName

    $iisServerManager.CommitChanges()

    $configuredBinding = $webSite.Bindings[0]
    $configuredBinding.CertificateHash = $CertificateInfo.Hash
    $configuredBinding.CertificateStoreName = $CertificateInfo.StoreName

    Write-Host 'Finished function Add-WebsiteThenCertificate2.'
}

function Add-WebsiteThenCertificate3 (
    [string]$WebsiteName,
    [string]$PhysicalPath,
    [string]$AppPoolName,
    [hashtable]$BindingInfo,
    [hashtable]$CertificateInfo
) 
{
    # Doesn't work.  Tried using New-IISSiteBinding to overwrite the existing binding to add the certificate.
    Write-Host 'Running function Add-WebsiteThenCertificate3...'

    $iisServerManager = Get-IISServerManager

    $webSite = $iisServerManager.Sites.Add(
        $WebsiteName, 
        $bindingInfo.Protocol, 
        $BindingInfo.BindingInformation, 
        $PhysicalPath)

    $rootWebApp = $webSite.Applications['/']
    $rootWebApp.ApplicationPoolName = $AppPoolName

    $iisServerManager.CommitChanges()

    New-IISSiteBinding -Name $WebsiteName `
        -Protocol $BindingInfo.Protocol `
        -BindingInformation $BindingInfo.BindingInformation `
        -CertificateThumbPrint $CertificateInfo.Thumbprint `
        -CertStoreLocation $CertificateInfo.Location

    Write-Host 'Finished function Add-WebsiteThenCertificate3.'
}

function Add-WebsiteThenCertificate4 (
    [string]$WebsiteName,
    [string]$PhysicalPath,
    [string]$AppPoolName,
    [hashtable]$BindingInfo,
    [hashtable]$CertificateInfo
) 
{
    # Works.  Like Add-WebsiteThenCertificate3 but removes the binding before calling New-IISSiteBinding.
    Write-Host 'Running function Add-WebsiteThenCertificate4...'

    $iisServerManager = Get-IISServerManager

    $webSite = $iisServerManager.Sites.Add(
        $WebsiteName, 
        $bindingInfo.Protocol, 
        $BindingInfo.BindingInformation, 
        $PhysicalPath)

    $rootWebApp = $webSite.Applications['/']
    $rootWebApp.ApplicationPoolName = $AppPoolName

    $iisServerManager.CommitChanges()

    Remove-IISSiteBinding -Name $WebsiteName `
        -Protocol $BindingInfo.Protocol `
        -BindingInformation $BindingInfo.BindingInformation

    New-IISSiteBinding -Name $WebsiteName `
        -Protocol $BindingInfo.Protocol `
        -BindingInformation $BindingInfo.BindingInformation `
        -CertificateThumbPrint $CertificateInfo.Thumbprint `
        -CertStoreLocation $CertificateInfo.Location

    Write-Host 'Finished function Add-WebsiteThenCertificate4.'
}

function Add-WebsiteThenCertificate5 (
    [string]$WebsiteName,
    [string]$PhysicalPath,
    [string]$AppPoolName,
    [hashtable]$BindingInfo,
    [hashtable]$CertificateInfo
) 
{
    # Doesn't work.  Same as Add-WebsiteThenCertificate2 but gets a new instance of ServerManager and 
    # retrieves the website before attempting to update the binding certificate information.
    Write-Host 'Running function Add-WebsiteThenCertificate5...'

    $iisServerManager = Get-IISServerManager

    $webSite = $iisServerManager.Sites.Add(
        $WebsiteName, 
        $bindingInfo.Protocol, 
        $BindingInfo.BindingInformation, 
        $PhysicalPath)

    $rootWebApp = $webSite.Applications['/']
    $rootWebApp.ApplicationPoolName = $AppPoolName

    $iisServerManager.CommitChanges()

    $iisServerManager = Get-IISServerManager

    $webSite = $iisServerManager.Sites[$WebsiteName]

    $configuredBinding = $webSite.Bindings[0]
    $configuredBinding.CertificateHash = $CertificateInfo.Hash
    $configuredBinding.CertificateStoreName = $CertificateInfo.StoreName

    $iisServerManager.CommitChanges()

    Write-Host 'Finished function Add-WebsiteThenCertificate5.'
}

function Add-WebsiteWithDynamicInvocation (
    [string]$WebsiteName,
    [string]$PhysicalPath,
    [string]$AppPoolName,
    [hashtable]$BindingInfo,
    [hashtable]$CertificateInfo
) 
{
    # Works.
    Write-Host 'Running function Add-WebsiteWithDynamicInvocation...'

    $iisServerManager = Get-IISServerManager

    $parameters = @(
        $WebsiteName, 
        $BindingInfo.BindingInformation, 
        $PhysicalPath, 
        $CertificateInfo.Hash, 
        $CertificateInfo.StoreName
    )

    [System.Type[]]$parameterTypes = @(
        [string], 
        [string], 
        [string], 
        [byte[]], 
        [string]
    )

    $iisSites = $iisServerManager.Sites
    $addMethod = $iisSites.GetType().GetMethod('Add', $parameterTypes)
    $webSite = $addMethod.Invoke($iisSites, $parameters)

    $rootWebApp = $webSite.Applications['/']
    $rootWebApp.ApplicationPoolName = $AppPoolName

    $iisServerManager.CommitChanges()

    Write-Host 'Finished function Add-WebsiteWithDynamicInvocation.'
}

function Add-WebsiteWithDynamicInvocation2 (
    [string]$WebsiteName,
    [string]$PhysicalPath,
    [string]$AppPoolName,
    [hashtable]$BindingInfo,
    [hashtable]$CertificateInfo
) 
{
    # Works.  Improved version of Add-WebsiteWithDynamicInvocation. 
    # Gets the types of the parameters dynamically and can create website with HTTPS or HTTP binding.
    Write-Host "Creating $WebsiteName with $($BindingInfo.Protocol) binding..."

    if ($BindingInfo.Protocol -eq 'https')
    {
        # Parameters must be listed in the order expected by the Add method.
        # The order is different for https and http bindings.
        $parameters = @(
            $WebsiteName, 
            $BindingInfo.BindingInformation, 
            $PhysicalPath, 
            $CertificateInfo.Hash, 
            $CertificateInfo.StoreName
        )
    }
    else
    {
        $parameters = @(
            $WebsiteName, 
            $BindingInfo.Protocol, 
            $BindingInfo.BindingInformation, 
            $PhysicalPath
        )
    }

    $iisServerManager = Get-IISServerManager

    [System.Type[]]$parameterTypes = $parameters.ForEach{ $_.GetType() }

    $iisSites = $iisServerManager.Sites
    $addMethod = $iisSites.GetType().GetMethod('Add', $parameterTypes)
    $webSite = $addMethod.Invoke($iisSites, $parameters)

    $rootWebApp = $webSite.Applications['/']
    $rootWebApp.ApplicationPoolName = $AppPoolName

    $iisServerManager.CommitChanges()

    Write-Host "Website $WebsiteName created."
}

# function Add-WebsiteWithDynamicInvocation3 (
#     [string]$WebsiteName,
#     [string]$PhysicalPath,
#     [string]$AppPoolName,
#     [hashtable]$BindingInfo,
#     [hashtable]$CertificateInfo
# ) 
# {
#     # Doesn't work.  Cannot use the splatting operator to pass parameters to a .NET method, apparently.
#     # (despite Gemini claiming it does work).
#     Write-Host "Creating $WebsiteName with $($BindingInfo.Protocol) binding..."

#     $parameters = @{
#         name = $WebsiteName
#         bindingInformation = $BindingInfo.BindingInformation
#         physicalPath = $PhysicalPath
#     }

#     if ($BindingInfo.Protocol -eq 'https')
#     {
#         $parameters.certificateHash = $CertificateInfo.Hash
#         $parameters.certificateStore = $CertificateInfo.StoreName
#     }
#     else
#     {
#         $parameters.bindingProtocol = $BindingInfo.Protocol
#     }

#     $iisServerManager = Get-IISServerManager

#     $webSite = $iisServerManager.Sites.Add(@parameters)

#     $rootWebApp = $webSite.Applications['/']
#     $rootWebApp.ApplicationPoolName = $AppPoolName

#     $iisServerManager.CommitChanges()

#     Write-Host "Website $WebsiteName created."
# }

function AddTwoWebsitesWithDifferentBindings (
    [string]$WebsiteName,
    [string]$PhysicalPath,
    [string]$AppPoolName,
    [hashtable]$BindingInfo,
    [hashtable]$CertificateInfo
) 
{
    Add-WebsiteWithDynamicInvocation2 -WebsiteName $WebsiteName `
        -PhysicalPath $PhysicalPath `
        -AppPoolName $AppPoolName `
        -BindingInfo $BindingInfo `
        -CertificateInfo $CertificateInfo

    $WebsiteName = 'TestHttp'
    $BindingInfo.Protocol = 'http'
    $BindingInfo.BindingInformation = '*:4001:'
    $PhysicalPath = 'C:\Temp\TestHttpSite'

    Add-WebsiteWithDynamicInvocation2 -WebsiteName $WebsiteName `
        -PhysicalPath $PhysicalPath `
        -AppPoolName $AppPoolName `
        -BindingInfo $BindingInfo `
        -CertificateInfo $CertificateInfo
}

#endregion Functions ****************************************************************************************

#region Main Script *****************************************************************************************

$functionToRun.Invoke($websiteName, $physicalPath, $appPoolName, $bindingInfo, $certificateInfo)

#endregion Main Script **************************************************************************************