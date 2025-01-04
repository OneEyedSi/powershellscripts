<#
.SYNOPSIS
Demonstrates mocking a function that accepts input from the pipeline and aggregates the results, returning a single 
object.

.NOTES
Author:			Simon Elms
Requires:		Pester v5.5 or v.5.6 PowerShell module
Version:		1.0.0 
Date:			3 Jan 2025

The following scripts belong together:
* Mocking_PipelineFunctionThatAggregatesResults.ps1:        Function under test
* Mocking_PipelineFunctionThatAggregatesResults.Tests.ps1:  Tests

The tests in Context 'Mock returning a hashtable for each pipeline input, instead of a single hashtable at the end' will 
fail.  This is due to a limitation of Pester mocking, which is unable to accurately mock a pipeline function end block.  
If you add an end block to a mocked pipeline function, either implicitly or explicitly, Pester will treat it as a 
process block and will run it for every input received from the pipeline.  If the mocked function returns a value in its 
end block, in the Pester tests that value will be returned repeatedly, once for each value in the input pipeline.

This limitation is noted in Pester issue 2154, https://github.com/pester/Pester/issues/2154.

A work-around for the issue is demonstrated in Context 'Mock returning a single hashtable at the end'.  It requires two 
mocks that use ParameterFilters: one to return the correct value when the final value is received from the input pipeline, 
and a second that returns nothing for all other input values.  If the second mock, that returns nothing, is not implemented 
# then Pester will fall back to calling the original, un-mocked, function for all input values apart from the last one.

A second work-around is to use a stub function instead of a mock.  See Context 'Using a stub function instead of a mock'.  
This may be simpler than creating two mocks.

----------------------------------------------------------------------------------------------------------------------------

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

# Can't dot source using ". .\Mocking_PipelineFunctionThatAggregatesResults.ps1" (without quotes) as relative paths are relative 
# to the current working directory, not the directory this test file is in.  So Use $PSScriptRoot to get the directory this 
# file is in, and dot source the file to test from the same directory.
# -InTestContext switch ensures the script under test doesn't run automatically when dot sourced into this script.
BeforeAll {
    # Must dot-source file to test in BeforeAll.
    . (Join-Path $PSScriptRoot 'Mocking_PipelineFunctionThatAggregatesResults.ps1') -InTestContext
}

#endregion Configuration ***************************************************************************************************

#region Pester tests *******************************************************************************************************

Describe 'Get-Result' {
    BeforeEach {
        $names = @('Name 1', 'Name 2', 'Name 3', 'Name 4')
    }

    Context 'Mock returning a hashtable for each pipeline input, instead of a single hashtable at the end' {
        BeforeAll {
            Mock Get-NameInfo {  
                end 
                {
                    return @{ InputNames = @(); InputCount = 0 }
                }
            } 
        }

        It 'aggregates the name info' {
            $result = Get-Result $names

            # Produces the following error:
            #   "Expected $false, but got $true."
            $result -is [System.Object[]] | Should -BeFalse
        }
    }

    Context 'Mock returning a single hashtable at the end' {
        BeforeAll {
            $lastInputValue = 'Name 4'

            Mock Get-NameInfo {  } `
                -ParameterFilter { $FeatureName -ne $lastInputValue }
            
            Mock Get-NameInfo { return @{ InputNames = $names; InputCount = 4 } } `
                -ParameterFilter { $FeatureName -eq $lastInputValue }
        }
        
        It 'doesn''t return an array' {
            $result = Get-Result $names

            $result -is [System.Object[]] | Should -BeFalse
        }
        
        It 'returns a single hashtable' {
            $result = Get-Result $names
            
            # Use -is rather than Should -BeOfType because Should -BeOfType System.Collections.Hashtable will be true if 
            # an array of hashtables is returned (because the Should -BeOfType is passed values from the pipeline, which 
            # splits the array up into separate hashtables).
            $result -is [System.Collections.Hashtable] | Should -BeTrue
        }
    }

    Context 'Using a stub function instead of a mock' {
        BeforeAll {
            function Get-NameInfo (
                [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
                [string]$FeatureName
            )
            {
                end
                {
                    return @{ InputNames = $names; InputCount = 4 }
                }
            }
        }
        
        It 'doesn''t return an array' {
            $result = Get-Result $names

            $result -is [System.Object[]] | Should -BeFalse
        }
        
        It 'returns a single hashtable' {
            $result = Get-Result $names
            
            $result -is [System.Collections.Hashtable] | Should -BeTrue
        }
    }
}

#endregion Pester tests ****************************************************************************************************