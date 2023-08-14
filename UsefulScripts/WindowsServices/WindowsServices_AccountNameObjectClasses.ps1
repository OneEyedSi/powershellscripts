<#
.SYNOPSIS
Lists the accounts that Windows Services on the local machine run under, along with the account object class.

.NOTES
Author:			Simon Elms
Version:		1.0.0 
Date:			22 Apr 2022
Requires:		* PowerShell 4.0 or later (confirmed to work with Windows PowerShell 4.0)
                * 'ActiveDirectory' module.  See notes below for installation and uninstallation 
                    instructions.

An object class of 'user' is a regular Windows user account.  
An object class of 'msDS-ManagedServiceAccount' is a Managed Service Account.

WARNING: The ActiveDirectory module is useful for attackers to find information about domain users. 
If you have to install the module to run this script, uninstall it after use.

To install the ActiveDirectory module on Windows Server:
    In a PowerShell window running as Administrator:
        Install-WindowsFeature -Name "RSAT-AD-PowerShell" -IncludeAllSubFeature
    Alternatively, it can be installed via the Server Manager Add Roles and Features wizard: 
        - In Server Manager select Manage menu > Add Roles and Features;
        - In the Add Roles and Features Wizard click Next until you get to the Features page;
        - On the Features page drill down to and select:
                Remote Server Administration Tools
                    Role Administration Tools
                        AD DS and AD LDS Tools
            ----------->    Active Directory module for Windows PowerShell 

To uninstall the ActiveDirectory module on Windows Server:
    It can be uninstalled via Uninstall-WindowsFeature.  However, this requires a server restart.
    Uninstalling via Server Manager is preferred as this does not require a restart:
        - In Server Manager select Manage menu > Remove Roles and Features;
        - In the Remove Roles and Features Wizard click Next until you get to the Features page;
        - On the Features page drill down to and de-select:
                Remote Server Administration Tools
                    Role Administration Tools
                        AD DS and AD LDS Tools
            ----------->    Active Directory module for Windows PowerShell 

#>
$servicePartialName = 'AP09'

Clear-Host

# Get-CimInstance is the recommended replacement for Get-WmiObject.
Get-CimInstance -classname win32_service -Filter "StartName like '%$($servicePartialName)%'" -Property StartName | 
    Select-Object StartName -Unique | 
    ForEach-Object {Get-AdUser -Filter "UserPrincipalName -eq '$($_.StartName)'"} |
    Select-Object UserPrincipalName, ObjectClass