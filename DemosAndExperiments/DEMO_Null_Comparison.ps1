<#
.SYNOPSIS
Demonstrates why $Null should appear on the left side of a comparison.

.DESCRIPTION
Demonstrates why $Null should appear on the left side of a comparison.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1 or later 
Version:		1.0.0 
Date:			22 Oct 2023

Putting the $Null on the left of the comparison ensures a boolean result is returned from the 
comparison.  

If the $InputValue is a collection and the $Null is on the right, the comparison would return an 
array of matching values (ie an array of every occurrence of $Null in the collection under test), 
or an empty array if there were no $Nulls in the collection.

So get into the habit of putting $Null on the left in comparisons.

See "PossibleIncorrectComparisonWithNull", 
https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/rules/possibleincorrectcomparisonwithnull?view=ps-modules
for a full explanation.

#>

function Get-ValueDataType ($InputValue)
{
    if ($Null -eq $InputValue)
    {
        return '[NULL]'
    }

    $dataType = $InputValue.GetType().Name

    if ($InputValue -is [array])
    {
        $numberOfElements = $InputValue.Count
        $dataType += " (array of $numberOfElements elements)"
    }

    return $dataType
}

function Write-Result ($InputValue)
{
    $result = ($Null -eq $InputValue)
    Write-Host "Null on left: $result"
    $resultType = Get-ValueDataType $result
    Write-Host "Result type: $resultType"

    $result = ($InputValue -eq $Null)
    Write-Host "Null on right: $result"
    $resultType = Get-ValueDataType $result
    Write-Host "Result type: $resultType"

    Write-Host '---------------------'
}

Clear-Host

# Result:
<#
Null on left: True
Result type: Boolean
Null on right: True
Result type: Boolean
#>
Write-Result $Null

# Result:
<#
Null on left: False
Result type: Boolean
Null on right: 
Result type: Object[] (array of 0 elements)
#>
Write-Result @()

# Result:
<#
Null on left: False
Result type: Boolean
Null on right: 
Result type: Object[] (array of 1 elements)
#>
Write-Result @($Null)

# Result:
<#
Null on left: False
Result type: Boolean
Null on right:
Result type: Object[] (array of 1 elements)
#>
Write-Result @(1, 2, $Null)

# Result:
<#
Null on left: False
Result type: Boolean
Null on right:
Result type: Object[] (array of 0 elements)
#>
Write-Result @(1, 2)

# Result:
<#
Null on left: False
Result type: Boolean
Null on right:
Result type: Object[] (array of 2 elements)
#>
Write-Result @(1, 2, $Null, 3, 4, $Null)
