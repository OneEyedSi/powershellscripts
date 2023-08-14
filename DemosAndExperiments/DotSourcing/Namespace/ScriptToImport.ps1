<#
.SYNOPSIS
Used to demonstrate dot sourcing with a namespace.

.DESCRIPTION
Imported into CallingScript.ps1 via dot sourcing.  Is located in a sub-folder.

.NOTES
#>
function Write-FromNamespace()
{
    Write-Host "Hello from a sub-folder!"
}