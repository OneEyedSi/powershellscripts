<#
.SYNOPSIS
Lists the details of the IIS App Pools on the local machine. 

.NOTES
Author:			Simon Elms
Version:		1.0.0 
Date:			22 Apr 2022
Requires:		* PowerShell 4.0 or later (confirmed to work with Windows PowerShell 4.0)
                * 'WebAdministration' module.  
                    - This is pre-installed on Windows Server 2012, at least if running the 
                    Web Server role.
                * 'ActiveDirectory' module.  See notes below for installation and uninstallation 
                    instructions.

This script must be run as administrator.  It will throw an error if it isn't.

Based on Stackoverflow answer https://stackoverflow.com/a/42101170/216440, an answer to 
question "Get App Pool Identity for IIS in Power Shell Script", 
https://stackoverflow.com/questions/38898233/get-app-pool-identity-for-iis-in-power-shell-script

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

# -------------------------------------------------------------------------------------------------
# Following line is not a comment, it's a Requires directive.  It will throw an error if the 
# script is not run with Administrator privileges.
#Requires -RunAsAdministrator
# -------------------------------------------------------------------------------------------------

Import-Module WebAdministration

Clear-Host

Get-ChildItem -Path IIS:\AppPools\ | 
    Select-Object name, state, managedRuntimeVersion, managedPipelineMode, 
        @{e={$_.processModel.username};l="username"}, <#@{e={$_.processModel.password};l="password"}, #> 
        @{e={$_.processModel.identityType};l="identityType"}, 
        # processModel.username of form 'DOMAIN\username'.  
        # GetAdUser -Filter does not take usernames in that format.  So strip off the domain from the username and use the result to filter on SamAccountName.
        @{e={if ($_.processModel.identityType -eq 'SpecificUser') {Get-AdUser -Filter "SamAccountName -eq '$($_.processModel.username.Split('\')[1])'" | Select-Object -ExpandProperty ObjectClass}};l="objectClass"} |
    # If we use -AutoSize the final column will be hidden if the PowerShell console window is only 120 characters wide.
    Format-Table 