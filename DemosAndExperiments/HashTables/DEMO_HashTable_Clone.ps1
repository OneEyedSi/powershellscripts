<#
.SYNOPSIS
Investigates the fastest way of performing a deep copy on a hash table.

.NOTES
Results: 
    Copy-HashTableViaForEach: 3974.2622 ms
    Copy-HashTableViaCloneMethod: 8883.3608 ms
    Copy-HashTableViaBinarySerialization: 4296.6145 ms
    Copy-HashTableViaJsonSerialization: 18450.8536 ms
    Copy-HashTableViaJavaScriptSerializer: 4869.0457 ms

So deep copying via a foreach loop or via binary serialization is quickest.

These methods assume the hash table values will be either value types or nested hash tables; 
they cannot handle deep copying hash table values which are reference types.
#>

function Write-Title ($TitleText)
{
    Write-Host
    Write-Host $TitleText
    Write-Host ("-" * $TitleText.Length)
}

function Write-HorizontalLine()
{
	Write-Host ("-" * 40)
}

function Get-OrdinalNumber ([ValidateRange(0,[int]::MaxValue)][int]$cardinalNumber)
{
    $cardinalMod100 = $cardinalNumber % 100
    # Floor only works for positive numbers but ValidateRange prevents negatives being passed.
    $isCardinalTeen = if ([math]::floor($cardinalMod100 / 10) -eq 1) { $True } else { $False }

    if ($isCardinalTeen)
    {
        return "${cardinalNumber}th"
    }

    $cardinalMod10 = $cardinalMod100 % 10

    switch ($cardinalMod10)
    {
        1       { return "${cardinalNumber}st" }
        2       { return "${cardinalNumber}nd" }
        3       { return "${cardinalNumber}rd" }
        default { return "${cardinalNumber}th" }       
    }
}

function Get-HashTable(
    [ValidateRange(0,[int]::MaxValue)]
    [int]$lowerBound, 

    [ValidateRange(0,[int]::MaxValue)]
    [int]$upperBound
    )
{
        if ($lowerBound -gt $upperBound)
        {
            throw "Lower bound is greater than upper bound."
        }

        $hashTable = @{}

        $array = $lowerBound..$upperBound
        $array.foreach{$hashTable["$_"] = (Get-OrdinalNumber $_)}

        return $hashTable
}

function Get-HashTableForTest()
{
    $hashTable = Get-HashTable 0 99
    # @(...) array subexpression operator converts the Keys collection to an array.  If not used 
    # an error occurs as we would be enumerating through the hashtable elements and it is not 
    # possible to modify a hashtable while enumerating through it.
    #   See https://stackoverflow.com/a/9710584/216440, answer to question 
    #   "Powershell updating hash table values in a foreach loop?"
    @($hashTable.Keys) | 
        Where-Object { ([convert]::ToInt32($_, 10) % 10) -eq 0 } | 
        ForEach-Object { $hashTable[$_] =  (Get-HashTable 0 5) }

    return $hashTable
}

function Copy-HashTableViaForEach([Collections.Hashtable]$HashTable)
{
    if ($HashTable -eq $Null)
    {
        return $Null
    }

    if ($HashTable.Keys.Count -eq 0)
    {
        return @{}
    }

    $copy = @{}
    foreach($key in $HashTable.Keys)
    {
        if ($HashTable[$key] -is [Collections.Hashtable])
        {
            $copy[$key] = (Copy-HashTableViaForEach $HashTable[$key])
        }
        else
        {
            # Assumes the value of the hash table element is a value type, not a reference type.
			# Works also if the value is an array of values types (ie does a deep copy of the 
			# array).
            $copy[$key] = $HashTable[$key]
        }
    }

    return $copy
}

function Copy-HashTableViaCloneMethod([Collections.Hashtable]$hashTable)
{
    if ($hashTable -eq $Null)
    {
        return $Null
    }

    if ($hashTable.Keys.Count -eq 0)
    {
        return @{}
    }

    $copy = $hashTable.Clone()

    #$hashTable.GetEnumerator() | 
    #    Where-Object { $_.Value -is [Collections.Hashtable] } | 
    #    ForEach-Object { $copy[$_.Key] = Copy-HashTableViaCloneMethod $_.Value }
    
    #$hashTable.Keys.Where({ $hashTable[$_] -is [Collections.Hashtable] }).ForEach({ $copy[$_] = (Copy-HashTableViaCloneMethod $hashTable[$_]) })

    # The two commented statements above proved slower than this statement for copying nested hash tables.
    $hashTable.GetEnumerator().
        Where({ $_.Value -is [Collections.Hashtable] }).
        ForEach({ $copy[$_.Key] = (Copy-HashTableViaCloneMethod $_.Value) })

    return $copy
}

