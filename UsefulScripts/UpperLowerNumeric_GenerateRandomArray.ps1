<#
.SYNOPSIS
Generates an array of all the upper & lower case letters plus digits in a random order.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5 or greater (tested on versions 5.1 and 7.2.6)
Version:		1.0.0
Date:			23 Sep 2022
#>

$asciiRanges = @(
                    (48..57),   # Digits
                    (65..90),   # Upper case
                    (97..122)   # Lower case
                )

$asciiList = $asciiRanges[0]
$asciiList += $asciiRanges[1]
$asciiList += $asciiRanges[2]
$sortedList = $asciiList | Foreach-Object {[System.Text.Encoding]::ASCII.GetString($_)}
$randomList = $sortedList | Sort-Object {Get-Random}
$output = ''
$separator = ''
foreach ($char in $randomList)
{
    $output += $separator + "('$char')"
    $separator = ', '
}

Clear-Host
$output
