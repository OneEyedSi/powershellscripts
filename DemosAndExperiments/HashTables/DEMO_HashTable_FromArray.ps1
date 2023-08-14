<#
.SYNOPSIS
Demonstrates how to populate a hashtable from an array.

.NOTES
#>

function Get-Value (
    [string]$Key
    )
{
    switch ($Key)
    {
        one     { 1 }
        two     { 2 }
        three   { 3 }
        default { 99 }
    }
}

Clear-Host

$a = @('one', 'two', 'three', 'four')
$h = @{}
$a.ForEach{ $h[$_] = Get-Value $_ }
$h