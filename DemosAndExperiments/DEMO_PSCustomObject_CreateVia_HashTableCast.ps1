<#
.SYNOPSIS
Demonstrates how to simply convert a hashtable to a PSObject.
#>

Clear-Host

$h = @{one=1; two=2; three=3; four=4; five=5}

$o = [PSCustomObject]$h
$o
$o.GetType().FullName