<#
.SYNOPSIS
Demonstration of attempting to update a supplied array within a function.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
Version:		1.0.0 
Date:			4 Jul 2024
#>

function UpdateArray($array)
{
    Write-Host $array.GetType().FullName
    $array += 99
    Write-Host 'After update inside function'
    $array
}

$array = @(1, 2)
Write-Host 'Before update'
$array

UpdateArray $array
Write-Host 'After update'
$array