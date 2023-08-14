<#
.SYNOPSIS
Starts the specified IIS app pools on the current server.

.NOTES
This script must be run as administrator.

If stopping all app pools and want to restart only those that were previously running, before 
performing the stop, run the following commands from a PowerShell console:

    Import-Module webadministration

    Get-ItemProperty -Path IIS:\AppPools\* | Where-Object { $_.State -eq 'Started' } | Select {"                [PSCustomObject]@{Name='$($_.Name)'}"}

Then paste the results into the $appPoolNames array below.
#>
$appPoolNames = @(
                [PSCustomObject]@{Name='ASP.NET v4.0'}
                [PSCustomObject]@{Name='ASP.NET v4.0 Classic'}
                [PSCustomObject]@{Name='Classic .NET AppPool'}
                [PSCustomObject]@{Name='DefaultAppPool'}
                [PSCustomObject]@{Name='NotificationDetails'}
                [PSCustomObject]@{Name='WebTracking4.0'}
            )

Import-Module webadministration

$initialResults = $appPoolNames | 
    Select-Object Name, `
                @{Name='PreviousState'; Expression={(Get-WebAppPoolState -Name $_.Name).Value}}

$appPoolNames | Start-WebAppPool

$endResults = $initialResults | 
    Select-Object Name, PreviousState, `
                @{Name='EndState'; Expression={(Get-WebAppPoolState -Name $_.Name).Value}}

Clear-Host
$endResults