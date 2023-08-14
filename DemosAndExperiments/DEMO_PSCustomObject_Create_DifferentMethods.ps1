<#
.SYNOPSIS
Demonstrates different methods of creating a PSCustomObject.

.NOTES
When passing objects through the pipeline by property name we need the upstream object to have 
a property name that matches the property name of the downstream object.  

The upstream object cannot be a hash table as we can't set a property name; we can only set the 
name of a Key.  The property name remains "Key", we're only assigning a value to that property.

Instead of a hash table we can use a PSCustomObject as the upstream object.  That allows us to 
set property names.  

This demonstrates different methods of creating a PSCustomObject.  It is based on 
https://ridicurious.com/2018/10/15/4-ways-to-create-powershell-objects/

RESULT:
The fastest way of creating PSCustomObject is by casting a hash table.  To create a collection 
of objects:

    $objectArray = @()
    $fileNames.ForEach{ $objectArray += [pscustomobject]@{ ChildPath=$_ } }
    $objectArray | Join-Path -Path $directoryPath

#>

function Write-Title ($TitleText)
{
    Write-Host
    Write-Host $TitleText
    Write-Host ("-" * $TitleText.Length)
}

function Write-SingleResult (
    $DirectoryPath, 
    $FileName, 
    [scriptblock]$ScriptBlock, 
    $NumberOfIterations, 
    $Title
    )
{
    Write-Title $Title
    $script:resultantPath = ''

    $startTime = Get-Date
    
    foreach($i in 1..$numberOfIterations) 
    {
        Invoke-Command $ScriptBlock
    }

    $endTime = Get-Date
    $timeTaken = New-TimeSpan -Start $startTime -End $endTime

    Write-Host "Directory: $DirectoryPath"
    Write-Host "File Name: $FileName"
    Write-Host "Resultant Path: $script:resultantPath"
    Write-Host "Time taken: $($timeTaken.TotalMilliseconds) ms"
}

function Write-ArrayResult (
    $DirectoryPath, 
    $FileNameArray, 
    [scriptblock]$ScriptBlock, 
    $NumberOfIterations, 
    $Title
    )
{
    Write-Title $Title
    $script:arrayResult = @()

    $startTime = Get-Date
    
    foreach($i in 1..$numberOfIterations) 
    {
        Invoke-Command $ScriptBlock
    }

    $endTime = Get-Date
    $timeTaken = New-TimeSpan -Start $startTime -End $endTime

    $script:arrayResult
    Write-Host "Time taken: $($timeTaken.TotalMilliseconds) ms"
}

Clear-Host

$directoryPath = 'C:\Temp'
$fileNames = @(
                'Test1.txt'
                'Test2.txt'
                'SubDir\Sub1.txt'
                'SubDir\Sub2.txt'
            )

#region Create a single PSCustomObject ************************************************************
<#
Results for 10000 iterations:

Cast hash table to PsCustomObject
---------------------------------
Time taken: 2534.3086 ms

Create object using New-Object + Add-Member -PassThru
-----------------------------------------------------
Time taken: 4565.3244 ms

Create object via Select-Object
-------------------------------
Time taken: 3661.366 ms

Create object using New-Object -Property <hash table>
------------------------------------------------------
Time taken: 3421.217 ms

So casting a hash table as an object is the quickest.
#>

$numberOfIterations = 10
$fileName = $fileNames[0]

[scriptblock]$scriptBlock = {

    $hashtable = @{ ChildPath=$fileName }
    $object = [pscustomobject]$hashtable

    $script:resultantPath = $object | Join-Path -Path $directoryPath
}
Write-SingleResult $directoryPath $fileName $scriptBlock $numberOfIterations 'Cast hash table to PsCustomObject'

[scriptblock]$scriptBlock = {

    # Need the -PassThru parameter otherwise the Add-Member cmdlet doesn't pass the object 
    # through to the output.
    $object = New-Object PsObject | 
        Add-Member -MemberType NoteProperty -Name ChildPath -Value $fileName -PassThru

    $script:resultantPath = $object | Join-Path -Path $directoryPath
}
Write-SingleResult $directoryPath $fileName $scriptBlock $numberOfIterations 'Create object using New-Object + Add-Member -PassThru'

