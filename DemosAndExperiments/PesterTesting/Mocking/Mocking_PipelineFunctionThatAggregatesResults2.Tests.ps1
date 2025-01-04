<#
.SYNOPSIS
Demonstrates a work-around that allows a mocked pipeline function to only return a value after all input values have been 
received from the pipeline.

.DESCRIPTION
According to Pester issue 2154, https://github.com/pester/Pester/issues/2154, Pester cannot correctly mock a pipeline 
function that only returns a value from its end block.  Instead, the mock will return the value for each input value 
received from the pipeline.  In effect, an end block in a mocked function will behave like a process block.

Use the -ParameterFilter parameter with the Mock function to work around this limitation, if you know what the last input 
value is that will be received from the pipeline (which you should when writing tests).  If the input value is not equal 
to the final value from the pipeline, have the mocked function return nothing.  If the input value is equal to the final 
value from the pipeline, have the mocked function return your expected result.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1+
                Pester 5.5+
Version:		1.0.0 
Date:			4 Jan 2025

The example code below is from Pester issue 2154, which is still open as of 4 Jan 2025.  The "mocked with ParameterFilter" 
Describe block has been added to demonstrate the work-around.

#>

BeforeAll {
    function outer
    {
        1..3 | inner
    }

    function inner
    {
        param
        (
            [Parameter(ValueFromPipeline)]$InputObject
        )

        # implicit end block, runs once
        "RETURN"
    }
}

Describe "unmocked" {
    # Passes, since it's calling the original, unmocked, inner function.  
    # Since the function is a pipeline function, the body of the function is in an implicit end block.  As a result the 
    # body of the function will only run once, after all inputs have been received from the pipeline.
    It "runs the end block" {
        (outer).Count | Should -Be 1
    }
}

Describe "mocked" {
    # Will fail, since the mocked inner will be called once for each input item from the pipeline, returning a 
    # result each time.
    It "runs the end block" {
        Mock inner {"FOO"}
        (outer).Count | Should -Be 1
    }
}

Describe "mocked with ParameterFilter" {
    # Passes, since mocking using -ParameterFilter ensures the mocked innner function only returns a value after it 
    # receives the last input value from the pipeline.
    It "runs the end block" {
        $lastInputValue = 3
        # The work-around requires two mocks: One to return the correct value when the final input value is received 
        # from the pipeline, and a second that doesn't return anything if the input value is NOT the final input value.
        # If the second mock, that returns nothing, is not implemented then Pester will fall back to calling the 
        # original, un-mocked, function for all input values apart from the last one.
        Mock inner {  } -ParameterFilter { $InputObject -ne $lastInputValue }
        Mock inner {"FOO"} -ParameterFilter { $InputObject -eq $lastInputValue }
        (outer).Count | Should -Be 1
    }
}