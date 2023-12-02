<#
.SYNOPSIS
Demonstrates how to get the relative path to files under a specified folder.

.NOTES
#>

function Write-Title ($TitleText)
{
    Write-Host
    Write-Host $TitleText
    Write-Host ("-" * $TitleText.Length)
}

$rootFolder = 'C:\Temp\Test'

Clear-Host

# $PWD is the current working directory (FileInfo object).
$originalWorkingDirectory = $PWD

# Resolve-Path -Relative is relative to the location set by Set-Location.
# Set-Location sets the current working directory.
Set-Location $rootFolder
Get-ChildItem $rootFolder -File -Recurse | Select-Object PsPath | Resolve-Path -Relative

Set-Location $originalWorkingDirectory