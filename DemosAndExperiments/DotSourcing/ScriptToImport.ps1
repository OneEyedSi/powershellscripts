<#
.SYNOPSIS
Used to demonstrate dot sourcing by being loaded into another script.

.DESCRIPTION
Imported into CallingScript.ps1 via dot sourcing.

.NOTES
#>
function Write-Something()
{
    Write-Host "Hello world!"
}

Set-Alias -Name ws -Value Write-Something

$MyVariable = 31