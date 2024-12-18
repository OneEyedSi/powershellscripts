<#
.SYNOPSIS
Demonstrates whether it's possible to pass a collection into a pipeline function, update it in the pipeline, and have the 
update persist outside the pipeline.

.DESCRIPTION

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
Version:		1.0.0 
Date:			12 Dec 2024

RESULTS:

Before update
-------------
Item 0:
    [Key1]  (type System.Int32) : '1'
    [Key2]  (type System.Int32) : '2'
Item 1:
    [Key3]  (type System.Int32) : '3'
    [Key4]  (type System.Int32) : '4'
Item 2:
    [Key5]  (type System.Int32) : '5'
    [Key6]  (type System.Int32) : '6'

After update
------------
Item 0:
    [Key1]  (type System.Int32) : '1'
    [Key2]  (type System.Int32) : '2'
    [NewValue]  (type System.Int32) : '11'
Item 1:
    [Key3]  (type System.Int32) : '3'
    [Key4]  (type System.Int32) : '4'
    [NewValue]  (type System.Int32) : '13'
Item 2:
    [Key5]  (type System.Int32) : '5'
    [Key6]  (type System.Int32) : '6'
    [NewValue]  (type System.Int32) : '15'

CONCLUSION:
That a collection can be updated by a pipeline function and the update will persist for the caller.

#>

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

function Update-SuppliedCollection (
    [Parameter(Position=0, ValueFromPipeline = $true, Mandatory = $true)]
    [Hashtable]$Ht
)
{
    process
    {
        # Hashtable.Keys is not sortable and has no index property so create an array from the Keys and sort it, to 
        # ensure we get the value corresponding to the first key alphabetically.
        $keys = $Ht.Keys | Sort-Object
        $Ht.NewValue = $Ht[$keys[0]] + 10
    }
}

Clear-Host

$collection = @(
    @{ 'Key1' = 1; 'Key2' = 2 },
    @{ 'Key3' = 3; 'Key4' = 4 },
    @{ 'Key5' = 5; 'Key6' = 6 }
)

Write-Collection -Collection $collection -Title 'Before update'

$collection | Update-SuppliedCollection

Write-Collection -Collection $collection -Title 'After update'