<#
.SYNOPSIS
Tests returning indivdual results and an overall result from a pipeline function.

.DESCRIPTION
Tests returning indivdual results and an overall result from a pipeline function.

.NOTES
#>

<#
.SYNOPSIS
Writes the keys and values of a hash table to the host.

.DESCRIPTION
Writes the keys and values of a hash table to the host.

.NOTES
#>

<#
.SYNOPSIS
Tests returning individual results and an overall result from a pipeline function.

.DESCRIPTION
Tests returning individual results and an overall result from a pipeline function.

.NOTES
Result: Outputs each of the individual results to the pipeline then outputs the cumulative result 
to the pipeline also.
#>
function Test-Result
{
    # CmdletBinding attribute must be on first non-comment line of the function
    # and requires that the parameters be defined via the Param keyword rather 
    # than in parentheses outside the function body.
    [CmdletBinding()]
    Param
    (
        [Parameter(Position=0,
                    Mandatory=$True,
                    ValueFromPipeline=$True)]
        $ListItem, 

        [Parameter(Position=1,
                    Mandatory=$False)]
        [switch]$DisplayMessages
    )

    begin
    {
        $CumulativeResult = 0
        if ($DisplayMessages)
        {
            Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"        
            Write-Host "BEGIN BLOCK:"
            Write-Host "Cumulative result: $CumulativeResult"
            # The following doesn't work.  It returns 0.
            Write-Host "Number of items: $($ListItem.Count)"
            Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        }
    }

    process
    {
        $Result = $ListItem * 2
        $CumulativeResult += $Result

        if ($DisplayMessages)
        {
            Write-Host "+++++++++++++++++++++++++++++++++++++"
            Write-Host "PROCESS BLOCK for input $($ListItem):"
            Write-Host "Process result: $Result"
            Write-Host "Cumulative result: $CumulativeResult"
            Write-Host "+++++++++++++++++++++++++++++++++++++"
        }

        # NOTE: In PowerShell we can return output from a function in three ways:
        #    1) Use the "return" keyword.  The function exits at the return statement; 
        #        execution does not continue past it;
        #    2) Use the Write-Output cmdlet.  This is slower than return but that shouldn't be 
        #        noticeable in most cases.  In addition execution continues past the 
        #        Write-Output statement;
        #    3) Put an unassigned value on its own line.  This allows multiple values to be 
        #        returned from a function by putting each on a separate line.  In that case 
        #        the multiple values will be returned as an array.  Execution continues past the 
        #        unassigned value.

        # So the following lines would be equivalent:
        #     return @{Value=$Result; Type="Process Result"}
        #     Write-Output @{Value=$Result; Type="Process Result"}
        #     @{Value=$Result; Type="Process Result"}

        # For a pipeline function, like this one, Write-Output is probably clearest in 
        # indicating what happens to the return value (it is output to the pipeline).
        Write-Output @{InputValue=$ListItem; Result=$Result; Type="Process Result"}
    }

    end
    {
        if ($DisplayMessages)
        {
            Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
            Write-Host "END BLOCK:"
            Write-Host "Cumulative result: $CumulativeResult"
            # The following doesn't work.  It returns 1.
            Write-Host "Number of items: $($ListItem.Count)"
            Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        }
        
        Write-Output @{Result=$CumulativeResult; Type="Cumulative Result"}
    }
}

Clear-Host
$List = @(1, 2, 3)
$List | Test-Result -DisplayMessages

Write-Host
Write-Host "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
Write-Host

# Doesn't work as hoped.  Gives two columns, Name and Value.  For each result there are three rows 
# instead of one (only two rows for Cumulative Result since it doesn't have an InputValue).  
# For the first input value (= 1) the three rows are:

# Name         Value
# ----         -----
# Result       2
# InputValue   1
# Type         Process Result

# What we wanted was:

# InputValue   Result  Type             
# ----------   ------  ----             
#          1        2  Process Result

$List | Test-Result | Format-Table

Write-Host
Write-Host "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
Write-Host

# This is how we get the output we wanted.  For the first input value (= 1) there is only a single 
# row:

# InputValue   Result  Type             
# ----------   ------  ----             
#          1        2  Process Result
$List | Test-Result | Select-Object @{Name="InputValue"; Expression={$_.InputValue}}, `
                                    @{Name="Result"; Expression={$_.Result}}, `
                                    @{Name="Type"; Expression={$_.Type}}