<#
.SYNOPSIS
Lists all objects in Visual Studio database projects that should be included in the built output
but are not.

.DESCRIPTION
Identifies all SSDT project files under a specified root directory then parses each project file
to find all the "None" items.  Items that should not be included in the built output, such as
database snapshots, are excluded from the results.

.NOTES
    Author: Simon Elms
    Date: 8 Jan 2018
    Version: 1.0.0.0
#>

$RootFolderPath = "C:\Working\Databases"

function Get-UnbuiltItem (
    [Parameter(Position=0,
                Mandatory=$True)]
    [string]$FullProjectFileName
    )
{
<#
.SYNOPSIS
Parses a SSDT project file to find the items that should be included in the project build but 
have been accidentally left out.

.DESCRIPTION
Parses a SSDT project file to return the "None" items.  None items that should not be included in 
the built output, such as database snapshots, are excluded from the results.

.NOTES
The first version of the function.  It works but makes the pipeline statement that uses the 
function very messy.  Version 2 of the function simplifies the pipeline statement.
#>
    $xmlDoc = new-object xml
    $xmlDoc.load($FullProjectFileName)
    $xmlDoc.Project.ItemGroup.None |
        select-object @{Name="ScriptFileName"; Expression={$_.Include}}, `
            @{Name="TopLevelDirectory"; Expression={($_.Include).Split("{\}")[0]}}, `
            @{Name="FileExtension"; Expression={[system.io.path]::GetExtension($_.Include)}} |
        Where-Object { (@("Scripts", "Snapshots", "PublishingProfiles", "Jobs", "Security") -notcontains $_.TopLevelDirectory) -and
            @(".dacpac", ".dll", ".xml") -notcontains $_.FileExtension } |
        Select-Object ScriptFileName
}

function Get-UnbuiltItem2 (
    [Parameter(Position=0,
                Mandatory=$True)]
    [string]$FullProjectFileName,

    [Parameter(Position=1,
                Mandatory=$True)]
    [string]$ProjectDisplayName
    )
{
<#
.SYNOPSIS
Parses a SSDT project file to find the items that should be included in the project build but 
have been accidentally left out.

.DESCRIPTION
Parses a SSDT project file to return the "None" items.  None items that should not be included in 
the built output, such as database snapshots, are excluded from the results.

.NOTES
The second version of the function, written to simplify the pipeline statement that uses the 
function.
#>
    $scriptFileNames = Get-UnbuiltItem -FullProjectFileName $FullProjectFileName
    $scriptFileNames | Select-Object @{Name="ProjectName"; Expression={$ProjectDisplayName}}, ScriptFileName
}

Clear-Host

$startTime = Get-Date
Write-Host "Started..."

# $collection = Get-UnbuiltItem -FullProjectFileName "C:\Working\Toll\TollGit\Toll Databases\Tranzbranch\Tranzbranch.sqlproj" -ProjectDisplayName "Tranzbranch.sqlproj"
# Get-Member -InputObject $collection
# $collection

# To group by project name and display each script file name on a different row of the result 
# table (as opposed to having the list of script file names appear as an array in a single row for 
# each project) we need to create PSCustomObjects with the following properties:
# ProjectName, ScriptFileName.
# A different custom object is needed for each ScriptFileName.

# Initially I tried creating these custom objects in the pipeline.  It's possible but messy, 
# requiring a nested ForEach-Object | Select-Object for each ScriptFileName.  See first cut 
# and function Get-UnbuiltItem.
# The pipeline can be simplified by creating the custom objects in the function that parses the 
# project file.  See second cut and function Get-UnbuiltItem2.

# The first cut of the pipeline statement.  It works but it's messy.
$results = Get-ChildItem $RootFolderPath -Recurse -File -Filter *.sqlproj |
    select-object @{Name="ProjectName"; Expression={ [System.IO.Path]::GetFileNameWithoutExtension($_.Name)}}, `
        @{Name="FullFileName"; Expression={Join-Path -Path $_.DirectoryName -ChildPath $_.Name}} |
    ForEach-Object { $projectName = $_.ProjectName 
                    Get-UnbuiltItem -FullProjectFileName $_.FullFileName |  
                        ForEach-Object { $_ | Select-Object @{Name="ProjectName"; Expression={$projectName}},
                                                            ScriptFileName
                                        }
                    }

# The second cut of the pipeline statement.  The modified Get-UnbuiltItem2 function removes the 
# need for the nested ForEeach-Object | Select-Object as it unrolls the list of script file names 
# for each project.
$results = Get-ChildItem $RootFolderPath -Recurse -File -Filter *.sqlproj |
    select-object @{Name="ProjectName"; Expression={ [System.IO.Path]::GetFileNameWithoutExtension($_.Name)}}, `
        @{Name="FullFileName"; Expression={Join-Path -Path $_.DirectoryName -ChildPath $_.Name}} |
    ForEach-Object { Get-UnbuiltItem2 -FullProjectFileName $_.FullFileName -ProjectDisplayName $_.ProjectName }

Write-Host

if ($results.Count -gt 0)
{
    $message = "$($results.Count) items found:"
    Write-Host $message -ForegroundColor "Yellow"
    Write-Host ("=" * $message.Length)
}
else
{
    Write-Host "NO NON-BUILT ITEMS FOUND" -ForegroundColor "Yellow"
} 

# Use the -Property parameter to exclude the column being grouped on from the result tables.  Only the specified 
# column(s) will appear in the result tables.
$results | Format-Table -GroupBy ProjectName -Property ScriptFileName

$endTime = Get-Date
$timeTaken = New-TimeSpan -Start $startTime -End $endTime
$timeTakenSeconds = $timeTaken.TotalSeconds

Write-Host
Write-Host "Finished in $timeTakenSeconds seconds"
