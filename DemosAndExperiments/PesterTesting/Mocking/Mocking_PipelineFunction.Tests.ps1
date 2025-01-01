<#
.SYNOPSIS
Demonstrates mocking a function that accepts input from the pipeline and updates a hashtable.

.NOTES
Author:			Simon Elms
Requires:		Pester v5.5 or v.5.6 PowerShell module
Version:		1.0.0 
Date:			1 Jan 2025

The following scripts belong together:
* Mocking_PipelineFunction.ps1:        Function under test
* Mocking_PipelineFunction.Tests.ps1:  Tests

Normally the function under test could be included in the .Tests file, in a BeforeAll block.  However, if you wish to run 
the function under test manually in the top-level code of a script you'll have to move it to a different file.  This is 
because PowerShell recognises .Tests.ps1 files as Pester files and runs the tests, rather than running any normal 
top-level code in the file.  

Even moving the function under test to a different file would usually result in the top-level code in that file running 
during the Pester discovery phase.  To avoid that we're using the $InTestContext script parameter to disable the running 
of the top-level code in the file under test during discovery and run phases of Pester tests.  Running the file under 
test normally, as opposed to via Pester, will not set $InTestContext and will allow the top-level code in the file to run.

#>

#region Requirements *******************************************************************************************************

# "#Requires" is not a comment, it's a requires directive.
# ModuleVersion is the minimum version, not the exact version.
#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.5.0"; MaximumVersion="5.6.99" }

#endregion Requirements ****************************************************************************************************

#region Configuration ******************************************************************************************************

# Can't dot source using ". .\Mocking_PipelineFunction.ps1" (without quotes) as relative paths are relative 
# to the current working directory, not the directory this test file is in.  So Use $PSScriptRoot to get the directory this 
# file is in, and dot source the file to test from the same directory.
# -InTestContext switch ensures the script under test doesn't run automatically when dot sourced into this script.
BeforeAll {
    # Must dot-source file to test in BeforeAll.
    . (Join-Path $PSScriptRoot 'Mocking_PipelineFunction.ps1') -InTestContext
}

#endregion Configuration ***************************************************************************************************

#region Pester tests *******************************************************************************************************

Describe 'Set-Something' {
    BeforeAll {
        Mock Update-HashTable {  
            process 
            {
                $HashTable.State = "Test State"
            }
        } 
    }
    BeforeEach {
        $array = @(
            @{Name='Name 1'; Description='Description 1'}
            @{Name='Name 2'; Description='Description 2'}
            @{Name='Name 3'; Description='Description 3'}
            @{Name='Name 4'; Description='Description 4'}
        )
    }

    It 'sets the State in each supplied hashtable' {
        Set-Something $array

        $array | Should -HaveCount 4
        foreach($hashtable in $array)
        {
            $hashtable.ContainsKey('State') | Should -BeTrue
            $hashtable.State | Should -BeExactly 'Test State'
        }
    }
}

#endregion Pester tests ****************************************************************************************************