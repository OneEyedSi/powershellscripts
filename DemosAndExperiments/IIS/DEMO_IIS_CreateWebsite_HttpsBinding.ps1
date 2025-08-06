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
Version:		1.0.0 
Date:			5 Aug 2025

#>

#Requires -RunAsAdministrator
#Requires -Version 5.1
#Requires -Modules @{ ModuleName='IISAdministration'; ModuleVersion='1.1.0.0' }

$physicalPath = 'C:\Working\SourceControl\Smartly\Smartpayroll'
$websiteName = 'Test'
# ASSUMPTION: App pool already exists.
$appPoolName = 'Test'
$bindingInfo = @{ Protocol = 'https'; BindingInformation = '*:4000:' }
[byte[]]$certificateHash = 204,219,71,236,31,111,36,12,228,97,184,227,116,172,225,48,123,184,38,197
$certificateInfo = @{ 
    Name = 'IIS Express Development Certificate'
    StoreName = 'My'
    Hash = $certificateHash
    Thumbprint = 'CCDB47EC1F6F240CE461B8E374ACE1307BB826C5'
}

$addCertificateWithSite = $true

$iisServerManager = Get-IISServerManager

if ($addCertificateWithSite) 
{
    # Works.
    $webSite = $iisServerManager.Sites.Add(
        $websiteName, 
        $bindingInfo.BindingInformation, 
        $physicalPath,
        $certificateInfo.Hash,
        $certificateInfo.StoreName)
}
else
{
    # Doesn't work.
    $webSite = $iisServerManager.Sites.Add(
        $websiteName, 
        $bindingInfo.Protocol, 
        $bindingInfo.BindingInformation, 
        $physicalPath)

    $configuredBinding = $webSite.Bindings[0]
    $configuredBinding.CertificateHash = $certificateInfo.Hash
    $configuredBinding.CertificateStoreName = $certificateInfo.StoreName
}

$rootWebApp = $website.Applications['/']
$rootWebApp.ApplicationPoolName = $appPoolName

$iisServerManager.CommitChanges()

Write-Host 'End'
