<#
.SYNOPSIS
Performance comparison of different ways to get unique values from a list.

.DESCRIPTION
Results for a list of 20,000 random numbers (times taken in milliseconds):

Generating random numbers:                   67604

Getting unique numbers via ...
    Sort-Object | Get-Unique:                  433
    Sort-Object -Unique:                       437
    Select-Object -Unique:                    2057
    [Linq.Enumerable]::Distinct() Method:       14

So the LINQ Distinct method is 1-2 orders of magnitude faster than any of the native PowerShell 
methods.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
Version:		1.0.0 
Date:			9 Sep 2020

#>
function Write-Title ([string]$title)
{
    Write-Host $title
    Write-Host ('-' * $title.Length)
}

function InvokeCode ([string]$Description, [scriptblock]$Code, $Arguments)
{
    Write-Host
    $title = "Starting $Description..."
    Write-Title $title

    $result = $null

    $startTime = Get-Date
    $timeTaken = (Get-Date) - $startTime

    try
    {
        $result = Invoke-Command -ScriptBlock $Code -ArgumentList $Arguments
        $timeTaken = (Get-Date) - $startTime
    }
    catch
    {
        Write-Error "$($_.Exception.GetType().Name): $($_.Exception.Message)"
        $timeTaken = (Get-Date) - $startTime
    }
    
    Write-Host
    Write-Host "Time taken: $($timeTaken.TotalMilliseconds) milliseconds"

    return $result
}

function Get-RandomNumberList ([int]$NumberOfItems, [int]$RandomNumberMaximum)
{
    $randomNumbers = @()

    # This uses the .NET System.Random class.
    $randomGenerator = New-object Random
    
    for($i = 1; $i -le $NumberOfItems; $i++)
    {
        $randomNumbers += $randomGenerator.Next(0, $RandomNumberMaximum)
    }

    return $randomNumbers
}

function Write-UniqueNumberList ([string]$Description, [scriptblock]$ScriptBlock, $RandomNumberList)
{
    $uniqueNumbers = InvokeCode -Description $Description -Code $ScriptBlock `
        -Arguments $RandomNumberList

    Write-Host "Number of unique numbers: $($uniqueNumbers.Count)"

    $numberOfItemsToDisplay = 10 
    Write-Host "First $numberOfItemsToDisplay unique items:"
    $uniqueNumbers | Select-Object -First $numberOfItemsToDisplay
}

Clear-Host

$randomNumbers = InvokeCode -Description 'Random number generation' `
    -Code ${function:Get-RandomNumberList} -Arguments 20000,500

Write-Host "Number of random numbers generated: $($randomNumbers.Count)"
        
$numberOfItemsToDisplay = 10 
Write-Host "First $numberOfItemsToDisplay items:"
$randomNumbers | Select-Object -First $numberOfItemsToDisplay

# Enclose argument $RandomNumberList in (, ) to ensure it gets passed as a single argument, 
# and not as an array of multiple arguments.
Write-UniqueNumberList -Description 'Sort-Object | Get-Unique' `
    -ScriptBlock { Param ([array]$RandomNumberList) $RandomNumberList | Sort-Object | Get-Unique } `
    -RandomNumberList (,$randomNumbers)

Write-UniqueNumberList -Description 'Sort-Object -Unique' `
    -ScriptBlock { Param ([array]$RandomNumberList) $RandomNumberList | Sort-Object -Unique } `
    -RandomNumberList (,$randomNumbers)

Write-UniqueNumberList -Description 'Select-Object -Unique' `
    -ScriptBlock { Param ([array]$RandomNumberList) $RandomNumberList | Select-Object -Unique } `
    -RandomNumberList (,$randomNumbers)

# Required for LINQ methods as they need to know the data type of the elements in the list.
# A normal PowerShell array, eg $randomNumbers, is of type object[], which doesn't tell 
# LINQ the types of the elements.
[int[]]$randomInts = $randomNumbers

Write-UniqueNumberList -Description '[Linq.Enumerable]::Distinct' `
    -ScriptBlock { Param ([int[]]$RandomNumberList) [Linq.Enumerable]::Distinct($RandomNumberList) } `
    -RandomNumberList  (,$randomInts)