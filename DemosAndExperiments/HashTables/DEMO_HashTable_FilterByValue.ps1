<#
.SYNOPSIS
Demonstrates how to filter a hashtable by value.
#>

Clear-Host

$h = @{one=$True; two=$False; three=$True; four=$False; five=$True}

# Doesn't work.  Results are an array of keys, ie strings.
$result = $h.Keys | Where-Object {$h[$_]}
$result.GetType().FullName
$result[0].GetType().FullName
$result

Write-Host

# Also doesn't work.  Returns a collection of custom PSObjects, which is 
# just a list of the keys.
$result = $h.Keys.Where{$h[$_]}
$result.GetType().FullName
$result

Write-Host

# This works.  Results are a different hashtable, filtered.
$result = @{}
$h.Keys | Where-Object {$h[$_]} | ForEach-Object { $result.Add($_, $h[$_])}
$result.GetType().FullName
$result
