<#
.SYNOPSIS
Demonstrates a function that indicates whether two hashtables are identical or not.
#>

<#
.SYNOPSIS
Indicates whether two hashtables are identical or not.

.DESCRIPTION
Compares two hashtables and returns a boolean indicating if they are identical or not.  The 
value is $True if the two hashtables are identical or $False if they are not.

.NOTES
The function only deals with hashtable values of the following data types:
    Value types, such as integers;
    Strings;
    Arrays;
    Hashtables

It specifically cannot deal with values that are reference types, such as objects.  While it can 
deal with hashtable values that are arrays, it assumes those arrays do not contain reference 
types or nested hashtables.

.INPUTS
Two hashtables.

.OUTPUTS
A boolean.
#>
function HashTablesAreIdentical (
    [hashtable]$HashTable1,
    [hashtable]$HashTable2
)
{
    if ($HashTable1 -eq $Null)
    {
        if ($HashTable2 -eq $Null)
        {
            return $True
        }
        return $False
    }
    # HashTable1 must be non-null...
    if ($HashTable2 -eq $Null)
    {
        return $False
    }
    # Both hashtables are non-null...

    # Reference equality: Both hashtables reference the same hashtable object.
    if ($HashTable1 -eq $HashTable2)
    {
        return $True
    }

    # The two hashtables are not pointing to the same object...

    # Result will be a list of the keys that exist in one hashtable but not the other.  If all 
    # keys match an empty array will be returned.
    $result = Compare-Object -ReferenceObject $HashTable1.Keys -DifferenceObject $HashTable2.Keys
    if ($result)
    {
        return $False
    }

    # Both hashtables have the same number of keys...

    foreach ($key in $HashTable1.Keys)
    {
        $value1 = $hashTable1[$key]
        $value2 = $HashTable2[$key]
        $typeName1 = $value1.GetType().FullName
        $typeName2 = $value2.GetType().FullName

        if ($typeName1 -ne $typeName2)
        {
            return $False
        }

        # Compare-Object, at the parent hashtable level, will always assume nested hashtables are 
        # identical, even if they aren't.  So treat nested hashtables as a special case.
        if ($typeName1 -eq 'System.Collections.Hashtable')
        {
            $valueHashTablesAreIdentical = HashTablesAreIdentical `
                -HashTable1 $value1 -HashTable2 $value2
            if (-not $valueHashTablesAreIdentical)
            {
                return $False
            }
        }

        # Arrays, strings and value types can be compared via Compare-Object.
        # ASSUMPTION: That no values are reference types and any arrays do not contain 
        # reference types or hashtables.

        # SyncWindow = 0 ensures arrays will be compared in element order.  If one array is 
        # @(1, 2, 3) and the other is @(3, 2, 1) with SyncWindow = 0 these would be seen as 
        # different.  Leaving out the SyncWindow parameter or setting it to a larger number the 
        # two arrays would be seen as identical.
        $result = Compare-Object -ReferenceObject $value1 -DifferenceObject $value2 -SyncWindow 0
        if ($result)
        {
            return $False
        }
    }

    return $True
}

Clear-Host

###################################################################################################
# Pester tests:
###################################################################################################
Describe 'HashTablesAreIdentical' {
    It 'returns $True if both hashtables are $Null' {
        HashTablesAreIdentical -HashTable1 $Null -HashTable2 $Null | Should -Be $True
    }
    
    It 'returns $False if first hashtable is $Null and the second is not' {
        HashTablesAreIdentical -HashTable1 $Null -HashTable2 @{} | Should -Be $False
    }
    
    It 'returns $False if first hashtable is not $Null and the second is $Null' {
        HashTablesAreIdentical -HashTable1 @{} -HashTable2 $Null | Should -Be $False
    }
    
    It 'returns $True if both hashtables reference the same object' {
        $ht = @{}
        HashTablesAreIdentical -HashTable1 $ht -HashTable2 $ht | Should -Be $True
    }
    
    It 'returns $True if both hashtables are empty' {
        $ht1 = @{}
        $ht2 = @{}
        HashTablesAreIdentical -HashTable1 $ht1 -HashTable2 $ht2 | Should -Be $True
    }
    
    It 'returns $False if the hashtables have different numbers of keys' {
        $ht1 = @{one=1}
        $ht2 = @{one=1; two=2}
        HashTablesAreIdentical -HashTable1 $ht1 -HashTable2 $ht2 | Should -Be $False
    }
    
    It 'returns $False if one or more keys differ between the hashtables' {
        $ht1 = @{one=1; five=5}
        $ht2 = @{two=2; five=5}
        HashTablesAreIdentical -HashTable1 $ht1 -HashTable2 $ht2 | Should -Be $False
    }
    
    It 'returns $False if matching keys in the two hashtables return different types' {
        $ht1 = @{one=1; two=2}
        $ht2 = @{one=1; two='2'}
        HashTablesAreIdentical -HashTable1 $ht1 -HashTable2 $ht2 | Should -Be $False
    }
    
    It 'returns $False if matching keys in the two hashtables return different integer values' {
        $ht1 = @{one=1; two=2}
        $ht2 = @{one=1; two=20}
        HashTablesAreIdentical -HashTable1 $ht1 -HashTable2 $ht2 | Should -Be $False
    }
    
    It 'returns $False if matching keys in the two hashtables return different string values' {
        $ht1 = @{one=1; two='2'}
        $ht2 = @{one=1; two='20'}
        HashTablesAreIdentical -HashTable1 $ht1 -HashTable2 $ht2 | Should -Be $False
    }
    
    It 'returns $False if matching keys in the two hashtables return different array values' {
        $ht1 = @{one=1; two=@(1, 2)}
        $ht2 = @{one=1; two=@(1, 2, 3)}
        HashTablesAreIdentical -HashTable1 $ht1 -HashTable2 $ht2 | Should -Be $False
    }
    
    It 'returns $False if matching keys in the two hashtables return different hashtable values' {
        $ht1 = @{one=1; two=@{nested=1}}
        $ht2 = @{one=1; two=@{nested=2}}
        HashTablesAreIdentical -HashTable1 $ht1 -HashTable2 $ht2 | Should -Be $False
    }
    
    It 'returns $True if matching keys in the two hashtables always return the same integer values' {
        $ht1 = @{one=1; two=2}
        $ht2 = @{one=1; two=2}
        HashTablesAreIdentical -HashTable1 $ht1 -HashTable2 $ht2 | Should -Be $True
    }
    
    It 'returns $True if matching keys in the two hashtables always return the same string values' {
        $ht1 = @{one='1'; two='2'}
        $ht2 = @{one='1'; two='2'}
        HashTablesAreIdentical -HashTable1 $ht1 -HashTable2 $ht2 | Should -Be $True
    }
    
    It 'returns $True if matching keys in the two hashtables always return the same array values' {
        $ht1 = @{one=@(1, 2); two=@(2, 4)}
        $ht2 = @{one=@(1, 2); two=@(2, 4)}
        HashTablesAreIdentical -HashTable1 $ht1 -HashTable2 $ht2 | Should -Be $True
    }
    
    It 'returns $True if matching keys in the two hashtables always return the same nested hashtable values' {
        $ht1 = @{one=@{nestedOne=1}; two=@{nestedTwo=2}}
        $ht2 = @{one=@{nestedOne=1}; two=@{nestedTwo=2}}
        HashTablesAreIdentical -HashTable1 $ht1 -HashTable2 $ht2 | Should -Be $True
    }
}