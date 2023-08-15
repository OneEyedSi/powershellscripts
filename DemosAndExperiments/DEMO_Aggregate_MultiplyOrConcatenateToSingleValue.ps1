<#
.SYNOPSIS
Demonstrates how to aggregate multiple values into a single value.

.DESCRIPTION
Demonstrates multiplying a range of values and concatenating a range of values.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 7.3 (may work with Windows PowerShell 5.1 but hasn't been tried)
Version:		1.0.0 
Date:			15 Aug 2023

The factorial example comes from Stackoverflow post 
"Does Powershell have an Aggregate/Reduce function?", 
https://stackoverflow.com/questions/25163907/does-powershell-have-an-aggregate-reduce-function
#>

Clear-Host

Write-Host 'Multiplying the numbers 1 to 10 (10 factorial):'
1..10 | ForEach-Object -Begin { $total = 1 } -Process { $total *= $_ } -End { $total }

Write-Host ''
Write-Host 'Concatenating strings:'
# ASSUMPTION: That this script is in a directory that contains multiple other scripts.
Get-ChildItem -Path $PSScriptRoot -File | 
    ForEach-Object -Begin { $fileList = '' } -Process { if ($fileList) { $fileList += ';' }; $fileList += $_.Name } -End { $fileList }

Write-Host ''
Write-Host '10 factorial again, showing that the -Begin, -Process and -End parameter names are optional:'
1..10 | ForEach-Object { $total = 1 } { $total *= $_ } { $total }

Write-Host ''
Write-Host 'It''s possible to bind multiple script blocks to the -Process parameter (result should be 14):'
# In this example, loosely based on  
# https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/foreach-object?view=powershell-7.3#example-10-run-multiple-script-blocks-for-each-pipeline-item
# the first script block is bound to the -Begin parameter, the last script block is bound to the 
# -End parameter, and the script blocks in between are bound to the -Process parameter.
1..3 | ForEach-Object { $result = 0 } { $result += 1 } { $result *= 2 } { $result }

Write-Host ''
Write-Host 'Alternative syntax to bind multiple script blocks to the -Process parameter (result should be 14):'
# Note that this time the script blocks bound to the -Process parameter are passed as a comma-separated list.
1..3 | ForEach-Object -Begin { $result = 0 } -Process { $result += 1 }, { $result *= 2 } -End { $result }

Write-Host ''
Write-Host 'Concatenating strings while binding multiple script blocks to the -Process parameter:'
# ASSUMPTION: That this script is in a directory that contains multiple other scripts.
Get-ChildItem -Path $PSScriptRoot -File | 
    ForEach-Object  -Begin { $fileList = '' } `
                    -Process { if ($fileList) { $fileList += ';' } }, { $fileList += $_.Name } `
                    -End { $fileList }

Write-Host ''
Write-Host 'Counting files in the same directory as this script:'
# ASSUMPTION: That this script is in a directory that contains multiple other scripts.
Get-ChildItem -Path $PSScriptRoot -File |
    ForEach-Object  -Begin { "Starting..."; $filecount = 0 } `
                    -Process { $filecount++; "${filecount}: $($_.Name)"; } `
                    -End { "--------------------"; "Final file count: $filecount"; "--------------------" }




