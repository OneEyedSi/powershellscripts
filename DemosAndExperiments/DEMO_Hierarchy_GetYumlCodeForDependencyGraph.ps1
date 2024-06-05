<#
.SYNOPSIS
Converts a hierarchy into code for a Yuml dependency diagram.

.DESCRIPTION
Takes an array of tuples, where each tuple represents a parent and its child, and outputs code 
that can be copied into https://yuml.me to create a dependency diagram.  Each layer in the 
diagram is colour-coded to highlight the different levels in the hierarchy.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
Version:		1.0.0 
Date:			11 May 2024

#>

# Each tuple: (parent, child)
$dependencies = @(
                    (1, 2),
                    (1, 3),
                    (1, 4),
                    (1, 6),
                    (1, 7),
                    (1, 8),
                    (1, 9),
                    (1, 10),
                    (1, 11),
                    (1, 12),
                    (1, 13),
                    (1, 14),
                    (1, 15),
                    (1, 16),
                    (1, 17),
                    (1, 18),
                    (1, 20),
                    (1, 21),
                    (1, 22),
                    (1, 24),
                    (2, 6),
                    (3, 6),
                    (4, 6),
                    (4, 5),
                    (7, 8),
                    (7, 9),
                    (10, 9),
                    (11, 12),
                    (13, 14),
                    (15, 16),
                    (17, 18),
                    (17, 19),
                    (20, 21),
                    (20, 23)
                )

function GetHierarchyLevels ($Dependencies)
{
    $levels = @{}

    $workingLevel = 0
    $workingDependencies = $Dependencies.Clone()
    $parents = $workingDependencies | ForEach-Object {$_[0]} | Select-Object -Unique
    $children = $workingDependencies | ForEach-Object {$_[1]} | Select-Object -Unique

    while ($parents.Length -gt 0 -and $workingLevel -le 50)
    {
        $orphans = $parents | Where-Object { $_ -notin $children }
        if ($orphans)
        {
            $orphans | ForEach-Object { $levels[$_] = $workingLevel }
            
            $orphansChildren = $workingDependencies | Where-Object { $_[0] -in $orphans } | 
                ForEach-Object {$_[1]} | Where-Object { $_ -ne 0 } | Select-Object -Unique

            $parents = $parents | Where-Object { $_ -notin $orphans }
            if ($orphansChildren)
            {
                $parents += $orphansChildren
                $parents = $parents | Select-Object -Unique
            }

            $workingDependencies = $workingDependencies | Where-Object { $_[0] -notin $orphans }
            $children = $workingDependencies | ForEach-Object {$_[1]} | Select-Object -Unique
        }
        $workingLevel++
    }

    return $levels
}

function GetHierarchyLevelColour($LevelNumber)
{
    $colours = @('magenta', 'mediumblue', 'cyan', `
        'lawngreen', 'yellow', 'darkorange', 'red', 'brown')

    $numberColours = $colours.Count
    $colourIndex = $LevelNumber % $numberColours
    $colour = $colours[$colourIndex]
    return $colour
}

function GetYumlRelationship($Dependency, $Levels)
{
    $parent = $Dependency[0]
    $child = $Dependency[1]
    $parentLevel = $Levels[$parent]
    $childLevel = $Levels[$child]
    $parentColour = GetHierarchyLevelColour $parentLevel
    $childColour = GetHierarchyLevelColour $childLevel
    $relationship = "[$parent{bg:$parentColour}]->[$child{bg:$childColour}]"
    return $relationship
}

function GetYumlDependencyGraph($Dependencies, $Levels)
{
    $graphs = @()
    
    $Dependencies | ForEach-Object { $graphs += GetYumlRelationship -Dependency $_ -Levels $Levels }

    return $graphs
}

Clear-Host

$levels = GetHierarchyLevels -Dependencies $dependencies
$graphs = GetYumlDependencyGraph -Dependencies $dependencies -Levels $levels
$graphs