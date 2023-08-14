<#
.SYNOPSIS
Determines the quickest way to convert a hashtable Keys collection to an array.

.NOTES
Results: 
    CopyTo method: 53 ms
    For method: 402 ms

So CopyTo is an order of magnitude faster than iterating over the keys.
#>

$ht = @{}
ForEach($i in 0..999) { $ht["$i"] = $i }

$startTime = Get-Date

ForEach($i in 0..999)
{
    $keys1 = @($Null) * $ht.Keys.Count
    $ht.Keys.CopyTo($keys1, 0)
}

$endTime = Get-Date

$timeTaken = $endTime - $startTime

Clear-Host
Write-Host "Time taken: $($timeTaken.Milliseconds) milliseconds"

# ----------------------------------------------------

$startTime = Get-Date

ForEach($i in 0..999)
{
    $keys2 = @($Null) * $ht.Keys.Count
    For($j = 0; $j -lt $keys2.Count; $j++ )
    {
        $keys2[$j] = $ht.Keys[$j]
    }
}

$endTime = Get-Date

$timeTaken = $endTime - $startTime

Write-Host "Time taken: $($timeTaken.Milliseconds) milliseconds"