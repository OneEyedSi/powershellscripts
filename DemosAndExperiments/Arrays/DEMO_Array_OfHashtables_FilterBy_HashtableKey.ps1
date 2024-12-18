<#
.SYNOPSIS
Demonstrates how to filter an array of hashtables via a hashtable key.

.DESCRIPTION

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
Version:		1.0.0 
Date:			13 Dec 2024

#>

#region Functions **********************************************************************************************************

function Write-Title (
    [Parameter(Mandatory=$True)]
    [string]$Title
)
{
    Write-Host $Title
    Write-Host ('-' * $Title.Length)
}

function Write-HashTable (
    [Parameter(Mandatory=$True)]
    $HashTable, 

    [Parameter(Mandatory=$True)]
    [string]$Title
)
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
}

function Write-Collection (
    [Parameter(Mandatory=$True)]
    $Collection, 

    [Parameter(Mandatory=$True)]
    [string]$Title
)
{
    Write-Title $Title

    if ($Null -eq $Collection)
    {
        Write-Host "Collection is NULL"
        return
    }
    if ($Collection.Count -eq 0)
    {
        Write-Host "Collection is empty"
        return        
    }

    for($i = 0; $i -lt $Collection.Count; $i++)
    {
        Write-HashTable -HashTable $Collection[$i] -Title "Item $($i):"
    }

    Write-Host
}
#endregion Functions *******************************************************************************************************

#region Main script ********************************************************************************************************

$collection = @(
    @{ 'KeyA' = 1; 'KeyB' = 2 },
    @{ 'KeyA' = 3; 'KeyB' = 4 },
    @{ 'KeyA' = 5; 'KeyB' = 6 },
    @{ 'KeyA' = 7; 'KeyB' = 8 },
    @{ 'KeyA' = 9; 'KeyB' = 10 }
)

Clear-Host

Write-Collection -Collection $collection -Title 'Original array'

$filteredCollection = $collection | Where-Object { $_.KeyA -le 3 }

Write-Collection -Collection $filteredCollection -Title 'Array filtered with Where-Object'

$filteredCollection = $collection.where{ $_.KeyA -eq 5 -or $_.KeyA -eq 7 }

Write-Collection -Collection $filteredCollection -Title 'Array filtered with Where method'

#endregion Main script *****************************************************************************************************