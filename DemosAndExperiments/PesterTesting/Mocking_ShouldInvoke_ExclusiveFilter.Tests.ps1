<#
.SYNOPSIS
Demonstrates how to use Should -Invoke with the -ExclusiveFilter parameter.

.NOTES
-ExclusiveFilter specifies that the mocked command is called at least once with the 
#>

<#
.SYNOPSIS
Function under test.
#>
BeforeAll {
    function Test-Function ([string]$FilePath)
    {
        return Test-Path $FilePath
    }
    
    function Test-Function2 ([string]$FilePath)
    {
        $result1 = Test-Path $FilePath
        $result2 = Test-Path 'D:\SomePath'

        return $True
    }
}

<#
.SYNOPSIS
Pester tests.
#>
Describe 'TestFunction' {

    BeforeAll {
        $filePath = 'C:\Temp\Aaaa.txt'
       
        Mock Test-Path {
            return $True
        }
    }

    Context 'Should -Invoke -ParameterFilter' {

        It 'passes' {
            Test-Function $filePath

            Should -Invoke Test-Path -ParameterFilter { $Path -like 'C:\*' } -Times 1
            Should -Invoke Test-Path -ParameterFilter { $Path -like 'NoExist:\*' } -Times 0
        }
    }

    Context 'Should -Invoke -ExclusiveFilter' {

        It 'passes' {
            Test-Function $filePath

            Should -Invoke Test-Path -ExclusiveFilter { $Path -like 'C:\*' }
        }

        It 'fails' {
            Test-Function $filePath

            # Error message:
            # Expected Test-Path to be called at least 1 times, but was called 0 times 
            # at Should -Invoke Test-Path -ExclusiveFilter { $Path -like 'NoExist:\*' }
            Should -Invoke Test-Path -ExclusiveFilter { $Path -like 'NoExist:\*' }
        }
    }
}

Describe 'TestFunction2' {

    BeforeAll {
        $filePath = 'C:\Temp\Aaaa.txt'
       
        Mock Test-Path {
            return $True
        }
    }

    Context 'Should -Invoke -ParameterFilter' {

        It 'passes' {
            Test-Function2 $filePath

            Should -Invoke Test-Path -ParameterFilter { $Path -like 'C:\*' } -Times 1
            Should -Invoke Test-Path -ParameterFilter { $Path -like 'D:\*' } -Times 1
            Should -Invoke Test-Path -ParameterFilter { $Path -like 'NoExist:\*' } -Times 0
        }
    }

    Context 'Should -Invoke -ExclusiveFilter' {

        It 'fails' {
            Test-Function2 $filePath

            # Error message:
            # Expected Test-Path to only be called with with parameters matching the specified filter, but 1 non-matching calls were made
            # at Should -Invoke Test-Path -ExclusiveFilter { $Path -like 'C:\*' }
            Should -Invoke Test-Path -ExclusiveFilter { $Path -like 'C:\*' }
        }

        It 'fails2' {
            Test-Function2 $filePath

            # Error message:
            # Expected Test-Path to be called at least 1 times, but was called 0 times
            # at Should -Invoke Test-Path -ExclusiveFilter { $Path -like 'NoExist:\*' }
            Should -Invoke Test-Path -ExclusiveFilter { $Path -like 'NoExist:\*' }
        }

        It 'passes' {
            Test-Function2 $filePath

            Should -Invoke Test-Path -ExclusiveFilter { $Path -match '[C|D]:\\.+' } 
        }

        It 'passes2' {
            Test-Function2 $filePath

            # Passes because without -Exactly switch "-Times 1" means "at least 1x".
            Should -Invoke Test-Path -ExclusiveFilter { $Path -match '[C|D]:\\.+' } -Times 1
        }

        It 'passes3' {
            Test-Function2 $filePath

            Should -Invoke Test-Path -ExclusiveFilter { $Path -match '[C|D]:\\.+' } -Times 2 -Exactly
        }

        It 'fails3' {
            Test-Function2 $filePath

            # Error message:
            #  Expected Test-Path to be called 1 times exactly, but was called 2 times
            # at Should -Invoke Test-Path -ExclusiveFilter { $Path  -match '[C|D]:\\.+' } -Times 1 -Exactly
            Should -Invoke Test-Path -ExclusiveFilter { $Path -match '[C|D]:\\.+' } -Times 1 -Exactly
        }
    }
}