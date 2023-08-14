<#
.SYNOPSIS
Counts the number of lines in files under a specified root directory.

.DESCRIPTION
This script recursively searches for files in the root directory, sub-directories of the root, 
sub-sub-directories, etc, that match the specified file name regex pattern.  For each matching 
file it then counts the number of lines in the file.

It performs two parallel counts: One of all lines in each matching file, and a second of lines 
which excludes lines matching a regex pattern.  This allows us to exclude blank lines and 
comment lines.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
Version:		1.0.0 
Date:			17 Apr 2019

.PARAMETER RootDirectoryPath
The directory at the root of the directory tree that will be searched.

.PARAMETER FileNameRegexPattern
A regex pattern which file names must match to be included in the line count.

.PARAMETER LinesToExcludeRegexPattern
A regex pattern which files must NOT match, to be included in the "useful" line count.

.PARAMETER DirectoryNamesToExclude
An array of directory names to exclude from the search.  Each directory name is a .NET regex 
pattern, not plain text.

#>
$RootDirectoryPath = "C:\Temp"

$FileNameRegexPattern = '*.cs'
$LinesToExcludeRegexPattern = '^\s*(//.*)*$'

$DirectoryNamesToExclude = @(
                            'bin'
                            'obj'
                            'testResults'
                            '\.vs'
                            '\.vscode'
                            '\.git'
                            )

Clear-Host

$DirectoryNamesToExcludeRegexPattern = '(\\)*(' + ($DirectoryNamesToExclude -join '|') + ')(\\)*'

$cumulativeLines = 0 
$cumulativeUsefulLines = 0
$results = @()
Get-ChildItem $RootDirectoryPath -Filter $FileNameRegexPattern -Recurse -File | 
    Where-Object { $_.DirectoryName -notmatch $DirectoryNamesToExcludeRegexPattern } |
    ForEach-Object {
                    $numberLines = (Get-Content $_.FullName).Count
                    # Exclude blank lines and lines that start with // (ie comments).  Too difficult to handle block comments.
                    $numberLinesToExclude = (select-string -Pattern $LinesToExcludeRegexPattern -Path $_.FullName).Count
                    $numberUsefulLines = $numberLines - $numberLinesToExclude
                    $cumulativeLines += $numberLines
                    $cumulativeUsefulLines += $numberUsefulLines
                    $results += @{
                                    Name=$_.Name
                                    DirectoryName=$_.DirectoryName
                                    NumberOfLines=$numberLines
                                    NumberOfUsefulLines=$numberUsefulLines
                                    CumulativeLines=$cumulativeLines
                                    CumulativeUsefulLines=$cumulativeUsefulLines
                                }
                    }
$results.ForEach({[PSCustomObject]$_}) | 
    Format-Table -AutoSize -Property Name, NumberOfLines, NumberOfUsefulLines -GroupBy DirectoryName

Write-Host
Write-Host 'Cumulative Totals:' -ForegroundColor Green
Write-Host '------------------' -ForegroundColor Green
Write-Host "All Lines: `t`t$cumulativeLines" -ForegroundColor Green
Write-Host "Useful Lines: `t$cumulativeUsefulLines" -ForegroundColor Green