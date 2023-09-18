<#
.SYNOPSIS
Demonstrates modifying pipeline objects in the Process block.

.DESCRIPTION
Some inputs are passed through to the output without modification, some are modified.

.NOTES
#>

<#
.SYNOPSIS
Writes the keys and values of a hash table to the host.

.DESCRIPTION
Writes the keys and values of a hash table to the host.

.NOTES
#>
function Write-HashTable (
        [Parameter(Mandatory=$True)]
        $HashTable, 

        [Parameter(Mandatory=$True)]
        [string]$Title
    )
{
    Write-Host $Title
    foreach($Key in $HashTable.Keys)
    {
        $Value = $HashTable[$Key] 

        try
        {
            $Type = " (type $($Value.GetType().FullName))"
        }
        catch
        {
            $Type = ""
        }
               
        if ($Value -eq $Null)
        {
            $Value = "[NULL]"
        }
        elseif ($Value -is [string] -and $Value -eq "")
        {
            $Value = "[EMPTY STRING]"
        }
        elseif ($Value -is [string] -and $Value.Trim() -eq "")
        {
            $Value = "[BLANK STRING]"
        }

        Write-Host "[$Key] $Type : '$Value'"
    }
}

<#
.SYNOPSIS
Modifies some, but not all, input values and then outputs them all.

.DESCRIPTION
Equivalent of FizzBuzz but changes the values of the input integers: 
- If divisible by 3 then output -3
- If divisible by 5 then output -5
- If divisible by 3 and 5 then output -15

.NOTES
#>
function Test-OutputPassing
{
    Param
    (
        [Parameter(Position=0,
                    Mandatory=$True,
                    ValueFromPipeline=$True)]
        [int]$ListItem
    )

    process
    {
        $modifiedValue = 1
        if ($ListItem % 3 -eq 0)
        {
            $modifiedValue *= 3
        }
        if ($ListItem % 5 -eq 0)
        {
            $modifiedValue *= 5
        }
        if ($modifiedValue -ne 1)
        {
            return $modifiedValue * -1
        }
        return $ListItem

        # Alternatives to using return are using Write-Output or using a variable as statement.
        # Write-Output is slower than return but perhaps makes it clearer that the value is being 
        # output to the pipeline again.  return exits the Process block (just for the current 
        # object from the pipeline; it won't stop the Process block running again for the next 
        # pipeline object).  However, the other two alternatives will allow execution to continue.  
        # So where there are multiple exit points, as in this example, return may be easier to use 
        # than Write-Output or a variable statement.
    }
}

Clear-Host

# Pass the results back into another pipeline cmdlet to prove the Process block produced an output 
# for every object passed in through the pipeline.
1..20 | Test-OutputPassing | ForEach-Object { Write-Output "Result: $_" }