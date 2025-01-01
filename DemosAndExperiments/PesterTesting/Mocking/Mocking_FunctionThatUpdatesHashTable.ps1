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

param ([switch]$InTestContext)

#region Functions Under Test ***********************************************************************************************

function Update-HashTable (
    [hashtable]$HashTable
)
{
    $HashTable.State = "State added"
}

function Set-Something ([hashtable]$HashTable)
{
    Update-HashTable $HashTable
}

#endregion Functions Under Test ********************************************************************************************

#region Manual check script ************************************************************************************************

# Manually run script, which doesn't run during tests, that demonstrates the function under test works as intended.

function Write-Hashtable (
    [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
    [hashtable]$HashTable, 

    [string]$Title
)
{
    process
    {
        Write-Host $Title

        # Hashtable.Keys is not sortable so create an array of the keys and sort that.
        $keys = $HashTable.Keys | Sort-Object
        foreach($key in $keys)
        {
            $Value = $HashTable[$key] 

            try
            {
                $Type = " (type $($Value.GetType().FullName))"
            }
            catch
            {
                $Type = ""
            }
                
            if ($Null -eq $Value)
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

            Write-Host "    [$key] $Type : '$Value'"
        }

        Write-Host
    }
}

# Ensure the script below doesn't run as part of the Pester discovery or run phases.
if($InTestContext)
{
    return
}

$hashtable = @{Name='Name 1'; Description='Description 1'}

Clear-Host 

Write-Hashtable $hashtable 'Initial hashtable'

Set-Something $hashtable

Write-Hashtable $hashtable 'hashtable after update'

#endregion Manual check script script **************************************************************************************

