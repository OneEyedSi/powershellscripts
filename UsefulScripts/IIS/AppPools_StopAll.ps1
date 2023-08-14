<#
.SYNOPSIS
Stops all IIS app pools on the current server.

.NOTES
This script must be run as administrator.

If stopping all app pools and want to restart only those that were previously running, before 
performing the stop, run the following commands from a PowerShell console:

    Import-Module webadministration

    Get-ItemProperty -Path IIS:\AppPools\* | Where-Object { $_.State -eq 'Started' } | Select {"                [PSCustomObject]@{Name='$($_.Name)'}"}

Then paste the results into the $appPoolNames array in the Start-AppPool script.
#>

Import-Module webadministration

$initialResults = Get-ItemProperty -Path IIS:\AppPools\* | 
    Select Name, @{Name='PreviousState'; Expression={$_.State}}

$initialResults | Stop-WebAppPool

$endResults = $initialResults | 
    Select-Object Name, PreviousState, `
                @{Name='EndState'; Expression={(Get-WebAppPoolState -Name $_.Name).Value}}

Clear-Host
$endResults