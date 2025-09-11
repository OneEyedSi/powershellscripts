<#
.SYNOPSIS
Demonstrates using dot sourcing inside a function to load another script.

.DESCRIPTION

.NOTES
Author:			Simon Elms
Requires:		Windows PowerShell 5.1 or cross-platform PowerShell 6+
Version:		1.0.0 
Date:			11 Sep 2025

Result: Dot sourcing within a function works, but the functions in the dot sourced script are loaded only within the 
calling function scope.  It doesn't seem possible to dot source within a function and have the functions in the dot sourced 
script available outside the calling function.
#>

function Write-Title ($TitleText)
{
    Write-Host
    Write-Host $TitleText
    Write-Host ("-" * $TitleText.Length)
}

function Add-Script (
    [string]$ScriptNameToTest
)
{
    $currentDirectory = $PSScriptRoot
	$scriptPath = Join-Path $currentDirectory $ScriptNameToTest
	Write-Host "Script path: $scriptPath"
    . $scriptPath
	
	Write-Title "Calling the function imported from the script inside the Add-Script function.  Should write 'Hello world!':"
	Write-Something
}

Clear-Host

Add-Script 'ScriptToImport.ps1'

Write-Title "Calling the function imported from the script.  Should write 'Hello world!':"
# The following results in a error:
# "Write-Something : The term 'Write-Something' is not recognized as the name of a cmdlet, function, script file, or operable program."
Write-Something