[scriptblock]$scriptBlock = {

    $object = Select-Object @{ Name='ChildPath'; Expression={$fileName} } -InputObject ''

    $script:resultantPath = $object | Join-Path -Path $directoryPath
}
Write-SingleResult $directoryPath $fileName $scriptBlock $numberOfIterations 'Create object via Select-Object'

[scriptblock]$scriptBlock = {

    $property = @{ ChildPath=$fileName }
    $object = New-Object PsObject -Property $property

    $script:resultantPath = $object | Join-Path -Path $directoryPath
}
Write-SingleResult $directoryPath $fileName $scriptBlock $numberOfIterations 'Create object using New-Object -Property <hash table>'

#endregion

#region Create multiple PSCustomObjects ***********************************************************
<#
Results for 3000 iterations:

Array: Casting each hash table to PsCustomObject
------------------------------------------------
Time taken: 1448.4645 ms

Array: Casting each hash table to PsCustomObject, take 2
--------------------------------------------------------
Time taken: 1237.6002 ms

Array: Create each object using New-Object + Add-Member -PassThru
-----------------------------------------------------------------
Time taken: 3502.8314 ms

Array: Create each object via Select-Object
-------------------------------------------
Time taken: 3058.0381 ms

Array: Create each object using New-Object -Property <hash table>
-----------------------------------------------------------------
Time taken: 3013.0078 ms

So casting a hash table as an object is still the quickest.
Of the two versions that cast a hash table to an object, the one 
that passes the result directly to the pipeline is faster than the 
one that uses the results to populate an array first.
#>
$numberOfIterations = 3000

[scriptblock]$scriptBlock = {

    $objectArray = @()
    $fileNames.ForEach{ $objectArray += [pscustomobject]@{ ChildPath=$_ } }

    $script:arrayResult = $objectArray | Join-Path -Path $directoryPath
}
Write-ArrayResult $directoryPath $fileNames $scriptBlock $numberOfIterations 'Array: Casting each hash table to PsCustomObject'

[scriptblock]$scriptBlock = {

    $script:arrayResult = $fileNames.ForEach{ [pscustomobject]@{ ChildPath=$_ } } | 
        Join-Path -Path $directoryPath
}
Write-ArrayResult $directoryPath $fileNames $scriptBlock $numberOfIterations 'Array: Casting each hash table to PsCustomObject, take 2'

[scriptblock]$scriptBlock = {

    $objectArray = @()
    $fileNames.ForEach{ $objectArray += (New-Object PsObject | Add-Member -MemberType NoteProperty -Name ChildPath -Value $_ -PassThru) }

    $script:arrayResult = $objectArray | Join-Path -Path $directoryPath
}
Write-ArrayResult $directoryPath $fileNames $scriptBlock $numberOfIterations 'Array: Create each object using New-Object + Add-Member -PassThru'

[scriptblock]$scriptBlock = {

    $objectArray = @()

    $fileNames.ForEach{
        $fileName=$_
        $objectArray += (Select-Object @{ Name='ChildPath'; Expression={$fileName} } -InputObject '')
    }

    $script:arrayResult = $objectArray | Join-Path -Path $directoryPath
}
Write-ArrayResult $directoryPath $fileNames $scriptBlock $numberOfIterations 'Array: Create each object via Select-Object'

[scriptblock]$scriptBlock = {

    $objectArray = @()
    $fileNames.ForEach{ $objectArray += (New-Object PsObject -Property @{ ChildPath=$_ }) }

    $script:arrayResult = $objectArray | Join-Path -Path $directoryPath
}
Write-ArrayResult $directoryPath $fileNames $scriptBlock $numberOfIterations 'Array: Create each object using New-Object -Property <hash table>'

#endregion

