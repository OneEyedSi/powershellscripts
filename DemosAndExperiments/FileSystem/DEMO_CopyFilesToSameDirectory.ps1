<#
.SYNOPSIS
Demonstrates how to copy files to the same directory and rename them in the process.

.NOTES
Assumes several files with the same filename pattern in the same folder.
#>

function Write-Title ($TitleText)
{
    Write-Host
    Write-Host $TitleText
    Write-Host ("-" * $TitleText.Length)
}

Clear-Host

get-childitem -Path 'C:\Temp\FileCopyTest\Demo5_MultistagePipeline_07_CreateDeployTemplateFile-f*.png' | 
   ForEach-Object {Copy-Item -Path $_.FullName -Destination ($_.FullName -replace '-f', '-1000-f')}

