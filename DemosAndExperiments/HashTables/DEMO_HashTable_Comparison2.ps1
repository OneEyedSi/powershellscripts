<#
.SYNOPSIS
Demonstrates a function that compares two hashtables and returns the differences.
#>

<#
.SYNOPSIS
Compares two hashtables and returns an array of error messages describing the differences.

.DESCRIPTION
Compares two hash tables and returns an array of error messages describing the differences.  If 
there are no differences the array will be empty.

.NOTES
The function only deals with hashtable values of the following data types:
    Value types, such as integers;
    Strings;
    Arrays;
    Hashtables

It specifically cannot deal with values that are reference types, such as objects.  While it can 
deal with values that are arrays, it assumes those arrays do not contain reference types or 
nested hashtables.

.INPUTS
Two hashtables.

.OUTPUTS
An array of strings.
#>
function GetHashTableDifferences (
    [hashtable]$HashTable1,
    [hashtable]$HashTable2, 
    [int]$IndentLevel = 0
)
{
    $spacesPerIndent = 4
    $indentSpaces = ' ' * $spacesPerIndent * $IndentLevel

    if ($HashTable1 -eq $Null)
    {
        if ($HashTable2 -eq $Null)
        {
            return @()
        }
        return @($indentSpaces + 'Hashtable 1 is $Null')
    }
    # HashTable1 must be non-null...
    if ($HashTable2 -eq $Null)
    {
        return @($indentSpaces + 'Hashtable 2 is $Null')
    }
    # Both hashtables are non-null...

    # Reference equality: Both hashtables reference the same hashtable object.
    if ($HashTable1 -eq $HashTable2)
    {
        return @()
    }

    # The two hashtables are not pointing to the same object...

    $returnArray = @()

    # Compare-Object doesn't work on the hashtable.Keys collections.  It assumes all keys in 
    # hashtable 1 are missing from 2 and vice versa.  Compare-Object works properly if the 
    # Keys collections are converted to arrays first.
    # CopyTo will only work if the keys array is created with the right length first.
    $keys1 = @($Null) * $HashTable1.Keys.Count
    $HashTable1.Keys.CopyTo($keys1, 0)
    $keys2 = @($Null) * $HashTable2.Keys.Count
    $HashTable2.Keys.CopyTo($keys2, 0)
    # 
    # Result will be a list of the keys that exist in one hashtable but not the other.  If all 
    # keys match an empty array will be returned.
    $result = Compare-Object -ReferenceObject $keys1 -DifferenceObject $keys2
    if ($result)
    {
        $keysMissingFrom2 = $result | 
            Where-Object {$_.SideIndicator -eq '<='} | 
            Select-Object InputObject -ExpandProperty InputObject
        if ($keysMissingFrom2)
        {            
            $returnArray += "${indentSpaces}Keys missing from hashtable 2: $($keysMissingFrom2 -join ', ')"
        }

        $keysAddedTo2 = $result | 
            Where-Object {$_.SideIndicator -eq '=>'} | 
            Select-Object InputObject -ExpandProperty InputObject
        if ($keysAddedTo2)
        {            
            $returnArray += "${indentSpaces}Keys added to hashtable 2: $($keysAddedTo2 -join ', ')"
        }
    }

    foreach ($key in $HashTable1.Keys)
    {
        $value1 = $hashTable1[$key]
        $typeName1 = $value1.GetType().FullName

        if (-not $HashTable2.ContainsKey($key))
        {
            continue
        }

        $value2 = $HashTable2[$key]
        $typeName2 = $value2.GetType().FullName

        if ($typeName1 -ne $typeName2)
        {
            $returnArray += "${indentSpaces}The data types of key [${key}] differ in the hashtables:  Hashtable 1 data type: $typeName1; Hashtable 2 data type: $typeName2" 
            continue
        }

        # $typeName1 and ...2 are identical, ie the values for the matching keys are of the same 
        # data type in the two hashtables...

        # Compare-Object, at the parent hashtable level, will always assume nested hashtables are 
        # identical, even if they aren't.  So treat nested hashtables as a special case.
        if ($typeName1 -eq 'System.Collections.Hashtable')
        {            
            $nestedHashTableDifferences = GetHashTableDifferences `
                -HashTable1 $value1 -HashTable2 $value2 -IndentLevel ($IndentLevel + 1)
            if ($nestedHashTableDifferences)
            {
                $returnArray += "${indentSpaces}The nested hashtables at key [${key}] differ:"
                $returnArray += $nestedHashTableDifferences
                continue
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
            if ($typeName1 -eq 'System.String')
            {
                $value1 = "'$value1'"
                $value2 = "'$value2'"
            }
            if ($typeName1 -eq 'System.Object[]')
            {
                $value1 = "@($($value1 -join ', '))"
                $value2 = "@($($value2 -join ', '))"
            }
            $returnArray += "${indentSpaces}The values at key [${key}] differ:  Hashtable 1 value: $value1; Hashtable 2 value: $value2"
        }
    }

    return $returnArray
}

Clear-Host

###################################################################################################
# Pester tests:
###################################################################################################
Describe 'GetHashTableDifferences' {
    It 'returns empty array if both hashtables are $Null' {
        GetHashTableDifferences -HashTable1 $Null -HashTable2 $Null | Should -Be @()
    }
    
    It 'returns error message if first hashtable is $Null and the second is not' {
        GetHashTableDifferences -HashTable1 $Null -HashTable2 @{} | Should -Be 'Hashtable 1 is $Null'
    }
    
    It 'returns error message if first hashtable is not $Null and the second is $Null' {
        GetHashTableDifferences -HashTable1 @{} -HashTable2 $Null | Should -Be 'Hashtable 2 is $Null'
    }
    
    It 'returns empty array if both hashtables reference the same object' {
        $ht = @{}
        GetHashTableDifferences -HashTable1 $ht -HashTable2 $ht | Should -Be @()
    }
    
    It 'returns empty array if both hashtables are empty' {
        $ht1 = @{}
        $ht2 = @{}
        GetHashTableDifferences -HashTable1 $ht1 -HashTable2 $ht2 | Should -Be @()
    }
    
    It 'returns error message if hashtable 2 has less keys than hashtable 1' {
        $ht1 = @{one=1; two=2; three=3}
        $ht2 = @{one=1}
        # "three, two", not "two, three" because the keys are sorted in alphabetic order.
        GetHashTableDifferences -HashTable1 $ht1 -HashTable2 $ht2 | Should -Be "Keys missing from hashtable 2: three, two"
    }
    
    It 'returns error message if hashtable 2 has more keys than hashtable 1' {
        $ht1 = @{one=1}
        $ht2 = @{one=1; two=2; three=3}
        GetHashTableDifferences -HashTable1 $ht1 -HashTable2 $ht2 | Should -Be "Keys added to hashtable 2: three, two"
    }
    
    It 'returns multiple error messages if one or more keys differ between the hashtables' {
        $ht1 = @{one=1; three=3; five=5}
        $ht2 = @{two=2; four=4; five=5}
        # Keys listed in alphabetic order.
        GetHashTableDifferences -HashTable1 $ht1 -HashTable2 $ht2 | Should -Be @(
                                                                                "Keys missing from hashtable 2: one, three"
                                                                                "Keys added to hashtable 2: four, two"
                                                                                )
    }
    
    It 'returns error message if matching keys in the two hashtables return different types' {
        $ht1 = @{one=1; two=2; three='3'}
        $ht2 = @{one=1; two='2'; three=3}
        # Keys are checked in alphabetic order.
        GetHashTableDifferences -HashTable1 $ht1 -HashTable2 $ht2 | 
            Should -Be @(
                        "The data types of key [three] differ in the hashtables:  Hashtable 1 data type: System.String; Hashtable 2 data type: System.Int32"
                        "The data types of key [two] differ in the hashtables:  Hashtable 1 data type: System.Int32; Hashtable 2 data type: System.String"
                        )
    }
    
    It 'returns error message if matching keys in the two hashtables return different integer values' {
        $ht1 = @{one=1; two=2; three=30}
        $ht2 = @{one=1; two=20; three=3}
        GetHashTableDifferences -HashTable1 $ht1 -HashTable2 $ht2 | 
            Should -Be @(
                        "The values at key [three] differ:  Hashtable 1 value: 30; Hashtable 2 value: 3"
                        "The values at key [two] differ:  Hashtable 1 value: 2; Hashtable 2 value: 20"
                        )
    }
    
    It 'returns error message if matching keys in the two hashtables return different string values' {
        $ht1 = @{one=1; two='2'; three='30'}
        $ht2 = @{one=1; two='20'; three='3'}
        GetHashTableDifferences -HashTable1 $ht1 -HashTable2 $ht2 |  
            Should -Be @(
                        "The values at key [three] differ:  Hashtable 1 value: '30'; Hashtable 2 value: '3'"
                        "The values at key [two] differ:  Hashtable 1 value: '2'; Hashtable 2 value: '20'"
                        )
    }
    
    It 'returns error message if matching keys in the two hashtables return different array values' {
        $ht1 = @{one=1; two=@(1, 2); three=@(1, 2, 3)}
        $ht2 = @{one=1; two=@(2, 4); three=@(2, 4, 6)}
        GetHashTableDifferences -HashTable1 $ht1 -HashTable2 $ht2 | 
            Should -Be @(
                        "The values at key [three] differ:  Hashtable 1 value: @(1, 2, 3); Hashtable 2 value: @(2, 4, 6)"
                        "The values at key [two] differ:  Hashtable 1 value: @(1, 2); Hashtable 2 value: @(2, 4)"
                        )
    }
    
    It 'returns error message if matching keys in the two hashtables return different hashtable values' {
        $ht1 = @{one=1; two=@{nested1=1; nested2=2}; three=@{nested10=1}}
        $ht2 = @{one=1; two=@{nested1=2; nested2=4}; three=@{nested20=2}}
        GetHashTableDifferences -HashTable1 $ht1 -HashTable2 $ht2 | 
            Should -Be @(
                        "The nested hashtables at key [three] differ:"
                        "    Keys missing from hashtable 2: nested10"
                        "    Keys added to hashtable 2: nested20"
                        "The nested hashtables at key [two] differ:"
                        "    The values at key [nested1] differ:  Hashtable 1 value: 1; Hashtable 2 value: 2"
                        "    The values at key [nested2] differ:  Hashtable 1 value: 2; Hashtable 2 value: 4"
                        )
    }
    
    It 'returns empty array if matching keys in the two hashtables always return the same integer values' {
        $ht1 = @{one=1; two=2}
        $ht2 = @{one=1; two=2}
        GetHashTableDifferences -HashTable1 $ht1 -HashTable2 $ht2 | Should -Be @()
    }
    
    It 'returns empty array if matching keys in the two hashtables always return the same string values' {
        $ht1 = @{one='1'; two='2'}
        $ht2 = @{one='1'; two='2'}
        GetHashTableDifferences -HashTable1 $ht1 -HashTable2 $ht2 | Should -Be @()
    }
    
    It 'returns empty array if matching keys in the two hashtables always return the same array values' {
        $ht1 = @{one=@(1, 2); two=@(2, 4)}
        $ht2 = @{one=@(1, 2); two=@(2, 4)}
        GetHashTableDifferences -HashTable1 $ht1 -HashTable2 $ht2 | Should -Be @()
    }
    
    It 'returns empty array if matching keys in the two hashtables always return the same nested hashtable values' {
        $ht1 = @{one=@{nestedOne=1}; two=@{nestedTwo=2}}
        $ht2 = @{one=@{nestedOne=1}; two=@{nestedTwo=2}}
        GetHashTableDifferences -HashTable1 $ht1 -HashTable2 $ht2 | Should -Be @()
    }
}