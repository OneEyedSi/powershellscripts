<#
.SYNOPSIS
Rearranges the elements in an array in random order.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5 or greater (tested on versions 5.1 and 7.2.6)
Version:		1.0.0
Date:			23 Sep 2022

From "Easiest way to Shuffle an Array with PowerShell", 
https://ilovepowershell.com/2015/01/24/easiest-way-shuffle-array-powershell/
#>

Clear-Host

#Give me a list - any list will do. Here's 26 numbers.
$MyList = 0..25
Write-Host 'Original array'
$MyList
Write-Host

#Shuffle your array content but keep them in the same array
$MyList = $MyList | Sort-Object {Get-Random}
Write-Host 'Reordered array'
$MyList