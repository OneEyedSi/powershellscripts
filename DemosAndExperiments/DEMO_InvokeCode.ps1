<#
.SYNOPSIS
Demonstrates a wrapper around any function or code block that can be used to time it.

.DESCRIPTION
Uses Invoke-Command to execute a function or a script block.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
Version:		1.0.0 
Date:			12 Sep 2020

#>

function Get-ScriptBlockDescription([scriptblock]$Code)
{
    if (-not $Code)
    {
        return '[NO CODE BLOCK SUPPLIED]'
    }

    $description = $Code.StartPosition.Content

    # First line of code block.
    $firstLine = ($Code.StartPosition.Content -split '\n')[0]

    if ($firstLine.StartsWith('function '))
    {
        $description = ($firstLine -split ' ')[1]
        if ($description.Contains('('))
        {
            $description = $description.Split('(')[0]
        }
    }

    return $description
}

function Get-UnitOfTimeMeasure ([string]$UnitOfTimeMeasure)
{
    if (-not $UnitOfTimeMeasure)
    {
        return $null
    }

    $UnitOfTimeMeasure = $UnitOfTimeMeasure.Trim()

    if (-not $UnitOfTimeMeasure.EndsWith('s'))
    {
        $UnitOfTimeMeasure += 's'
    }

    if (-not $UnitOfTimeMeasure.EndsWith('seconds') -and -not $UnitOfTimeMeasure.EndsWith('minutes')) 
    {
        return $null
    }

    if (-not $UnitOfTimeMeasure.StartsWith('Total'))
    {
        $UnitOfTimeMeasure = 'Total' + $UnitOfTimeMeasure
    }

    if (-not $UnitOfTimeMeasure -in ('TotalMinutes', 'TotalSeconds', 'TotalMilliseconds'))
    {
        return $null
    }

    return $UnitOfTimeMeasure
}

function Write-TimeTaken ([datetime]$StartTime, [string]$UnitOfTimeMeasure)
{
    $timeTaken = (Get-Date) - $StartTime

    $UnitOfTimeMeasure = Get-UnitOfTimeMeasure $UnitOfTimeMeasure
    $timeValue = $timeTaken | Select-Object -ExpandProperty $UnitOfTimeMeasure
    $timeDisplayUnits = $UnitOfTimeMeasure.Replace('Total', '').ToLower()
    Write-Host "[TIMING] Time taken: $timeValue $timeDisplayUnits" -ForegroundColor Cyan
}

<#
.SYNOPSIS 
Invokes a script block with optional arguments.

.DESCRIPTION
Invokes a script block with optional arguments, and writes the time taken and any exception 
details to the host.

If a terminating error occurs the details will be written to the host then the application 
or script will exit.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
Version:		1.0.0 
Date:			12 Sep 2020

.PARAMETER Code
The script block to execute.  

If calling a function include a leading "$" before the curly braces of the script block, and 
prefix the function name with "function:".  For example: ${function:Add-Array}

If calling a script block do not include a leading "$".  Parameters may be included via a 
param block.  For example: { param($first, $second) $first+$second }

.PARAMETER Arguments
Optional.  Arguments to pass into the function or script block to be executed.

If passing multiple arguments separate them with a comma.  For example: $myValue1,$myValue2.

If passing a single argument of type array enclose it in parentheses with a leading comma: (, ).  
For example: 

    $parsedData = Invoke-Code -Code ${function:Get-ParsedData} -Arguments (,$rawData) `
                    -UnitOfTimeMeasure 'second'
                   

This forces Invoke-Code to treat it as a single argument of type array, rather than an array of 
multiple arguments.

It's not necessary to wrap multiple arguments of type array, as the "," separator between 
arguments is sufficient to tell PowerShell each array is a separate argument.  For example:
    
    $resultant = Invoke-Code -Code ${function:Add-Array} -Arguments $array1,$array2 `
                    -UnitOfTimeMeasure 'second'

Note that splatting does not work.  You cannot use the splat operator when passing arguments to 
Invoke-Code.  For example, the following will result in an error:

    $splattedArguments = @{ first = 3; second = 8 }
    # Note the splat operator in front of the splattedArguments variable.
    $sum = Invoke-Code -Code { param($first, $second) $first+$second} -Arguments @splattedArguments `
                -UnitOfTimeMeasure 'millisecond'

.PARAMETER UnitOfTimeMeasure
Indicates which unit of time to use when measuring the time the script block takes to execute.  
Valid values are 'minute', 'second', 'millisecond'.  

The UnitOfTimeMeasure can be either singular or plural.  For example, both 'second' and 'seconds' 
are valid.

.PARAMETER ContinueOnError
Normally Invoke-Code will terminate on a terminating error, as the code it is invoking would do.  
However, if ContinueOnError is set execution will continue after writing details of the error to 
the host.

.EXAMPLE
Calling a script block with multiple arguments:

    $sum = Invoke-Code -Code {param($first, $second) $first+$second} `
                -Arguments $addend1,$addend2 -UnitOfTimeMeasure 'millisecond'

.EXAMPLE
Calling a function with a single array argument:

    $parsedData = Invoke-Code -Code ${function:Get-ParsedData} -Arguments (,$rawData) `
                    -UnitOfTimeMeasure 'second' 

.EXAMPLE
Calling a function with multiple array arguments:

    $resultant = Invoke-Code -Code ${function:Add-Array} -Arguments $array1,$array2 `
                    -UnitOfTimeMeasure 'second'

