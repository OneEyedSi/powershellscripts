Import-Module .\MyModule.psm1

Describe "BuildIfChanged" {
    Context "When there are Changes" {
        Mock -ModuleName MyModule Get-Version { return 1.1 }
        Mock -ModuleName MyModule Get-NextVersion { return 1.2 }

        # Just for giggles, we'll also mock Write-Host here, to demonstrate that you can
        # mock calls to commands other than functions defined within the same module.
        Mock -ModuleName MyModule Write-Host {} -Verifiable -ParameterFilter {
            $Object -eq 'a build was run for version: 1.2'
        }

        $result = BuildIfChanged

        It "Builds the next version and calls Write-Host" {
            # Prior to Pester 4 this was Assert-VerifiableMocks, with an "s".
            Assert-VerifiableMock
        }

        It "returns the next version number" {
            $result | Should Be 1.2
        }
    }

    Context "When there are no Changes" {
        Mock -ModuleName MyModule Get-Version { return 1.1 }
        Mock -ModuleName MyModule Get-NextVersion { return 1.1 }
        Mock -ModuleName MyModule Build { }

        $result = BuildIfChanged

        It "Should not build the next version" {
            Assert-MockCalled Build -ModuleName MyModule -Times 0 -ParameterFilter {
                $version -eq 1.1
            }
        }
    }
}