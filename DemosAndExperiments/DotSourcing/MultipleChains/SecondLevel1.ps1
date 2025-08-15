<#
.SYNOPSIS
Second level script in a demo of dot sourcing with multiple reference chains between the lowest level script and 
the highest level script.

.DESCRIPTION

.NOTES
Author:			Simon Elms
Requires:		Windows PowerShell 5.1 or cross-platform PowerShell 6+
Version:		1.0.0 
Date:			15 Aug 2025

The reference chains from one script to another:

                TopLevel.ps1
                    |
      +-------------+-------------+
      |                           |
SecondLevel1.ps1            SecondLevel2.ps1
      |                           |
      +-------------+-------------+
                    |
              LowestLevel.ps1   

#>

. $PSScriptRoot\LowestLevel.ps1

function Write-SecondLevel1 ([string]$Text)
{
    $message = "SecondLevel1: $Text"
    Write-Text $message
}