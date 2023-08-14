<#
.SYNOPSIS
Tests whether a function will continue after a return, a Write-Output, or an unassigned value.

.DESCRIPTION
Tests whether a function will continue after a return, a Write-Output, or an unassigned value.

.NOTES
Values can be returned from a function in three ways:
    1) return keyword.  Execution leaves the function at the return statement;
    2) Write-Output cmdlet.  Execution continues past the Write-Output statement.
        Multiple Write-Output statements are allowed in a single function.  This allows the 
        function to return multiple values.  The multiple values are returned as an array;
    3) Unassigned value on its own line.  Execution continues past the unassigned value.  
        Multiple unassigned values are allowed in a single function.  This allows the 
        function to return multiple values.  The multiple values are returned as an array.
#>
function Test-Return
{
    return 1

    Write-Host "Continued past return"
}

function Test-WriteOutput
{
    Write-Output 1

    Write-Host "Continued past first Write-Output"
    
    Write-Output 2

    Write-Host "Continued past second Write-Output"
}

function Test-UnassignedValue
{
    1

    Write-Host "Continued past first unassigned value"

    2

    Write-Host "Continued past second unassigned value"
}

Clear-Host

Write-Host
Write-Host "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
Write-Host "Test-Return:"

Test-Return

Write-Host
Write-Host "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
Write-Host "Test-WriteOutput:"

Test-WriteOutput

Write-Host
Write-Host "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
Write-Host "Test-WriteOutput data type:"

# Indicates Test-WriteOutput returns an array of System.Object[]
$a = Test-WriteOutput
$a.GetType().FullName

Write-Host
Write-Host "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
Write-Host "Test-UnassignedValue:"

Test-UnassignedValue

Write-Host
Write-Host "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
Write-Host "Test-UnassignedValue data type:"

# Indicates Test-UnassignedValue returns an array of System.Object[]
$a = Test-UnassignedValue
$a.GetType().FullName