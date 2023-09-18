<#
.SYNOPSIS
Demonstrates how care must be taken to avoid unexpected outputs from the Process block.

.DESCRIPTION
The pipeline function converts pipeline output to an array.  However, there is an oversight in the 
Process block: The ArrayList.Add method returns a result (the index of the newly added element) 
and this result is not captured.  The result generated in the Process block is added to the 
function output.  

The end result is that the function doesn't simply convert the output of the pipeline to an array.  
Instead, it creates an array made up of the index values of each element added to the ArrayList, 
plus a final element which is a sub-array, the output of the pipeline converted to an array (the 
expected output).

To avoid this problem assign the result of ArrayList.Add() to a variable or to $null so it isn't 
output from the Process block.

.NOTES
#>

function Convert-PipelineOutputToArray_Bad
{
    Begin
    {
        $arrayList = New-Object System.Collections.ArrayList;
    }
    Process
    {        
        # ArrayList.Add returns the index of the added value.  Since it's not captured it will 
        # be output from the function.  The result is that 
        #   return ,$outputArray 
        # from the End block will return an array where the first n elements are integers, the 
        # indexes of the values added to the ArrayList, and the final element is a sub-array 
        # containing the ArrayList converted to an array.
        $arrayList.Add($_);
    }
    End
    {
        $outputArray = $arrayList.ToArray();
        # Wraps the output in a one-element array to prevent the pipeline from unrolling the 
        # output.  In this case the pipeline will unroll the one-element wrapper array, leaving 
        # the original output array.
        return ,$outputArray;
    }
}

function Convert-PipelineOutputToArray_Fixed
{
    Begin
    {
        $arrayList = New-Object System.Collections.ArrayList;
    }
    Process
    {        
        # ArrayList.Add returns the index of the added value.  Capturing the return value from 
        # ArrayList.Add results in the returned array containing the elements from the ArrayList 
        # and nothing more (as expected).
        $null = $arrayList.Add($_);
    }
    End
    {
        $outputArray = $arrayList.ToArray();
        # Wraps the output in a one-element array to prevent the pipeline from unrolling the 
        # output.  In this case the pipeline will unroll the one-element wrapper array, leaving 
        # the original output array.
        return ,$outputArray;
    }
}

function Write-Title ($TitleText)
{
    Write-Host
    Write-Host $TitleText
    Write-Host ("-" * $TitleText.Length)
}

function Write-Array ($Array)
{
    Write-Host "Number of elements: $($Array.Count)"
    Write-Host "Resultant object type: $($Array.GetType().FullName)"   

    if ($Array -is [array]) 
    { 
        Write-Host  'Result -is [array]: TRUE' 
    } 
    else 
    { 
        Write-Host "Result -is [array]: FALSE" 
    }

    Write-Host
    Write-Host "First element type: $($Array[0].GetType().FullName)"
    Write-Host "First 5 elements:"
    for($i = 0; $i -le 5; $i++)
    {
        Write-Output $Array[$i]
    }

    Write-Host
    Write-Host "Second last element type: $($Array[-2].GetType().FullName)"
    if (-not ($Array[-2] -is [array]))
    {
        Write-Host "Second last element:"
        Write-Output $Array[-2]
    }

    Write-Host
    Write-Host "Last element type: $($Array[-1].GetType().FullName)"
    if ($Array[-1] -is [array])
    {
        $lastElementArray = $Array[-1]
        Write-Host "Last element is array.  Details of that array:"
        Write-Host "Number of elements: $($lastElementArray[0])"
        Write-Host "First element:"
        Write-Output $lastElementArray[0]
    }
    else     
    {
        Write-Host "Last element:"
        Write-Output $Array[-1]
    }
}

Clear-Host

Write-Title 'Bad function that doesn''t capture ArrayList.Add output in Process block'
# Have to exclude service McpManagementService as it results in an error.
$result = Get-Service -Exclude 'McpManagementService' | Convert-PipelineOutputToArray_Bad
Write-Array $result

Write-Title 'Fixed function that captures ArrayList.Add output in Process block'
$result = Get-Service -Exclude 'McpManagementService' | Convert-PipelineOutputToArray_Fixed
Write-Array $result