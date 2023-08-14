<#
.SYNOPSIS
Demonstrates how to test a PowerShell script, as opposed to a module, using Pester.
#>

# The following line is not a comment, it's a requires directive.
#Requires -Modules AssertExceptionThrown

# Can't dot source using ". .\ScriptToTest.ps1" (without quotes) as relative paths are relative 
# to the current working directory, not the directory this test file is in.  So Use $PSScriptRoot 
# to get the directory this file is in, and dot source the file to test from the same directory.
. (Join-Path $PSScriptRoot 'ScriptToTest.ps1')

Describe 'Get-FirstText' {
    $result = Get-FirstText
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
        
    # WARNING: Mock scope is Describe block, not It block.  If created in an It block the mock 
    # will persist in subsequent It blocks.  So better to declare mock outside It block to make 
    # this obvious.
    Mock Get-FirstText { return 'Mock text' }
    Mock Get-ThirdText { return 'Woteva' }
    
    It 'returns text "Mock text; Other text" after mocking Get-FirstText' {
        Get-Text | Should -Be 'Mock text; Other text'
        } 
    
    It 'calls Get-FirstText' {
        Get-Text

        Assert-MockCalled Get-FirstText -Scope It -Times 1
        } 
    
    It 'does NOT call Get-ThirdText' {
        Get-Text

        Assert-MockCalled Get-ThirdText -Scope It -Times 0
        } 
}

Describe 'Invoke-Something' {
    Context 'mocking scope' {
        Mock Set-Something { return 'Some text' }

        It 'returns immediately if first Set-Something call does not error' {
            Invoke-Something

            Assert-MockCalled Set-Something -Scope It -Times 1 -Exactly
        }
    }

    # The following doesn't work because the second call to Set-Something raises an error, 
    # causing the test to crash and burn.
    <#
    Mock Set-Something { Write-Error 'Some error' }

    It 'calls Set-Something a second time if first raises a non-terminating error' {
        Invoke-Something

        Assert-MockCalled Set-Something -Scope It -Times 2 -Exactly
    }
    #>
    
    # This version of the test above does work.
    # We need the -ErrorAction SilentlyContinue to avoid displaying the details of the first 
    # non-terminating error (this error is expected but we don't want to scare the person 
    # running the test).
    Context 'mocking scope' {
        Mock Set-Something { Write-Error 'Some error'}
        Mock Set-Something { return $Null } -ParameterFilter { $SecondParam -eq 'World' }
        MOck Get-FirstText

        It 'calls Set-Something a second time if first raises a non-terminating error' {
            try 
            { 
                Invoke-Something 
            }
            catch {}

            Assert-MockCalled Set-Something -Scope It -Times 2 -Exactly
            Assert-MockCalled Get-FirstText -Scope It -Times 1 -Exactly
        }
    }
}

Describe 'Set-File' {

    $filePath = 'C:\Temp\Aaaa.txt'

    Context 'file already exists' {
        Mock Test-Path { return $True }
        Mock New-Item

        It 'returns True' {
            Set-File $filePath | Should -Be $True
        }

        It 'does not call New-Item' {
            Set-File $filePath
            Assert-MockCalled New-Item -Times 0 -Exactly
        }
    }

    Context 'file does not already exist and creation fails' {
        Mock Test-Path { return $False }
        Mock New-Item

        It 'calls New-Item' {
            Set-File $filePath
            Assert-MockCalled New-Item -Times 1 -Exactly -Scope It
        }

        It 'calls Test-Path twice' {
            Set-File $filePath
            Assert-MockCalled Test-Path -Times 2 -Exactly -Scope It
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
    WARNING: A weakness of this technique os that the persistent variable is script-scoped so 
    may be changed in other parts of the script.

    Based on code in the following Pester issues:
        https://github.com/pester/Pester/issues/330
        https://github.com/pester/Pester/issues/574
    #>
    Context 'file does not already exist and creation succeeds - using "static" script-scoped variable' {

        BeforeEach {
            $script:fileExists = $False
        }

        AfterAll {
            Remove-Variable fileExists -Scope Script
        }
        
        Mock Test-Path { 
            return $script:fileExists
        }

        Mock New-Item {
            $script:fileExists = $True
        }

        It 'calls New-Item' {
            Set-File $filePath
            Assert-MockCalled New-Item -Times 1 -Exactly -Scope It
        }

        It 'calls Test-Path twice' {
            Set-File $filePath
            Assert-MockCalled Test-Path -Times 2 -Exactly -Scope It
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

        BeforeEach {
            $mockState = @{
                            FileExists = $False    
                        }
        }
        
        Mock Test-Path { 
            return $mockState.FileExists
        }

        Mock New-Item {
            $mockState.FileExists = $True
        }

        It 'calls New-Item' {
            Set-File $filePath
            Assert-MockCalled New-Item -Times 1 -Exactly -Scope It
        }

        It 'calls Test-Path twice' {
            Set-File $filePath
            Assert-MockCalled Test-Path -Times 2 -Exactly -Scope It
        }

        It 'returns True' {
            Set-File $filePath | Should -Be $True
        }
    }
}

# Demonstrates that parameters can be accessed inside a mock.
Describe 'Invoke-GetParameterValue' {
    
    Mock Get-ParameterLength { 
        if (-not $Text)
        {
            throw 'Cannot read parameter'
        }

        # Want return value to depend on parameter but not be the same as the value returned by 
        # the function under test.
        return $Text.Length * 10
    }

    It 'mock throws exception if no argument supplied' {
        { Invoke-GetParameterLength } | Assert-ExceptionThrown -WithMessage 'Cannot read parameter'
    }

    It 'mock return value is dependent on argument passed in' {
        Invoke-GetParameterLength -Text '123' | Should -Be 30
        Invoke-GetParameterLength -Text 'four' | Should -Be 40
    }
}