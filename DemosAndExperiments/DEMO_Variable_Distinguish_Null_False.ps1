<#
.SYNOPSIS
Demonstrates a test that distinguishes between $Null and $False.

.DESCRIPTION
Demonstrates a test that distinguishes between $Null and $False.  This allows a nullable boolean 
variable to be used ($Null = not set; $True/$False = set to either true or false).

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1 or later 
Version:		1.0.0 
Date:			22 Oct 2023

#>

function Write-WhatSet ($InputValue)
{
    # $Null on left of comparison ensures a boolean result is returned from the comparison.
    # If the $InputValue were a collection and the $Null were on the right, the comparison 
    # would return a matching value, or an empty array if there were no matches.
    # While this particular demo doesn't involve collection input values it's a good idea to get 
    # into the habit of putting $Null on the left.
    if ($Null -eq $InputValue)
    {
        Write-Host 'Is NULL'
        return
    }

    Write-Host "Is $InputValue"
}

Write-WhatSet $null
Write-WhatSet $true
Write-WhatSet $false