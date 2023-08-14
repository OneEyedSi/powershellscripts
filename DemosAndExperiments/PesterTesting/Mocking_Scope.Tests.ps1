<#
.SYNOPSIS
Tests that investigate scope that Mock applies to.

.NOTES
CONCLUSIONS:
1) Mocks defined in a Describe block are available in the Describe block but not outside it;

2) Mocks defined in a Context block are available in the Context block but not outside it;

3) Mocks defined in an It block are available in the parent block, Describe or Context, but not outside it;

4) Mocks will only be used below where they are defined.  Above where they are defined Pester will
    run the original command, not the mock.
#>

<#
.SYNOPSIS
Pester tests.
#>
Describe 'Mock defined in Describe' {
    Mock Write-Output { return "${InputObject}: MOCKED" }

    It 'overrides original functionality' {
        Write-Output 'This should be written by a mock' | Should -Be 'This should be written by a mock: MOCKED'
    }

    It 'overrides original functionality again' {
        Write-Output 'Still should be written by a mock' | Should -Be 'Still should be written by a mock: MOCKED'
    }
}

Describe 'Mock NOT defined in Describe' {
    It 'does not override original functionality' {
        Write-Output 'This should NOT be written by a mock' | Should -Be 'This should NOT be written by a mock'
    }
}

Describe 'Mock defined in Context' {
    Context 'Defines Mock' {
        Mock Write-Output { return "${InputObject}: MOCKED" }

        It 'overrides original functionality' {
            Write-Output 'This should be written by a mock' | Should -Be 'This should be written by a mock: MOCKED'
        }

        It 'overrides original functionality again' {
            Write-Output 'Still should be written by a mock' | Should -Be 'Still should be written by a mock: MOCKED'
        }
    }

    Context 'Different' {
        It 'does not override original functionality' {
            Write-Output 'This should NOT be written by a mock' | Should -Be 'This should NOT be written by a mock'
        }
    }
}

Describe 'Mock defined in It' {
    It 'does not override original functionality' {
        Write-Output 'This should NOT be written by a mock' | Should -Be 'This should NOT be written by a mock'
    }

    It 'overrides original functionality' {
        Mock Write-Output { return "${InputObject}: MOCKED" }
        Write-Output 'This should be written by a mock' | Should -Be 'This should be written by a mock: MOCKED'
    }

    It 'overrides original functionality again' {
        Write-Output 'Still should be written by a mock' | Should -Be 'Still should be written by a mock: MOCKED'
    }
}