<#
.SYNOPSIS
Demonstrates a pipeline function to convert the output of a pipeline into an array.

.DESCRIPTION
The output of a pipeline can be converted into an array by enclosing the pipeline in @(...).  
However, if the pipeline is long or if you've built it up piece by piece it can be a pain 
to wrap it in @(...).  This pipeline function provides an alternative.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5 or greater
Version:		1.0.0
Date:			17 Aug 2023

Based on PowerShell Team blog post "Converting to Array", 
https://devblogs.microsoft.com/powershell/converting-to-array/

Results are inconclusive with around 350 services listed in the array.  Sometimes one method is 
faster, sometimes another is.

.EXAMPLE
    $a = Get-ChildItem -File | Convert-PipelineOutputToArray_Simple

The other versions of the function are used in the same way.

This is equivalent to:
    $a = @(Get-ChildItem -File)

#>

<#
.SYNOPSIS
Simple version of the pipeline function.

.DESCRIPTION
For very large collections of pipeline objects this will not have good performance since 
$output += $_; creates a new array each time it adds an element.
#>
function Convert-PipelineOutputToArray_Simple
{
    Begin
    {
        $output = @();
    }
    Process
    {
        $output += $_;
    }
    End
    {
        # Wraps the output in a one-element array to prevent the pipeline from unrolling the 
        # output.  In this case the pipeline will unroll the one-element wrapper array, leaving 
        # the original output array.
        return ,$output;
    }
}

function Convert-PipelineOutputToArray_Simple2
{
    Begin
    {
        $output = @();
    }
    Process
    {
        $output += $_;
    }
    End
    {
        return $output;
    }
}

<#
.SYNOPSIS
More efficient version of the pipeline function.

.DESCRIPTION
Add each element to an ArrayList and convert the ArrayList to an array only at the end.
#>
function Convert-PipelineOutputToArray_Performant
{
    Begin
    {
        $arrayList = New-Object System.Collections.ArrayList;
    }
    Process
    {        
        # ArrayList.Add returns the index of the added value.  If not captured it will become an 
        # output of the function.  In that case 
        #   return ,$outputArray; 
        # from the End block will return an array where the first n elements are integers, the 
        # indexes of the values added to the ArrayList, and the final element is a sub-array 
        # containing the ArrayList converted to an array.  Capturing the return value from 
        # ArrayList.Add results in the returned array containing the elements from the ArrayList 
        # and nothing more (as expected).
        $null = $arrayList.Add($_);
    }
    End
    {
        $outputArray = $arrayList.ToArray();
        return ,$outputArray;
    }
}

<#
.SYNOPSIS
Similar to performant version of the pipeline function but doesn't wrap the output in a 
one-element array.

#>
function Convert-PipelineOutputToArray_Performant2
{
    Begin
    {
        $arrayList = New-Object System.Collections.ArrayList;
    }
    Process
    {        
        $null = $arrayList.Add($_);
    }
    End
    {
        $outputArray = $arrayList.ToArray();
        return $outputArray;
    }
}

function Write-Title ($TitleText)
{
    Write-Host
    Write-Host $TitleText
    Write-Host ("-" * $TitleText.Length)
}

function Write-Array ($Array, [datetime]$StartTime)
{
    $endTime = Get-Date
    $duration = $endTime - $StartTime

    Write-Host "Duration: $($duration.TotalSeconds) sec"
    Write-Host "Number of elements: $($Array.Count)"
    Write-Host "Resulting type: $($Array.GetType().FullName)"    
    if ($Array -is [array]) 
    { 
        Write-Host  'Result -is [array]: TRUE' 
    } 
    else 
    { 
        Write-Host "Result -is [array]: FALSE" 
    }
    Write-Host "Element type: $($Array[0].GetType().FullName)"
    Write-Host "First 5 elements:"
    for($i = 0; $i -lt 5; $i++)
    {
        Write-Output $Array[$i]
    }
}

Clear-Host

Write-Title 'Normal way of converting pipeline output to an array'
# Have to exclude service McpManagementService as it results in an error.
$startTime = Get-Date
$result = @(Get-Service -Exclude 'McpManagementService')
Write-Array $result $startTime

Write-Title 'Simple conversion function'
$result = $null
$startTime = Get-Date
$result = Get-Service -Exclude 'McpManagementService' | Convert-PipelineOutputToArray_Simple
Write-Array $result $startTime

Write-Title 'Simple conversion function 2: output not wrapped in one-element array'
$result = $null
$startTime = Get-Date
$result = Get-Service -Exclude 'McpManagementService' | Convert-PipelineOutputToArray_Simple2
Write-Array $result $startTime

Write-Title 'Performant conversion function'
$result = $null
$startTime = Get-Date
$result = Get-Service -Exclude 'McpManagementService' | Convert-PipelineOutputToArray_Performant
Write-Array $result $startTime

Write-Title 'Performant conversion function 2: output not wrapped in one-element array'
$result = $null
$startTime = Get-Date
$result = Get-Service -Exclude 'McpManagementService' | Convert-PipelineOutputToArray_Performant2
Write-Array $result $startTime