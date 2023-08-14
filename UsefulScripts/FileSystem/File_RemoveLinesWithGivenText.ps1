<#
.SYNOPSIS
Reads lines of input text file, removes lines containing specified text, then writes the 
remaining lines to an output file.

.DESCRIPTION
The text to be removed is listed in an array, allowing multiple strings to select the rows to be 
removed.

For speed this uses .NET string.Contains(textToFind) so the text to find cannot be a regex 
expression.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
Version:		1.0.0 
Date:			  12 Jul 2022

Script can handle 400 strings to remove, against a 7000 line text file, in around 15 seconds.

#>

$sourceFilePath = 'C:\Temp\POPULATE_int_MapSite.sql'
$outputFilePath = 'C:\Temp\POPULATE_int_MapSit_modified.sql'
$stringsToRemove = @(
  '101230',
  '134045',
  '134105',
  '192200',
  '210210',
  '220915',
  '221000',
  '270915'
)

function Test-Line ($ArrayOfTextToRemove, $LineToTest)
{
  foreach ($stringToFind in $ArrayOfTextToRemove)
  {
    if ($LineToTest.Contains($stringToFind))
    {
      return $true
    }
  }
  return $false
}

function Get-OutputContent ($SourceFilePath, $ArrayOfTextToRemove)
{
  $linesToTest = Get-Content $sourceFilePath

  $outputLines = @()
  
  foreach($lineToTest in $linesToTest)
  {
    $removeLine = Test-Line -ArrayOfTextToRemove $stringsToRemove -LineToTest $lineToTest
  
    if (-not $removeLine)
    {
      $outputLines += $lineToTest
    }
  }

  return $outputLines
}

Clear-Host

$outputContent = Get-OutputContent -SourceFilePath $sourceFilePath -ArrayOfTextToRemove $stringsToRemove

if (-not $outputContent)
{
  Write-Host 'WARNING: No lines for output file.  Either the input file was empty, all lines in the input file were removed, or something went wrong.  Debug the code to check.' -ForegroundColor Yellow 
  return
}

Set-Content $outputFilePath -Value $outputContent

Write-Host 'COMPLETED' -ForegroundColor Cyan

