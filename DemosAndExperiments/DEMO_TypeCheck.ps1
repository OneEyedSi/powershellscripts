<#
.SYNOPSIS
Demonstrates how to check the type of a variable.
#>

function Test-Type($object)
{
    # Can't check array via switch statement as it will loop over each element in the 
    # array instead of checking the array as a whole.
    if ($object -is [array])
    {
        "    It's an array"
    }    
    # Two ways of checking for an array - compare to either [array] or to [object[]].
    if ($object -is [object[]])
    {
        "    It's an object array"
        return
    }
    switch ($object)
    {
        { $_ -is [hashtable] }	{ "    It's a hashtable" }
        { $_ -is [string] }		{ "    It's a string" }
        { $_ -is [int32] }		{ "    It's an int" }
        default					{ "    It's something else" }
    }
}

Clear-Host

Write-Host 'Array object:'
$a = @(1, 2, 3)
Test-Type $a

Write-Host
Write-Host 'Hashtable object:'
$a = @{}
Test-Type $a

Write-Host
Write-Host 'String:'
$a = 'Woteva'
Test-Type $a

Write-Host
Write-Host 'Integer:'
$a = 32
Test-Type $a

Write-Host
Write-Host 'Double:'
$a = 1.234
Test-Type $a

Write-Host