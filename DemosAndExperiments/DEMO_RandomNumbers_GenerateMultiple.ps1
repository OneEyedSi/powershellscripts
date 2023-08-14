<#
.SYNOPSIS
Demonstrates different ways to generate a range of random numbers.

.DESCRIPTION
Results for generating a list of 10,000 random numbers (times taken in seconds):

For loop - Get-Random:                  33
Range.ForEach() - Get-Random:           34
For loop - .NET Random.Next() method:   27

So using a For loop vs using Range.ForEach() has very little effect, although the For loop seems 
slightly faster.  However, using the .NET Random.Next() method is about 15-20% quicker than using 
Get-Random.
                                        
.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
Version:		1.0.0 
Date:			9 Sep 2020

In PowerShell 7 we could use:
    Get-Random -Count 10000 -Maximum 5000

However, in PowerShell 5.1 the Count parameter is only used to return a specified number of 
elements from a collection in random order, either passing the collection in via the 
pipeline or by using the InputObject parameter.

#>
function ForLoopGetRandom ([int]$NumberOfItems, [int]$RandomNumberMaximum)
{
    $randomNumbers = @()
    for($i = 1; $i -le $NumberOfItems; $i++)
    {
        $randomNumbers += (get-random -Maximum $RandomNumberMaximum)
    }

    return $randomNumbers
}

function RangeGetRandom ([int]$NumberOfItems, [int]$RandomNumberMaximum)
{
    $randomNumbers = @()
    (1..$NumberOfItems).ForEach({$randomNumbers += (get-random -Maximum $RandomNumberMaximum)})

    return $randomNumbers
}

function ForLoopRandomNext ([int]$NumberOfItems, [int]$RandomNumberMaximum)
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

function InvokeFunction ([string]$Description, [scriptblock]$Function, $Arguments)
{
    Write-Host
    $title = "Starting $Description..."
    Write-Host $title
    Write-Host ('-' * $title.Length)

    $randomNumbers = @()

    $startTime = Get-Date
    $timeTaken = (Get-Date) - $startTime

    try
    {
        $randomNumbers = Invoke-Command -ScriptBlock $Function -ArgumentList $Arguments

        $timeTaken = (Get-Date) - $startTime
        
        Write-Host
        Write-Host "Number of random numbers generated: $($randomNumbers.Count)"
        
        $numberOfItemsToDisplay = 10        
        Write-Host
        Write-Host "First $numberOfItemsToDisplay items:"
        $randomNumbers | Select-Object -First $numberOfItemsToDisplay
    }
    catch
    {
        Write-Error "$($_.Exception.GetType().Name): $($_.Exception.Message)"
        $timeTaken = (Get-Date) - $startTime
    }
    
    Write-Host
    Write-Host "Time taken: $($timeTaken.TotalSeconds) seconds"
}

Clear-Host

$arguments = @(10000, 5000)

InvokeFunction -Description 'For loop - Get-Random' `
    -Function ${function:ForLoopGetRandom} -Arguments $arguments

InvokeFunction -Description 'Range.ForEach() - Get-Random' `
    -Function ${function:RangeGetRandom} -Arguments $arguments

InvokeFunction -Description 'For loop - .NET Random.Next() method' `
    -Function ${function:ForLoopRandomNext} -Arguments $arguments