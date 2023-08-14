<#
.SYNOPSIS
Tests the persistence of variables in a pipeline function.

.DESCRIPTION
Tests the persistence of variables in a pipeline function.

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
Function called from within pipeline function to test variable persistence.

.DESCRIPTION
Function called from within pipeline function to test variable persistence.

.NOTES
#>
function Test-InnerFunction (
        [Parameter(Mandatory=$True)]
        $PreviousResult
    )
{
    $Result = $PreviousResult

    Write-HashTable -HashTable $PreviousResult -Title "InnerFunction PreviousResult:"

    Write-Host "-------------------------------------------------------------"
    Write-HashTable -HashTable $Result -Title "InnerFunction Result:"
    Write-Host "-------------------------------------------------------------"

    $Result.IsValid = (-not $Result.IsValid)

    Write-Host "============================================================="
    Write-HashTable -HashTable $Result -Title "InnerFunction Result:"
    Write-Host "============================================================="

    return $Result
}

<#
.SYNOPSIS
Tests the persistence of variables in a pipeline function.

.DESCRIPTION
Tests the persistence of variables in a pipeline function.

.NOTES
#>
function Test-Persistence
{
    # CmdletBinding attribute must be on first non-comment line of the function
    # and requires that the parameters be defined via the Param keyword rather 
    # than in parentheses outside the function body.
    [CmdletBinding()]
    Param
    (
        [Parameter(Position=1,
                    Mandatory=$True,
                    ValueFromPipeline=$True)]
        $ListItem
    )

    begin
    {
        $Result = @{IsValid=$True; ErrorMessages=@()}
        Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        Write-HashTable -HashTable $Result -Title "Begin Result:"
        Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    }

    process
    {
        Write-Host "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
        Write-HashTable -HashTable $Result -Title "Process Loop List Item ($ListItem) Result:"
        Write-Host "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"

        $Result = Test-InnerFunction -PreviousResult $Result

        Write-Host "+++++++++++++++++++++++++++++++++++++"
        Write-HashTable -HashTable $Result -Title "Process Loop List Item ($ListItem) Result:"
        Write-Host "+++++++++++++++++++++++++++++++++++++"
    }

    end
    {
        return $Result
    }
}

Clear-Host
$List = @(1, 2, 3)

$Result = ($List | Test-Persistence)
$Result