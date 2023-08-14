<#
.SYNOPSIS
Demonstrates case-sensitive and case-sensitive string assertions for Pester.

.NOTES
Tests from "Getting Started with Pester" from the "Hey, Scripting Guy!" blog:
https://blogs.technet.microsoft.com/heyscriptingguy/2015/12/15/getting-started-with-pester/
#>

<#
.SYNOPSIS
Pester tests.
#>
Describe 'StringComparison' {
    It 'Compares two strings with case sensitivity' {
        'this is a test' | Should BeExactly 'this is a TEST'
    }
    
    it 'Compares two strings with case insensitivity' {
        'this is a test' | Should Be 'this is a TEST'
    }
}