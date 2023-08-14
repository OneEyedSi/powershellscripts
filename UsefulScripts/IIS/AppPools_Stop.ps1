<#
.SYNOPSIS
Stops the specified IIS app pools on the current server.

.NOTES
This script must be run as administrator.
#>
$appPoolNames = @(
                [PSCustomObject]@{Name='IncidentFormAppPool'}
                [PSCustomObject]@{Name='WebTracking4.0'}
            )

Import-Module webadministration

$initialResults = $appPoolNames | 
    Select-Object Name, `
                @{Name='PreviousState'; Expression={(Get-WebAppPoolState -Name $_.Name).Value}}

$appPoolNames | Stop-WebAppPool

$endResults = $initialResults | 
    Select-Object Name, PreviousState, `
                @{Name='EndState'; Expression={(Get-WebAppPoolState -Name $_.Name).Value}}

Clear-Host
$endResults