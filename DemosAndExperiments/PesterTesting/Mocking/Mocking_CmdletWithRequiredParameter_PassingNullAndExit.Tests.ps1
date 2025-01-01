<#
.SYNOPSIS
Demonstrates an issue with Pester mocks and tests: How to test a function which calls a cmdlet 
with a required parameter, where the function under test checks the value and exits if the 
value is $null.

.DESCRIPTION
This problem only occurs when:
1. The function under test calls a cmdlet with a required parameter; and 
2. The function under test has a guard clause that checks the value that would be passed to the 
cmdlet parameter, and aborts execution if the value is $null or an empty string; and
3. The abort is carried out via an exit statement (as opposed to a return or throw); and 
4. There is a Pester v5 test of the guard clause, which sets the value to be checked in the 
guard clause to $null or an empty string.

Issue:
Pester v5 runs Discovery on the tests to run and on the function under test.  However, it does 
not recognise the exit keyword so assumes execution of the function under test will continue after 
the guard clause, even if the value to be passed to the cmdlet is $Null.  Because there is a test 
that sets the value to be passed to the cmdlet to $null, during the Discovery phase Pester will 
throw an error similar to:
    "Get-Content: Cannot bind argument to parameter 'Path' because it is null."

Fix:
Move the exit statement to a separate "exit" function and mock that function.  To prevent 
execution continuing once the mocked exit function has run, in the mock throw an exception.  In 
the test check the function under test throws the expected exception.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5
                Pester v5
Version:		1.0.0
Date:			5 Jan 2024

Normally, execution would be aborted by either calling return, or via throw.  throw results in a 
script terminating (fatal) error (ref #1), with an exit code of 1 (ref #2).  You would only need 
to explictly call exit if you want an exit code other than 1.

References:
1: See answer https://stackoverflow.com/a/58528359/216440 to Stackoverflow question 
"What's the right way to emit errors in powershell module functions?", 
https://stackoverflow.com/questions/58516065/whats-the-right-way-to-emit-errors-in-powershell-module-functions

2: See answer https://stackoverflow.com/a/58541699/216440 to Stackoverflow question 
"How to set the exit code when throwing an exception", 
https://stackoverflow.com/questions/28724388/how-to-set-the-exit-code-when-throwing-an-exception).
#>

<#
.SYNOPSIS
Function under test.
#>
BeforeAll {
    function Test-Function ([string]$SourceFilePath)
    {
        if ([string]::IsNullOrWhiteSpace($SourceFilePath))
        {
            Exit-WithMessage 'The source file path was not set. Exiting.'
        }

        # Do some stuff ...

        $fileContents = Get-Content -Path $SourceFilePath

        # Do some stuff ...
    }

    function Exit-WithMessage ([string]$Message)
    {
        Write-Output $Message
        exit 0
    }
}

Describe 'Test-Function_Fixed' {

    BeforeAll {
        Mock Get-Content { return 'File content text' }   
        Mock Exit-WithMessage { throw 'exception from mock' }
    }

    It 'exits when source file path is null' {
        $sourceFilePath = $null

        { Test-Function -SourceFilePath $sourceFilePath } | Should -Throw -ExpectedMessage 'exception from mock'

        Should -Invoke Exit-WithMessage -ParameterFilter { $Message -eq 'The source file path was not set. Exiting.' } -Times 1
    }

    It 'does not attempt to read file contents when source file path is null' {
        $sourceFilePath = $null

        { Test-Function -SourceFilePath $sourceFilePath } | Should -Throw -ExpectedMessage 'exception from mock'

        Should -Invoke Get-Content -Times 0
    }
}

Describe 'Test-Function_Bad' {

    BeforeAll {
        Mock Get-Content { return 'File content text' } 
    }

    It 'does not attempt to read file contents when source file path is null' {
        $sourceFilePath = $null

        Test-Function -SourceFilePath $sourceFilePath

        Should -Invoke Get-Content -Times 0
    }
}

#Test-Function -SourceFilePath C:\Temp\TestFile.txt
#Test-Function -SourceFilePath $Null