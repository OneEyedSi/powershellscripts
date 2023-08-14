<#
.SYNOPSIS
Lists Windows Services on the local machine along with the accounts they run under.

.NOTES
Author:			Simon Elms
Version:		1.0.0 
Date:			22 Apr 2022
Requires:		PowerShell 4.0 or later (confirmed to work with Windows PowerShell 4.0)
#>
$servicePartialName = 'AP09'

Clear-Host

# Get-CimInstance is the recommended replacement for Get-WmiObject.
Get-CimInstance -classname win32_service -Filter "StartName like '%$($servicePartialName)%'" -Property StartName, DisplayName | 
    Select-Object Name, DisplayName, StartName | 
    Format-Table -AutoSize