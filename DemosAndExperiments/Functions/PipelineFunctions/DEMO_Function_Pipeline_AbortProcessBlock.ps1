<#
.SYNOPSIS
Demonstrates how to avoid running the Process block in a pipeline function.

.DESCRIPTION
Performs a check and skips the Process block functionality if the check is false.  The Process 
block is still run for every object passing through the pipeline but the check ensures execution 
jumps out of the Process block immediately.  

.NOTES
Author:			Simon Elms
Requires:		PowerShell 7.3 (not sure if it would work with earlier versions)
Version:		1.0.0 
Date:			16 Aug 2023

Could not find any way to perform the check in the Begin block, and skip running the Process block 
for every object passing through the pipeline.

Reference:
Stackoverflow post 
"Function pipeline how to skip process block? Similar to continue in a foreach loop", 
https://stackoverflow.com/questions/56188038/function-pipeline-how-to-skip-process-block-similar-to-continue-in-a-foreach-lo

#>

function Invoke-PipelineTest1
{
    # Regardless of value of $ValueToCheck, always returns 10.
    param (
        [Parameter(
            Position=0,
            Mandatory=$true)
        ]
        $ValueToCheck,
        
        [Parameter(
            Position=1,
            Mandatory=$true,
            ValueFromPipeline=$true)
        ]
        $PipelineValue
    )

    Begin
    {
        $aggregateValue = $PipelineValue
        if (-not $ValueToCheck)
        {
            return $aggregateValue
        }
    }

    Process
    {
        Start-Sleep -Seconds 1
        $aggregateValue += $PipelineValue
    }

    End
    {
        return $aggregateValue
    }
}

function Invoke-PipelineTest2
{
    param (
        [Parameter(
            Position=0,
            Mandatory=$true)
        ]
        $ValueToCheck,
        
        [Parameter(
            Position=1,
            Mandatory=$true,
            ValueFromPipeline=$true)
        ]
        $PipelineValue
    )

    Begin
    {
        $aggregateValue = $PipelineValue
        if (-not $ValueToCheck)
        {
            continue
        }
    }

    Process
    {
        Start-Sleep -Seconds 1
        $aggregateValue += $PipelineValue
    }

    End
    {
        return $aggregateValue
    }
}

function Invoke-PipelineTest3
{
    # If $ValueToCheck=$true, returns 10.
    # If $ValueToCheck=$false returns $null but still calls the Process block for every pipeline object.
    param (
        [Parameter(
            Position=0,
            Mandatory=$true)
        ]
        $ValueToCheck,
        
        [Parameter(
            Position=1,
            Mandatory=$true,
            ValueFromPipeline=$true)
        ]
        $PipelineValue
    )

    Begin
    {
        $aggregateValue = $PipelineValue
    }

    Process
    {      
        Start-Sleep -Seconds 1
        if (-not $ValueToCheck)
        {
            return 
        } 
        $aggregateValue += $PipelineValue
    }

    End
    {
        return $aggregateValue
    }
}

function Invoke-PipelineTest4
{
    # If $ValueToCheck=$true, returns 10.
    # If $ValueToCheck=$false returns object array with 5 elements, all $null.  Still calls the Process block 
    #   for every pipeline object.
    param (
        [Parameter(
            Position=0,
            Mandatory=$true)
        ]
        $ValueToCheck,
        
        [Parameter(
            Position=1,
            Mandatory=$true,
            ValueFromPipeline=$true)
        ]
        $PipelineValue
    )

    Begin
    {
        $aggregateValue = $PipelineValue
    }

    Process
    {       
        Start-Sleep -Seconds 1
        if (-not $ValueToCheck)
        {
            return $aggregateValue
        } 
        $aggregateValue += $PipelineValue
    }

    End
    {
        return $aggregateValue
    }
}

function Invoke-PipelineTest5
{
    # If $ValueToCheck=$true, returns 10.
    # If $ValueToCheck=$false returns object array with 5 elements, all $null.  Still calls the Process block 
    #   for every pipeline object.
    param (
        [Parameter(
            Position=0,
            Mandatory=$true)
        ]
        $ValueToCheck,
        
        [Parameter(
            Position=1,
            Mandatory=$true,
            ValueFromPipeline=$true)
        ]
        $PipelineValue
    )

    Begin
    {
        $aggregateValue = $PipelineValue        
        if (-not $ValueToCheck)
        {
            break
        }
    }

    Process
    {       
        Start-Sleep -Seconds 1
        $aggregateValue += $PipelineValue
    }

    End
    {
        return $aggregateValue
    }
}

function Invoke-PipelineTest6
{
    # If $ValueToCheck=$true, returns 10.
    # If $ValueToCheck=$false aborts execution of script.
    param (
        [Parameter(
            Position=0,
            Mandatory=$true)
        ]
        $ValueToCheck,
        
        [Parameter(
            Position=1,
            Mandatory=$true,
            ValueFromPipeline=$true)
        ]
        $PipelineValue
    )

    Begin
    {
        $aggregateValue = $PipelineValue
    }

    Process
    {       
        Start-Sleep -Seconds 1
        if (-not $ValueToCheck)
        {
            continue 
        } 
        $aggregateValue += $PipelineValue
    }

    End
    {
        return $aggregateValue
    }
}

