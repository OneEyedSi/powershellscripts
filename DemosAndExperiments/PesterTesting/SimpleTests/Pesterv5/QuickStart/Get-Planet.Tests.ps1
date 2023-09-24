<#
.SYNOPSIS 
Basic Pester tests from Pester v5 Quick Start page.

.DESCRIPTION
Basic Pester tests from Pester v5 Quick Start page, https://pester.dev/docs/quick-start

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5
				Pester 5
Date:			24 Sep 2023
Version:		1.0.0

#>
BeforeAll {
    # Must dot-source file to test in BeforeAll.
    . $PSScriptRoot/Get-Planet.ps1
}

Describe 'Get-Planet' {
    It 'Given no parameters, it lists all 8 planets' {
        $allPlanets = Get-Planet
        $allPlanets.Count | Should -Be 8
    }

    It 'Earth is the third planet in our Solar System' {
        $allPlanets = Get-Planet
        $allPlanets[2].Name | Should -Be 'Earth'
    }

    It 'Pluto is not part of our Solar System' {
        $allPlanets = Get-Planet
        $plutos = $allPlanets | Where-Object Name -EQ 'Pluto'
        $plutos.Count | Should -Be 0
    }

    It 'Planets have this order: Mercury, Venus, Earth, Mars, Jupiter, Saturn, Uranus, Neptune' {
        $allPlanets = Get-Planet
        $planetsInOrder = $allPlanets.Name -join ', '
        $planetsInOrder | Should -Be 'Mercury, Venus, Earth, Mars, Jupiter, Saturn, Uranus, Neptune'
    }
}