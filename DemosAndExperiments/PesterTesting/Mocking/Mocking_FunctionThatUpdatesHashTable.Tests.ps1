<#
.SYNOPSIS
Demonstrates mocking a function that updates a hashtable.

.NOTES
Author:			Simon Elms
Requires:		Pester v5.5 or v.5.6 PowerShell module
Version:		1.0.0 
Date:			1 Jan 2025

The following scripts belong together:
* Mocking_FunctionThatUpdatesHashTable.ps1:         Function under test
* Mocking_FunctionThatUpdatesHashTable.Tests.ps1:   Tests

Normally the function under test could be included in the .Tests file, in a BeforeAll block.  However, if you wish to run 
the function under test manually in the top-level code of a script you'll have to move it to a different file.  This is 
because PowerShell recognises .Tests.ps1 files as Pester files and runs the tests, rather than running any normal 
top-level code in the file.  

Even moving the function under test to a different file would usually result in the top-level code in that file running 
during the Pester discovery phase.  To avoid that we're using the $InTestContext script parameter to disable the running 
of the top-level code in the file under test during discovery and run phases of Pester tests.  Running the file under 
test normally, as opposed to via Pester, will not set $InTestContext and will allow the top-level code in the file to run.

#>

#region Configuration ******************************************************************************************************

# Can't dot source using ". .\Mocking_FunctionThatUpdatesHashTable.ps1" (without quotes) as relative paths are relative 
# to the current working directory, not the directory this test file is in.  So Use $PSScriptRoot to get the directory this 
# file is in, and dot source the file to test from the same directory.
# -InTestContext switch ensures the script under test doesn't run automatically when dot sourced into this script.
BeforeAll {
    # Must dot-source file to test in BeforeAll.
    . (Join-Path $PSScriptRoot 'Mocking_FunctionThatUpdatesHashTable.ps1') -InTestContext
}

#endregion Configuration ***************************************************************************************************

#region Pester tests *******************************************************************************************************

Describe 'Set-Something' {
    BeforeAll {
        Mock Update-HashTable {  
            $HashTable.State = 'Test State'
        } 
    }
    BeforeEach {
        $ht = @{Name='Name'; Description='Description'}
    }

    It 'sets the State for the supplied hashtable' {
        Set-Something $ht

        $ht.ContainsKey('State') | Should -BeTrue
        $ht.State | Should -BeExactly 'Test State'
    }
}

#endregion Pester tests ****************************************************************************************************