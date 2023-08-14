<#
.SYNOPSIS
Experiments with short circuiting Select-String to stop after it finds the first match.

.NOTES 
Expects Lorem.txt to be in the same folder as this script.

RESULTS:
For a text file, 200 lines long with the match on line 11, after 3000 iterations the times 
of the two loops are approximately:
    1) Select-String:                               1.6 seconds
    2) Get-Content | Select-String | Select-Object: 3.7 seconds

So it's much quicker to use a simple Select-String than to get fancy.
#>

#region Functions *********************************************************************************

function Write-Title ($TitleText)
{
    Write-Host
    Write-Host $TitleText
    Write-Host ("-" * $TitleText.Length)
}

function Write-TimeTaken ([datetime]$StartTime)
{
    $endTime = Get-Date
    $timeTaken = New-TimeSpan -Start $StartTime -End $endTime

    Write-Host "Finished in $($timeTaken.TotalSeconds) seconds" -ForegroundColor Yellow
}

#endregion

#region Main script *******************************************************************************

Clear-Host

$numberOfIterations = 3000

Write-Host "Number of iterations: $numberOfIterations"

Write-Title 'Select-String:'

$startTime = Get-Date
Write-Host "Started..." -ForegroundColor Yellow

for ($i=0; $i -lt $numberOfIterations; $i++) 
{ 
    $matches = Select-String -Path "$PSScriptRoot.\Lorem.txt" -Pattern '^\s*#*\s*Version\s*:\s*([\d\.]{1,7})'
}

Write-TimeTaken $startTime

Write-Title 'Get-Content | Select-String | Select-Object:'

$startTime = Get-Date
Write-Host "Started..." -ForegroundColor Yellow

for ($i=0; $i -lt $numberOfIterations; $i++) 
{ 
    $matches = Get-Content -Path "$PSScriptRoot.\Lorem.txt" | 
        Select-String -Pattern '^\s*#*\s*Version\s*:\s*([\d\.]{1,7})' | 
        Select-Object -First 1
}

Write-TimeTaken $startTime

#endregion