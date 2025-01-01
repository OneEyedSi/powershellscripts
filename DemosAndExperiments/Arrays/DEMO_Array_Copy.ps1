<#
.SYNOPSIS
Demonstrates how to copy an array of value types.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
Version:		1.0.0 
Date:			27 Dec 2024

The copy can be updated independently of the original array: the original array will not show the changes made to the copy.
#>

function Copy-Array ([array]$ArrayToCopy)
{    
    return @() + $ArrayToCopy
}

Clear-Host

Write-Host 'Original array:'
$originalArray = @(1, 2, 3, 4)
$originalArray
Write-Host

Write-Host 'Copy:'
$copy = Copy-Array $originalArray
$copy
Write-Host

Write-Host 'Change copy value:'
$copy[2] = 999
$copy
Write-Host

Write-Host 'Original array after copy updated:'
$originalArray
Write-Host