function Invoke-PipelineTest7
{
    # Attempts to aggregate the values received from the pipeline but throws if the value is 3.
    param (
        [Parameter(
            Position=0,
            Mandatory=$true,
            ValueFromPipeline=$true)
        ]
        $PipelineValue
    )

    Begin
    {
        $aggregateValue = $PipelineValue
    }

    Process
    {       
        if ($PipelineValue -eq 3)
        {
            throw "Throwing on 3"
        } 

        $aggregateValue += $PipelineValue
    }

    End
    {
        return $aggregateValue
    }
}

function Write-Title ($Title)
{
    Write-Host
    Write-Host $Title
    Write-Host ('-' * ($Title.Length))
}

function Write-Duration ($StartTime)
{
    $endTime = Get-Date
    $duration = $endTime - $StartTime
    Write-Host "Duration: $($duration.TotalSeconds) sec"
}

function Write-Result($Result)
{
    if($null -eq $Result)
    {
        Write-Host 'RESULT -eq NULL'
    }
    else 
    {
        Write-Host "Result type: $($Result.GetType().Name)"
    }

    if ($Result)
    {
        Write-Host 'if($result) is TRUE'
        Write-Host '$result:'
        $Result
        if($null -eq $Result)
        {
            Write-Host 'RESULT IS NULL'
        }
    }
    else
    {
        Write-Host 'if($result) is FALSE'
    }
}

Clear-Host

Write-Title 'TEST 1:'
Write-Host 'Should process each pipeline object, returning 10:'
$startTime = Get-Date
1..4 | Invoke-PipelineTest1 $true
Write-Duration $startTime
Write-Host 'Doesn''t short-circuit, still returns 10:'
$startTime = Get-Date
1..4 | Invoke-PipelineTest1 $false
Write-Duration $startTime

# Had to comment this out since it kills execution - TEST 3 never runs after TEST 2 runs with parameter $false.
# Write-Title 'TEST 2:'
# Write-Host 'Should process each pipeline object, returning 10:'
# 1..4 | Invoke-PipelineTest2 $true
# Write-Host 'Terminates execution:'
# $result = (1..4 | Invoke-PipelineTest2 $false)
# if ($result)
# {
#     $result
# }
# else
# {
#     Write-Host 0
#     Write-Host '(result wasn''t set)'
# }

Write-Title 'TEST 3:'
Write-Host 'Should process each pipeline object, returning 10:'
$startTime = Get-Date
$result = (1..4 | Invoke-PipelineTest3 $true)
$result
Write-Duration $startTime
Write-Host 'Doesn''t short-circuit, still executes Process for every pipeline object.'
Write-Host 'But returns $null instead of the aggregated value.'
$startTime = Get-Date
$result = (1..4 | Invoke-PipelineTest3 $false)
Write-Result $result
Write-Duration $startTime

Write-Title 'TEST 4:'
Write-Host 'Should process each pipeline object, returning 10:'
$startTime = Get-Date
$result = (1..4 | Invoke-PipelineTest4 $true)
$result
Write-Duration $startTime
Write-Host 'Doesn''t short-circuit, still executes Process for every pipeline object.'
Write-Host 'But returns an array of NULL objects instead of the aggregated value.'
$startTime = Get-Date
$result = (1..4 | Invoke-PipelineTest4 $false)
Write-Result $result
Write-Duration $startTime
for($i = 0; $i -lt $result.Count; $i++)
{
    $obj = $result[$i]
    if($null -eq $obj)
    {
        Write-Host "Result[$i] -eq NULL"
    }
    else 
    {
        Write-Host "Result[$i] Type: $($obj.GetType().Name)"
    }
}

# Had to comment this out since it kills execution - TEST 6 never runs after TEST 5 runs with parameter $false.
# Write-Title 'TEST 5:'
# Write-Host 'Should process each pipeline object, returning 10:'
# $startTime = Get-Date
# $result = (1..4 | Invoke-PipelineTest5 $true)
# $result
# Write-Duration $startTime
# Write-Host 'Terminates execution:'
# $startTime = Get-Date
# $result = (1..4 | Invoke-PipelineTest5 $false)
# Write-Result $result
# Write-Duration $startTime

Write-Title 'TEST 7:'
Write-Host 'Fails to return aggregate result as throws part way through the pipeline, aborting it:'
$startTime = Get-Date
$result = $null
try 
{
    $result = (1..4 | Invoke-PipelineTest7)
}
catch 
{
    Write-Host "Captured error: $($_.Exception.Message)"
}
$result
Write-Duration $startTime

Write-Title 'TEST 6:'
Write-Host 'Should process each pipeline object, returning 10:'
$startTime = Get-Date
$result = (1..4 | Invoke-PipelineTest6 $true)
$result
Write-Duration $startTime
Write-Host 'Terminates execution:'
$startTime = Get-Date
$result = (1..4 | Invoke-PipelineTest6 $false)
Write-Result $result
Write-Duration $startTime

# Never runs as Invoke-Pipeline6 terminates execution.
Write-Host 'End'