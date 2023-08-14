<#
.SYNOPSIS
Demonstrates test initialization and clean up in Pester.

.NOTES
Tests from "More Pester Features and Resources" from the "Hey, Scripting Guy!" blog:
https://blogs.technet.microsoft.com/heyscriptingguy/2015/12/18/more-pester-features-and-resources/
#>

Describe 'Setup and Teardown' {
    BeforeAll { Write-Host -ForegroundColor Yellow 'Executing BeforeAll block' }
    AfterAll { Write-Host -ForegroundColor Yellow 'Executing AfterAll block' }

    It 'Executes the first test' {
        $someObject.Name | Should Be 'Cool!'
    }

    $someObject = [pscustomobject] @{ Name = 'I changed it...' }

    It 'Executes the second test' {
        $someObject.Name | Should Be 'Cool!'
    }

    BeforeEach {
        $someObject = [pscustomobject] @{ Name = 'Cool!' }
        Write-Host -ForegroundColor Gray 'Executing BeforeEach block'
    }

    AfterEach { Write-Host -ForegroundColor Gray 'Executing AfterEach block' }
}