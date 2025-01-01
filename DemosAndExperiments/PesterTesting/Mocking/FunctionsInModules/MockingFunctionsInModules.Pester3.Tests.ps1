Import-Module .\MyModule.psm1

Describe "Unit testing the module's internal Build function:" {
    InModuleScope MyModule {
        $testVersion = 5.0
        Mock Write-Host { }

        Build $testVersion

        It 'Outputs the correct message' {
            Assert-MockCalled Write-Host -ParameterFilter {
                $Object -eq "a build was run for version: $testVersion"
            }
        }
    }
}