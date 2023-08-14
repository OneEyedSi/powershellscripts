<#
.SYNOPSIS
Demonstrates using dot sourcing to load another script into this one.

.DESCRIPTION
Uses dot sourcing to load another script into this one, then demonstrates that the function, 
alias and variable in the imported script are available here.

.NOTES
#>

function Write-Title ($TitleText)
{
    Write-Host
    Write-Host $TitleText
    Write-Host ("-" * $TitleText.Length)
}

# $PSScriptRoot is the folder this script is running in.  We want to load up scripts that are 
# in the same folder as this one, whatever that folder may be.
$ScriptToImport = Join-Path $PSScriptRoot .\ScriptToImport.ps1

# Dot sourcing to load script.
. $ScriptToImport

Clear-Host

Write-Title "Calling the function imported from the script.  Should write 'Hello world!':"
Write-Something

Write-Title "Calling the alias imported from the script.  Aliases the function also imported:"
ws

Write-Title "Referencing the variable imported from the script.  Should be 31:"
Write-Host "The value of the variable is: $MyVariable"

# Load a script with script parameters:
# --------------------------------------

$ScriptToImport = Join-Path $PSScriptRoot .\ScriptToImportWithParameter.ps1

$FirstArgument = "First"
$SecondArgument = "Second"

Write-Title "Dot sourcing a second script, passing arguments '$FirstArgument' & '$SecondArgument' by position:"
. $ScriptToImport $FirstArgument $SecondArgument

# Function imported from second script, which will write parameters in form: "$FirstParam, $SecondParam"
Write-Parameter

$FirstArgument = "ist"
$SecondArgument = "2nd"

Write-Title "Dot sourcing the second script, passing arguments '$FirstArgument' & '$SecondArgument' by name:"
. $ScriptToImport -SecondParam $SecondArgument -FirstParam $FirstArgument

Write-Parameter
Write-Host