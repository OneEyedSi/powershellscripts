<#
.SYNOPSIS
Rename all files under a specified directory tree, including files in sub-directories.
#>
$rootFolderPath = 'C:\Azure\ExamPrep_AnkiQuestionsAndLists'
$filter = '*_ClozeListsAndDeletions.txt'
$originalText = 'AndDeletions'
$newText = ''
$renameFiles = $true
$renameDirectories = $false
$recurse = $false
$whatIf = $false

Get-ChildItem $rootFolderPath -Filter $filter -Recurse:$recurse -File:$renameFiles -Directory:$renameDirectories |
    Rename-Item -NewName { $_.Name -replace $originalText, $newText } -WhatIf:$whatIf