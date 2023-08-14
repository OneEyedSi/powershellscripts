function Test-IsNullFalseOrEmpty (
    $ObjectToTest
    )
{
    # Count object indicates whether array or hash table is empty.
    # Length doesn't.  For a hash table Length is always 1, regardless of whether it has 
    # 0, 1 or 100 elements.  To account for objects that don't have a Count property, 
    # check whether the object has a Count property first.
    # NOTE: The -match operator will only work in PowerShell 3+
    # For PowerShell 2 use:
    #     if ($ObjectToTest.PSobject.Properties | where { $_.Name -eq "Count"})
    # Another alternative:
    #    if (Get-Member -InputObject $ObjectToTest -Name "Count" -Membertype Properties)
    if ($ObjectToTest.PSobject.Properties.name -match "Count")
    {
        return ($ObjectToTest.Count -eq 0)
    }

    # Cannot simply use the following test, without the Count test above, because if(object)... 
    # appears to implicitly use the Length property for arrays and hash tables.  And Hash table 
    # Length property will always resolve to 1, ie True.

    # Resolves to false for numerics that are 0, empty strings, $False, $Null.    
    if ($ObjectToTest)
    {
        return $False
    }

    # Return true for numerics <> 0, strings which are non-empty, $True, non-null objects.
    return $True
}

Clear-Host

"Are the following null, false or empty?:"

$a = $Null
$b = Test-IsNullFalseOrEmpty $a
"Null: $b"

$a = $True
$b = Test-IsNullFalseOrEmpty $a
"True: $b"

$a = $False
$b = Test-IsNullFalseOrEmpty $a
"False: $b"

$a = @()
$b = Test-IsNullFalseOrEmpty $a
"Empty Array: $b"

$a = @(1, 2)
$b = Test-IsNullFalseOrEmpty $a
"Non-empty Array: $b"

$a = @{}
$b = Test-IsNullFalseOrEmpty $a
"Empty Hash Table: $b"

$a = @{string="Hello"; int=1}
$b = Test-IsNullFalseOrEmpty $a
"Non-empty Hash Table: $b"

$a = New-Object xml
$b = Test-IsNullFalseOrEmpty $a
"XmlDocument (ie .NET object): $b"