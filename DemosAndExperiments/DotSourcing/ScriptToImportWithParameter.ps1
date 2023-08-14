<#
.SYNOPSIS
Used to demonstrate dot sourcing with script parameters by being loaded into another script.

.DESCRIPTION
Imported into CallingScript.ps1 via dot sourcing.

.NOTES
#>

Param(
  [string]$FirstParam,
  [string]$SecondParam
)

function Write-Parameter()
{
    $TextToWrite = "$FirstParam, $SecondParam"
    Write-Host $TextToWrite
}