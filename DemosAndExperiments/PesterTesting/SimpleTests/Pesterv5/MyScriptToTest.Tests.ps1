<#
.SYNOPSIS
Demonstrates how to test a PowerShell script, as opposed to a module, using Pester.
#>

# The following line is not a comment, it's a requires directive.
#Requires -Modules AssertExceptionThrown

# Can't dot source using ". .\MyScriptToTest.ps1" (without quotes) as relative paths are relative 
# to the current working directory, not the directory this test file is in.  So Use $PSScriptRoot 
# to get the directory this file is in, and dot source the file to test from the same directory.
BeforeAll {
    # Must dot-source file to test in BeforeAll.
    . (Join-Path $PSScriptRoot 'MyScriptToTest.ps1')
}

Describe 'Get-FirstText' {
    It 'returns text "Some text" when called indirectly' {
        $result = Get-FirstText
            $result | Should -Be 'Some text'
        } 

    It 'returns text "Some text" when called directly' {
        Get-FirstText | Should -Be 'Some text'
        } 
}

# Demonstrates there is no need for an InModuleScope wrapper when testing a script, as opposed to 
# a module.  Dot sourcing the script imports all functions, none are hidden from the test code as 
# they would be if they were non-exported functions in a module.
Describe 'Get-Text' {

    It 'returns text "Some text; Other text"' {
        Get-Text | Should -Be 'Some text; Other text'
        } 
        
    Context 'with mocked Get-FirstText' {
        BeforeAll {
            Mock Get-FirstText { return 'Mock text' }
            Mock Get-ThirdText { return 'Woteva' }
        }
        
        It 'returns text "Mock text; Other text" after mocking Get-FirstText' {
            Get-Text | Should -Be 'Mock text; Other text'
        } 
        
        It 'calls Get-FirstText' {
            Get-Text

            # Chould -Invoke replaces Should -Invoke in Pester v5
            Should -Invoke Get-FirstText -Times 1
        } 
        
        It 'does NOT call Get-ThirdText' {
            Get-Text

            Should -Invoke Get-ThirdText -Times 0
        } 
    }
}

Describe 'Invoke-Something' {
    Context 'call mocked function directly' {
        BeforeAll {
            Mock Set-Something { return 'Some text' }
        }

        It 'returns immediately if first Set-Something call does not error' {
            Invoke-Something

            Should -Invoke Set-Something -Times 1 -Exactly
        }
    }

    # The following doesn't work because the second call to Set-Something raises an error, 
    # causing the test to crash and burn.
    <#
    It 'calls Set-Something a second time if first raises a non-terminating error' {
        Mock Set-Something { Write-Error 'Some error' }

        Invoke-Something
        Should -Invoke Set-Something -Scope It -Times 2 -Exactly
    }
    #>
    
    # This version of the test above does work.
    # We need the -ErrorAction SilentlyContinue to avoid displaying the details of the first 
    # non-terminating error (this error is expected but we don't want to scare the person 
    # running the test).
    Context 'call mocked function from another function under test' {
        BeforeAll {
            Mock Set-Something { Write-Error 'Some error'}
            Mock Set-Something { return $Null } -ParameterFilter { $SecondParam -eq 'World' }
            Mock Get-FirstText
        }
        
        It 'calls Set-Something a second time if first raises a non-terminating error' {
            try 
            { 
                Invoke-Something 
            }
            catch {}

            Should -Invoke Set-Something -Scope It -Times 2 -Exactly
            Should -Invoke Get-FirstText -Scope It -Times 1 -Exactly
        }
    }
}

