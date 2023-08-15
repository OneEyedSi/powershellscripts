<#
.SYNOPSIS
Demonstrates parallel processing with ForEach-Object.

.DESCRIPTION
Demonstrates how to perform slow operations in parallel.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 7+ (-Parallel parameter was added in PowerShell 7.0)
Version:		1.0.0 
Date:			15 Aug 2023

See Microsoft Learn document
"ForEach-Object" > "Example 11: Run slow script in parallel batches", 
https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/foreach-object?view=powershell-7.2#example-11-run-slow-script-in-parallel-batches

For more information about parallel processing with ForEach-Object, see further examples on the 
ForEach-Object page.

Results:
-------
Note that with parallel processing the order the pipeline items are processed in is not guaranteed.
Notice the order of the "loop counter".

Without parallel processing:
Loop 1 elapsed time: 1.00 sec
Loop 2 elapsed time: 2.00 sec
Loop 3 elapsed time: 3.01 sec
Loop 4 elapsed time: 4.02 sec
Loop 5 elapsed time: 5.03 sec
Loop 6 elapsed time: 6.05 sec
--------------------------
Total time taken: 6.05 sec

With parallel processing (ThrottleLimit 2):
Loop 2 elapsed time: 1.23 sec
Loop 1 elapsed time: 1.23 sec
Loop 3 elapsed time: 2.25 sec
Loop 4 elapsed time: 2.25 sec
Loop 5 elapsed time: 3.26 sec
Loop 6 elapsed time: 3.28 sec
--------------------------
Total time taken: 3.30 sec

With parallel processing (ThrottleLimit 3):
Loop 1 elapsed time: 1.12 sec
Loop 2 elapsed time: 1.13 sec
Loop 3 elapsed time: 1.16 sec
Loop 4 elapsed time: 2.15 sec
Loop 6 elapsed time: 2.18 sec
Loop 5 elapsed time: 2.18 sec
--------------------------
Total time taken: 2.19 sec

With parallel processing (ThrottleLimit 6):
Loop 2 elapsed time: 1.21 sec
Loop 1 elapsed time: 1.22 sec
Loop 3 elapsed time: 1.22 sec
Loop 4 elapsed time: 1.26 sec
Loop 5 elapsed time: 1.33 sec
Loop 6 elapsed time: 1.33 sec
--------------------------
Total time taken: 1.34 sec

#>

Clear-Host

Write-Host 'Without parallel processing:'
$startTime = Get-Date
1..6 | ForEach-Object -Process { 
                                    Start-Sleep -Seconds 1; 
                                    $elapsedTime = (Get-Date) - $startTime; 
                                    Write-Host "Loop $_ elapsed time: $($elapsedTime.ToString('s\.ff')) sec" 
                                }
$elapsedTime = (Get-Date) - $startTime
Write-Host "--------------------------"
Write-Host "Total time taken: $($elapsedTime.ToString('s\.ff')) sec"

# ------------------------------------------------------
<#
.SYNOPSIS
Operates on each pipeline object in parallel.

.DESCRIPTION
Operates on each pipeline object in parallel.  The number of parallel processes running 
simultaneously is determined by the -ThrottleLimit parameter.

.NOTES
The -Parallel parameter of ForEach-Object cannot be used with -Begin, -Process or -End.

The code block run via the -Parallel parameter runs outs of process.  Therefore it cannot directly 
access variables defined in the script (eg $startTime).  To access such variables, use $using.  
For example, to access the $startTime variable inside the parallel processing block, use 
    $using:startTime
#>
function Invoke-Parallel ([int]$ThrottleLimit)
{
    Write-Host ''
    Write-Host "With parallel processing (ThrottleLimit $ThrottleLimit):"
    $startTime = Get-Date
    1..6 | ForEach-Object   -Parallel { 
                                        Start-Sleep -Seconds 1; 
                                        $elapsedTime = (Get-Date) - $using:startTime; 
                                        Write-Host "Loop $_ elapsed time: $($elapsedTime.ToString('s\.ff')) sec" 
                                    } `
                            -ThrottleLimit $ThrottleLimit
    $elapsedTime = (Get-Date) - $startTime
    Write-Host "--------------------------"
    Write-Host "Total time taken: $($elapsedTime.ToString('s\.ff')) sec"
}
# ------------------------------------------------------

Invoke-Parallel -ThrottleLimit 2
Invoke-Parallel -ThrottleLimit 3
Invoke-Parallel -ThrottleLimit 6