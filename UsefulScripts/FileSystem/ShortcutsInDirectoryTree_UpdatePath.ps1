<#
.SYNOPSIS
Updates the paths in all shortcuts in a specified folder. 

.DESCRIPTION
This script will iterate through all files in a specified folder, optionally recursing through 
sub-folders, to find *.lnk shortcut files.  It will update both the Target and Start-in paths, 
replacing the specified original text with the new text. 

.NOTES
Author:			Simon Elms
Version:		1.1.0 
Date:			13 Aug 2022
Requires:		PowerShell 7.2.5 or later 

Based on Stackoverflow answer https://stackoverflow.com/a/21967566/216440, an answer to 
question "Editing shortcut (.lnk) properties with Powershell", 
https://stackoverflow.com/questions/484560/editing-shortcut-lnk-properties-with-powershell

#>

$folderPath = 'C:\KeyboardShortcuts'
$originalPathSegment = 'SimonE\Documents'
$replacementPathSegment = 'SimonsDocuments'
$recurse = $true
$whatIf = $true

Clear-Host

$linkFiles = Get-ChildItem $folderPath -File -Filter *.lnk -Recurse:$recurse

if (-not $linkFiles)
{
    Write-Host 'No matching files found.'
    return
}

$shell = New-Object -COM WScript.Shell

foreach ($file in $linkFiles)
{
    $link = $shell.CreateShortcut($file.FullName)
    $escapedPathSegment = [RegEx]::Escape($originalPathSegment)

    $originalTargetPath = $link.TargetPath
    $newTargetPath = $originalTargetPath -replace $escapedPathSegment,$replacementPathSegment
    
    $originalArguments = $link.Arguments
    $newArguments = $originalArguments -replace $escapedPathSegment,$replacementPathSegment
        
    $originalWorkingDirectory = $link.WorkingDirectory
    $newWorkingDirectory = $originalWorkingDirectory -replace $escapedPathSegment,$replacementPathSegment

    $targetPathChanged = ($originalTargetPath -ne $newTargetPath)
    $argumentsSet = ($originalArguments)
    $argumentsChanged = ($argumentsSet -and ($originalArguments -ne $newArguments))
    $workingDirSet = ($originalWorkingDirectory)
    $workingDirChanged = ($workingDirSet -and ($originalWorkingDirectory -ne $newWorkingDirectory))

    if ($whatIf)
    {
        $name = $link.FullName
        Write-Host $name
        Write-Host ('-' * $name.Length)

        if ($targetPathChanged)
        {
            Write-Host 'Target Path:' 
            Write-Host "From: $originalTargetPath"
            Write-Host "To: $newTargetPath"
        }
        else 
        {
            Write-Host "Target Path: UNCHANGED - $originalTargetPath"
        }
        
        if ($argumentsSet)
        {
            if ($argumentsChanged)
            {
                Write-Host 'Arguments:'
                Write-Host "From: $originalArguments"
                Write-Host "To: $newArguments"
            }
            else 
            {
                Write-Host "Arguments: UNCHANGED - $originalArguments"
            }       
        }
        else 
        {            
            Write-Host "Arguments: NOT SET"
        }
        
        if ($workingDirSet)
        {
            if ($workingDirChanged)
            {
                Write-Host 'Working Dir:'
                Write-Host "From: $originalWorkingDirectory"
                Write-Host "To: $newWorkingDirectory"
            }
            else 
            {
                Write-Host "Working Dir: UNCHANGED - $originalWorkingDirectory"
            }       
        }
        else 
        {            
            Write-Host "Working Dir: NOT SET"
        }

        Write-Host
        continue
    }

    if ($targetPathChanged -or $argumentsChanged -or $workingDirChanged)
    {
        $link.TargetPath = $newTargetPath
        $link.Arguments = $newArguments
        $link.WorkingDirectory = $newWorkingDirectory
        $link.Save()
    }
}

Write-Host "COMPLETE"