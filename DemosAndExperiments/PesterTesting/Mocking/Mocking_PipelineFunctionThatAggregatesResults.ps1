<#
.SYNOPSIS
Demonstrates mocking a function that accepts input from the pipeline and aggregates the results, returning a single 
object.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1+
Version:		1.0.0 
Date:			3 Jan 2025

The following scripts belong together:
* Mocking_PipelineFunctionThatAggregatesResults.ps1:        Function under test
* Mocking_PipelineFunctionThatAggregatesResults.Tests.ps1:  Tests

Normally the function under test could be included in the .Tests file, in a BeforeAll block.  However, if you wish to run 
the function under test manually in the top-level code of a script you'll have to move it to a different file.  This is 
because PowerShell recognises .Tests.ps1 files as Pester files and runs the tests, rather than running any normal 
top-level code in the file.  

Even moving the function under test to a different file would usually result in the top-level code in that file running 
during the Pester discovery phase.  To avoid that we're using the $InTestContext script parameter to disable the running 
of the top-level code in the file under test during discovery and run phases of Pester tests.  Running the file under 
test normally, as opposed to via Pester, will not set $InTestContext and will allow the top-level code in the file to run.

#>

param ([switch]$InTestContext)

#region Functions Under Test ***********************************************************************************************

function Get-NameInfo (
    [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
    [string]$FeatureName
)
{
    begin
    {
        $result = @{
            InputNames = @()
            InputCount = 0
        }
    }
    process 
    {
        $result.InputNames += $FeatureName
        $result.InputCount++
    }
    end
    {
        return $result
    }
}

function Get-Result ([array]$ArrayOfNames)
{
    $result = $ArrayOfNames | Get-NameInfo
    return $result
}

#endregion Functions Under Test ********************************************************************************************

#region Manual check script ************************************************************************************************

# Manually run script, which doesn't run during tests, that demonstrates the function under test works as intended.

function Get-Indent ([int]$IndentLevel)
{
    if (-not $IndentLevel)
    {
        return ''
    }

    $indent = ' ' * (4 * $IndentLevel)

    return $indent
}

function Write-Title ([string]$Title, [int]$IndentLevel)
{    
    if ($Title)
    {
        $Title = $Title.Trim()
        if ($Title[-1] -ne ':')
        {
            $Title += ':'
        }
    }

    $indent = Get-Indent $IndentLevel

    Write-Host "${indent}$Title"
}

function Get-ValueText ([object]$Value)
{
    $valueText = "$Value"

    if ($Null -eq $Value)
    {
        $valueText = "[NULL]"
    }
    elseif ($Value -is [string])
    {
        if ($Value -eq "")
        {
            $valueText = "[EMPTY STRING]"
        }
        elseif ($Value.Trim() -eq "")
        {
            $valueText = "[BLANK STRING]"
        }
        else 
        {
            $valueText = "'$Value'"
        }
    }

    return $valueText
}

function Write-Enumerable ([System.Collections.IEnumerable]$Enumerable, [string]$Title, [int]$IndentLevel)
{
    Write-Title -Title $Title -IndentLevel $IndentLevel

    if (-not $IndentLevel)
    {
        $IndentLevel = 0
    }

    $IndentLevel++

    $indent = Get-Indent $IndentLevel

    foreach($value in $Enumerable)
    {
        $valueText = Get-ValueText $value

        Write-Host "${indent}$valueText"
    }

    Write-Host
}

function Write-Hashtable ([hashtable]$HashTable, [string]$Title)
{
    Write-Title $Title

    $indentLevel = 1
    $indent = Get-Indent $indentLevel

    # Hashtable.Keys is not sortable so create an array of the keys and sort that.
    $keys = $HashTable.Keys | Sort-Object
    foreach($key in $keys)
    {
        $value = $HashTable[$key] 

        try
        {
            $type = "(type $($value.GetType().FullName))"
        }
        catch
        {
            $type = ""
        }

        $lineTitle = "[$key] $type : "
            
        if ($value -is [System.Collections.IEnumerable])
        {
            Write-Enumerable -Enumerable $value -Title $lineTitle -IndentLevel $indentLevel
            continue
        }

        $valueText = Get-ValueText $value

        Write-Host "${indent}${lineTitle}${valueText}"
    }

    Write-Host
}

# Ensure the script below doesn't run as part of the Pester discovery or run phases.
if($InTestContext)
{
    return
}

$names = @('Name 1', 'Name 2', 'Name 3', 'Name 4')

Clear-Host 

Write-Enumerable $names 'Names'

$result = Get-Result $names
Write-Host "Result type: $($result.GetType().FullName)"

Write-HashTable $result 'Resultant hashtable'

#endregion Manual check script script **************************************************************************************

