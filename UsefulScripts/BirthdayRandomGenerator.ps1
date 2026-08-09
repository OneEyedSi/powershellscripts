<#
.SYNOPSIS
Generates a random date earlier than the specified most recent date.

.DESCRIPTION
Generates a random date earlier than the specified most recent date.

.NOTES
Author:		Simon Elms
Requires:	PowerShell 5.1
Version:	1.0.0
Date:       4 Aug 2026

#>

$minimumAge = 21
$maximumAge = 65

$today = Get-Date
$earliestDate = $today.AddYears(-$maximumAge)
$latestDate = $today.AddYears(-$minimumAge)
$maxNumberOfDays = ($latestDate - $earliestDate).Days
$randomNumberOfDays = Get-Random -Minimum 0 -Maximum $maxNumberOfDays
$randomDate = $earliestDate.AddDays($randomNumberOfDays)
$randomDateString = $randomDate.ToString('yyyy-MM-dd')
Write-Host "Random date generated: $randomDateString"