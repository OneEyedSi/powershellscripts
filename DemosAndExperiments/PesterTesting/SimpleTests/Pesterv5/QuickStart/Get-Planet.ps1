<#
.SYNOPSIS
Function to test from Pester v5 Quick Start docs.

.DESCRIPTION
Function to test from the Pester v5 Quick Start page, https://pester.dev/docs/quick-start

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5
				Pester 5
Date:			24 Sep 2023
Version:		1.0.0

#>

function Get-Planet ([string]$Name = '*') {
    $planets = @(
        @{ Name = 'Mercury' }
        @{ Name = 'Venus'   }
        @{ Name = 'Earth'   }
        @{ Name = 'Mars'    }
        @{ Name = 'Jupiter' }
        @{ Name = 'Saturn'  }
        @{ Name = 'Uranus'  }
        @{ Name = 'Neptune' }
    ) | ForEach-Object { [PSCustomObject] $_ }

    $planets | Where-Object { $_.Name -like $Name }
}