<#
.SYNOPSIS
Demonstrates how to create a hashtable with the keys in the order they were added.

.DESCRIPTION
In a hashtable the keys are in an arbitrary order.  However, in a System.Collections.Specialized.OrderedDictionary the keys 
remain in the order they were added to the dictionary/hashtable.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1 or later
Version:		1.0.0 
Date:			9 Feb 2025

Ordered keys are useful if converting a list of hashtables to a CSV file, where the columns have to be in a certain order.

To create an ordered hashtable use the [ordered] type accelerator in the hashtable definition.

Result:
-------

Key order in hashtable:
    Four
    One
    Two
    Three

Key order in ordered hashtable:
    One
    Two
    Three
    Four
#>

Clear-Host

$hashtable = @{}
$hashtable.One = 'One'
$hashtable.Two = 'Two'
$hashtable.Three = 'Three'
$hashtable.Four = 'Four'

Write-Host 'Key order in hashtable:'
foreach($key in $hashtable.Keys)
{
    Write-Host "    $key"
}

Write-Host

$orderedHt = [ordered]@{}
$orderedHt.One = 'One'
$orderedHt.Two = 'Two'
$orderedHt.Three = 'Three'
$orderedHt.Four = 'Four'

Write-Host 'Key order in ordered hashtable:'
foreach($key in $orderedHt.Keys)
{
    Write-Host "    $key"
}