.EXAMPLE
Calling a function with different units of time measure:

    $array = (1..5000)

    $arrayCount = Invoke-Code -Code ${function:Measure-Array} `
                    -Arguments (,$array) -UnitOfTimeMeasure 'second'
                    
    $arrayCount = Invoke-Code -Code ${function:Measure-Array} `
                    -Arguments (,$array) -UnitOfTimeMeasure 'millisecond'

    [TIMING] Starting Measure-Array...
    [TIMING] Time taken: 4.4671478 seconds
    5000
    [TIMING] Starting Measure-Array...
    [TIMING] Time taken: 4332.503 milliseconds
    5000

.EXAMPLE
Continuing execution after a terminating error by setting -ContinueOnError:

Details of the error will still be output to the host.

    Write-Host "Forcing a terminating error (divide by zero) with -ContinueOnError set:"
    $result = Invoke-Code -Code { param($top, $bottom) $top/$bottom } `
                    -Arguments 1,0 -UnitOfTimeMeasure 'millisecond' -ContinueOnError
    Write-Host "This code will execute because Invoke-Code will continue execution after terminating error."

#>
function Invoke-Code 
    ([scriptblock]$Code, $Arguments, [string]$UnitOfTimeMeasure, [switch]$ContinueOnError)
{
    $description = Get-ScriptBlockDescription $Code
    Write-Host "[TIMING] Starting $description..." -ForegroundColor Cyan

    $result = $null

    $startTime = Get-Date
    $timeTaken = (Get-Date) - $startTime
    
    try
    {
        $result = Invoke-Command -ScriptBlock $Code -ArgumentList $Arguments

        Write-TimeTaken -StartTime $startTime -UnitOfTimeMeasure $UnitOfTimeMeasure
    }
    catch
    {
        # Don't use Write-Error because that will include the PositionMessage of the line in this 
        # Invoke-Code function where the error occurred.  We want the line in the script block 
        # where the error occurred.  If the script block is a function the line number counts from 
        # the top of the script file containing the function; it doesn't count from the start of 
        # the function.
        Write-Host "$($_.Exception.GetType().Name): $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "$($_.Exception.ErrorRecord.InvocationInfo.PositionMessage)" -ForegroundColor Red

        Write-TimeTaken -StartTime $startTime -UnitOfTimeMeasure $UnitOfTimeMeasure

        if (-not $ContinueOnError)
        {
            Write-Host 'EXITING DUE TO TERMINATING ERROR, ABOVE.' -ForegroundColor Yellow
            exit
        }
    }    

    return $result
}

function Measure-Array ([array]$Array)
{
    $count = 0
    foreach($item in $Array)
    {
        $count++
    }

    return $count
}

Clear-Host

# Demonstrates how to call a function.
# Also demonstrates the use of different units of time measure, and how to pass an array as a 
# single argument.
Write-Host 'Count number of elements in an array, using different units of time measure:'
$array = (1..1200)
# Note that when calling a function the use of the "$" before the script block, and the use of 
# the "function:" keyword.
$arrayCount = Invoke-Code -Code ${function:Measure-Array} -Arguments (,$array) `
                -UnitOfTimeMeasure 'second'
$arrayCount
$arrayCount = Invoke-Code -Code ${function:Measure-Array} -Arguments (,$array) `
                -UnitOfTimeMeasure 'millisecond'
$arrayCount

# Demonstrates calling a script block with arguments, and how to pass multiple arguments.
Write-Host 
$addend1 = 2
$addend2 = 5
Write-Host "Adding $addend1 and $addend2 in a script block:"
# Note that when calling a script block, as opposed to a function, there is no leading "$".
$sum = Invoke-Code -Code { param($first, $second) $first+$second} -Arguments $addend1,$addend2 `
                -UnitOfTimeMeasure 'millisecond'
Write-Host "Result: $sum"

# Demonstrates that Invoke-Code works with splatting.
Write-Host "Adding two numbers in a script block, using splatting to pass arguments:"
$splattedArguments = @{ first = 3; second = 8 }
$sum = Invoke-Code -Code { param($first, $second) $first+$second} -Arguments $splattedArguments `
                -UnitOfTimeMeasure 'millisecond'
Write-Host "Result: $sum"

# Demonstrates dealing with a terminating error when -ContinueOnError is set 
# (will log the exception then continue).
Write-Host
Write-Host "Forcing a terminating error (divide by zero) with -ContinueOnError set:"
$result = Invoke-Code -Code { param($top, $bottom) $top/$bottom } `
                -Arguments 1,0 -UnitOfTimeMeasure 'millisecond' -ContinueOnError
Write-Host "This code will execute because Invoke-Code will continue execution after terminating error."

# Demonstrates dealing with a terminating error (will log the exception then exit).
Write-Host
Write-Host "Forcing a terminating error (divide by zero) without -ContinueOnError set:"
$result = Invoke-Code -Code { param($top, $bottom) $top/$bottom } `
                -Arguments 1,0 -UnitOfTimeMeasure 'millisecond'
Write-Host "This would have been the result: $result.  But this code will not execute because of error."
