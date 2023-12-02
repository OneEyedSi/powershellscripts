<#
.SYNOPSIS
Demonstrates how to get the intersection of two arrays.

.NOTES
Based on Stackoverflow question "Union and Intersection in PowerShell?", 
https://stackoverflow.com/questions/8609204/union-and-intersection-in-powershell

#>

Clear-Host

$firstArray = @(1,2,3,4,5)
$secondArray = @(4,5,6,7,8)

# Will not work if first array is null.
$intersection1 = Compare-Object $firstArray $secondArray -PassThru -IncludeEqual -ExcludeDifferent
$intersection1

$intersection2 = $firstArray | Where-Object { $secondArray -contains $_ }
$intersection2