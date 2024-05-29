<#
.SYNOPSIS
Demonstrates how to return different values on different calls to a mocked command.

.DESCRIPTION
Demonstrates how to handle a common pattern when mocking commands:

1. Test existence: Returns false
2. If object not found then create it
3. Test existence again to verify creation: Returns true

Demonstrates two ways of handling this pattern:

1. Use a persistent script-scoped variable.  Change it between tests of existence.  
    Problem: Possible race condition since the variable can be changed elsewhere in the script 
    (eg by another test).

2. Use a hash table.  This is not script-scoped so there is no possibility of a race condition.
#>

<#
.SYNOPSIS
Function under test.
#>
BeforeAll {
    function Set-File ([string]$FilePath)
    {
        if (Test-Path $FilePath)
        {
            return $True
        }

        New-Item -Path $FilePath -ItemType File

        if (Test-Path $FilePath)
        {
            return $True
        }

        return $False
    }
}

<#
.SYNOPSIS
Pester tests.
#>
Describe 'Changing mocked Test-Path behaviour between calls' {

    BeforeAll {
        $filePath = 'C:\Temp\Aaaa.txt'
    }

    Context 'file does not already exist and creation succeeds - using script-scoped variable' {

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
            Remove-Variable fileExists  -Scope Script
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