Describe 'Set-File' {
    BeforeAll {
        $filePath = 'C:\Temp\Aaaa.txt'
    }
    
    Context 'file already exists' {
        BeforeAll {
            Mock Test-Path { return $True }
            Mock New-Item
        }        

        It 'returns True' {
            Set-File $filePath | Should -Be $True
        }

        It 'does not call New-Item' {
            Set-File $filePath
            Should -Invoke New-Item -Times 0 -Exactly
        }
    }

    Context 'file does not already exist and creation fails' {
        BeforeAll {
            Mock Test-Path { return $False }
            Mock New-Item
        }

        It 'calls New-Item' {
            Set-File $filePath
            Should -Invoke New-Item -Times 1 -Exactly
        }

        It 'calls Test-Path twice' {
            Set-File $filePath
            Should -Invoke Test-Path -Times 2 -Exactly
        }

        It 'returns False' {
            Set-File $filePath | Should -Be $False
        }
    }

    <#
    .SYNOPSIS 
    This case involves mocking Test-Path so that it returns a different value on its first 
    call than on subsequent calls.

    .DESCRIPTION
    This tests a common pattern:
        "test existence - if not found then create - test again to verify creation"

    The first "test existence" must return false, the second "test again" must return true.  

    The same arguments will be passed in both calls so we can't create two mocks with different 
    parameter filters to generate the different behaviour.

    To generate the different behaviour we use a persistent variable that we return from 
    the mock.  We can change its value inside a mock so subsequent calls can return a different 
    value.

    .NOTES
    WARNING: A weakness of this technique is that the persistent variable is script-scoped so 
    may be changed in other parts of the script.

    Based on code in the following Pester issues:
        https://github.com/pester/Pester/issues/330
        https://github.com/pester/Pester/issues/574
    #>
    Context 'file does not already exist and creation succeeds - using "static" script-scoped variable' {
        BeforeAll {
            Mock Test-Path { 
                return $script:fileExists
            }

            Mock New-Item {
                $script:fileExists = $True
            }
        }

        BeforeEach {
            $script:fileExists = $False
        }

        AfterAll {
            Remove-Variable fileExists -Scope Script
        }

        It 'calls New-Item' {
            Set-File $filePath
            Should -Invoke New-Item -Times 1 -Exactly 
        }

        It 'calls Test-Path twice' {
            Set-File $filePath
            Should -Invoke Test-Path -Times 2 -Exactly 
        }

        It 'returns True' {
            Set-File $filePath | Should -Be $True
        }
    }
    
    <#
    .SYNOPSIS 
    Another technique for mocking Test-Path so that it returns a different value on its first 
    call than on subsequent calls.

    .DESCRIPTION
    This version avoids the weakness of the "persistent variable" technique, where the variable 
    was script scoped so could be changed in other parts of the script.

    .NOTES
    Based on code in the following Pester issue:
        https://github.com/pester/Pester/issues/330
    #>
    
    Context 'file does not already exist and creation succeeds - using local hashtable variable' {
        BeforeAll {
            Mock Test-Path { 
                return $mockState.FileExists
            }

            Mock New-Item {
                $mockState.FileExists = $True
            }
        }

        BeforeEach {
            $mockState = @{
                            FileExists = $False    
                        }
        }

        It 'calls New-Item' {
            Set-File $filePath
            Should -Invoke New-Item -Times 1 -Exactly -Scope It
        }

        It 'calls Test-Path twice' {
            Set-File $filePath
            Should -Invoke Test-Path -Times 2 -Exactly -Scope It
        }

        It 'returns True' {
            Set-File $filePath | Should -Be $True
        }
    }
}

# Demonstrates that parameters can be accessed inside a mock.
Describe 'Invoke-GetParameterValue' {
    BeforeAll {
        Mock Get-ParameterLength { 
            if (-not $Text)
            {
                throw 'Cannot read parameter'
            }

            # Want return value to depend on parameter but not be the same as the value returned by 
            # the function under test.
            return $Text.Length * 10
        }        
    }

    It 'mock throws exception if no argument supplied' {
        { Invoke-GetParameterLength } | Assert-ExceptionThrown -WithMessage 'Cannot read parameter'
    }

    It 'mock return value is dependent on argument passed in' {
        Invoke-GetParameterLength -Text '123' | Should -Be 30
        Invoke-GetParameterLength -Text 'four' | Should -Be 40
    }
}