function Copy-HashTableViaBinarySerialization([Collections.Hashtable]$hashTable)
{
    if ($hashTable -eq $Null)
    {
        return $Null
    }

    if ($hashTable.Keys.Count -eq 0)
    {
        return @{}
    }

    $memStream = new-object IO.MemoryStream
    $formatter = new-object Runtime.Serialization.Formatters.Binary.BinaryFormatter
    $formatter.Serialize($memStream, $hashTable)
    $memStream.Position=0
    $copy = [Collections.Hashtable]($formatter.Deserialize($memStream))

    return $copy
}

function Convert-PsCustomObjectToHashTable($psObject)
{
    $hashTable = @{}
    ForEach ($property in $psObject.PsObject.Properties)
    {
        if ($property.Value -is [System.Management.Automation.PSCustomObject])
        {
            $hashTable[$property.Name] = Convert-PsCustomObjectToHashTable $property.Value
        }
        else
        {
            $hashTable[$property.Name] = $property.Value
        }
    }

    return $hashTable 
}

function Copy-HashTableViaJsonSerialization([Collections.Hashtable]$hashTable)
{
    if ($hashTable -eq $Null)
    {
        return $Null
    }

    if ($hashTable.Keys.Count -eq 0)
    {
        return @{}
    }

    $jsonText = ConvertTo-Json $hashTable

    # ConvertFrom-Json doesn't reverse the serialization to JSON.  Instead it deserializes to a 
    # PSCustomObject.
    $psObject = ConvertFrom-Json $jsonText
    $copy = Convert-PsCustomObjectToHashTable $psObject

    return $copy
}

function Copy-HashTableViaJavaScriptSerializer([Collections.Hashtable]$hashTable)
{
    if ($hashTable -eq $Null)
    {
        return $Null
    }

    if ($hashTable.Keys.Count -eq 0)
    {
        return @{}
    }

    $parser = New-Object Web.Script.Serialization.JavaScriptSerializer

    $jsonText = $parser.Serialize($hashTable)

    $parser.MaxJsonLength = $jsonText.Length
    $copy = $parser.Deserialize($jsonText, $hashTable.GetType())

    # Problem: Nested hashtables are copied as Dictionary objects.  Need to convert them.
    $hashTable.GetEnumerator().
        Where({ $_.Value -is [Collections.Hashtable] }).
        ForEach({ $copy[$_.Key] = [Collections.Hashtable]($_.Value) })

    return $copy
}

function Invoke-HashTableCopy ([scriptblock]$function)
{
    $originalHashTable = Get-HashTableForTest

    $hashTableCopy = @{}
    $startTime = Get-Date
    for($i = 1; $i -le 5000; $i++)
    {
        $hashTableCopy = $function.Invoke($originalHashTable)
    }
    $endTime = Get-Date

    $timeTaken = $endTime - $startTime
    return $timeTaken
}

Clear-Host

# Check to make sure that the copy function does a deep copy of values including strings, 
# hashtables and arrays.  
# Result: It does.
$hashTable = @{one="one";two="two";hashtable=@{ht1="one";ht2="two"};array=@("one","two")}
$copy = Copy-HashTableViaForEach $hashTable

Write-Title "Original hash table, before changes:"
$hashTable

$hashTable.one = "1"
$hashTable.Remove("two")
$hashTable["three"] = "three"
$hashTable.hashtable.ht1 = "1"
$hashTable.hashtable.Remove("ht2")
$hashTable.hashtable.ht3 = "three"
$hashTable.array += "three"

Write-Title "Original hash table, modified:"
$hashTable

Write-Title "Copied hash table, hopefully unmodified:"
$copy

Write-Host
Write-HorizontalLine

# Results: 
#    Copy-HashTableViaForEach: 3974.2622 ms
#    Copy-HashTableViaCloneMethod: 8883.3608 ms
#    Copy-HashTableViaBinarySerialization: 4296.6145 ms
#    Copy-HashTableViaJsonSerialization: 18450.8536 ms
#    Copy-HashTableViaJavaScriptSerializer: 4869.0457 ms
Write-Host "Times Taken:"
$timeTaken = Invoke-HashTableCopy ${function:Copy-HashTableViaForEach}
Write-Host "    Copy-HashTableViaForEach: $($timeTaken.TotalMilliseconds) ms"

$timeTaken = Invoke-HashTableCopy ${function:Copy-HashTableViaCloneMethod}
Write-Host "    Copy-HashTableViaCloneMethod: $($timeTaken.TotalMilliseconds) ms"

$timeTaken = Invoke-HashTableCopy ${function:Copy-HashTableViaBinarySerialization}
Write-Host "    Copy-HashTableViaBinarySerialization: $($timeTaken.TotalMilliseconds) ms"

$timeTaken = Invoke-HashTableCopy ${function:Copy-HashTableViaJsonSerialization}
Write-Host "    Copy-HashTableViaJsonSerialization: $($timeTaken.TotalMilliseconds) ms"

$timeTaken = Invoke-HashTableCopy ${function:Copy-HashTableViaJavaScriptSerializer}
Write-Host "    Copy-HashTableViaJavaScriptSerializer: $($timeTaken.TotalMilliseconds) ms"