<#
.SYNOPSIS
Searches the contents of all files in the tree under the root directory for the specified text.

.DESCRIPTION
This script recursively searches files in the root directory, sub-directories of the root, 
sub-sub-directories, etc, for the specified text.  It searches for the specified text in the 
contents of the files, not in the file names.

The text to find is a regex pattern, not plain text.  So, for example, to search for references 
to 'MyFile.txt' you would need to escape the ".": 'MyFile\.txt'.

The variable $IsCaseSensitive determines whether the search is case-sensitive or not. 

Specified file names and directory names can be excluded from the search.  The file names and 
directory names to exclude are specified via regex patterns, not plain text.

This script requires PowerShell 5.1 to allow it to handle paths longer than the Windows 
MAX_PATH value of 260 characters.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 4.0
Version:		1.5.0 
Date:			11 Dec 2018

.PARAMETER RootDirectoryPath
The directory at the root of the directory tree that will be searched.

.PARAMETER RegexPatternToFind
The text to find in the contents of the files being searched.  Only the contents of the files are 
searched for the specified text, not the file names.  The text to find is a .NET regex pattern, 
not plain text.

.PARAMETER IsCaseSensitive
Determines whether the search will only return text that matches the case of the text to find, 
or whether the script will ignore case when performing the search.

.PARAMETER DirectoryNamesToExclude
An array of directory names to exclude from the search.  Each directory name is a .NET regex 
pattern, not plain text.

.PARAMETER FileNamesToExclude
An array of file names to exclude from the search.  Each file name is a .NET regex pattern, 
not plain text.

.PARAMETER DoPressKeyToFinish
Set to $true to display the "Finished in ... seconds" text in Visual Studio Code.  For the 
PowerShell console or PowerShell ISE there is no need to set this variable; it's only a 
work-around needed for Visual Studio Code.

#>

# To map a local drive to a drive letter, enter the following from a command prompt: 
#        net use x: \\localhost\c$\Working\Toll
        
$RootDirectoryPath = "C:\PowerShell\DemosAndExperiments"

$RegexPatternToFind = 'Param'

$IsCaseSensitive = $false

$DirectoryNamesToExclude = @(
                            'bin'
                            'obj'
                            'testResults'
                            '\.vs'
                            '\.vscode'
                            '\.git'
                            )

$FileNamesToExclude = @(
                        '.*\.bin'
						'.*\.dat'
						'.*\.ncb'
						'.*\.obj'
						'.*\.ost'
						'.*\.pch'
						'.*\.sdf'
						'.*\.cd'
						'.*\.dll'
						'.*\.msi'
						'.*\.pdb'
						'.*\.cab'
						'.*\.sln'
						'.*\.doc'
						'.*\.docx'
						#'.*\.txt'
						#'.*\.log'
						'.*\.jfm'
						'DevExpress.*\.xml'
						'.*\.Publish\.xml'
						'.*\.user'
						'.*\.datasource'
						'.*\.pubxml'
						'.*\.wsdl'
						'.*\.disco'
						'.*\.dacpac'
						'.*\.dbmdl'
						'.*\.refactorlog'
						'jquery.*\.js'
						'.*\.discomap'
						'.*\.png'
						'.*\.jpg'
						'.*\.gif'
						'bootstrap\.js'
						'.*\.min\.js'
						'.*\.less'
						'.*\.eot'
						'.*\.woff'
						'.*\.exe$' # includes trailing "$" so that it excludes "*.exe" but allows through "*.exe.config".
						'.*Microsoft\.Practices.*\.xml'
						'.*\.zip'
						'.*\.wav'
						'.*\.nupkg'
						'.*\.resx'
						'.*\.xls'
						'.*\.xlsx'
						'.*\.mht'
						'.*\.pdf'
						'.*\.7z'
						'.*ReferenceTablesPopulate.sql'          
                        )

Clear-Host

$startTime = Get-Date
Write-Host "Started..." -ForegroundColor Yellow

$DirectoryNamesToExcludeRegexPattern = '(\\)*(' + ($DirectoryNamesToExclude -join '|') + ')(\\)*'
$FileNamesToExcludeRegexPattern = '(' + ($FileNamesToExclude -join '|') + ')'

$RootDirectoryPath = $RootDirectoryPath.Trim()

# Notes:
# Name property is only filename, including extension, without path.  So to exclude folders 
#   need to filter the DirectoryName property.
$matchInfo = Get-ChildItem $RootDirectoryPath -Recurse -File |
    where { $_.DirectoryName -notmatch $DirectoryNamesToExcludeRegexPattern `
            -and $_.Name -notmatch $FileNamesToExcludeRegexPattern } |
    select-string $RegexPatternToFind -AllMatches -CaseSensitive:$IsCaseSensitive 

$matchInfo | format-table LineNumber, Line -GroupBy Path

$numberMatchingFiles = (($matchInfo | Group-Object Path) | Measure-Object).Count
$numberOfMatches = ($matchInfo | Measure-Object).Count
Write-Host "Found $numberOfMatches matches in $numberMatchingFiles files" -ForegroundColor Yellow

$endTime = Get-Date
$timeTaken = New-TimeSpan -Start $startTime -End $endTime
$timeTakenSeconds = $timeTaken.TotalSeconds

Write-Host "Finished in $timeTakenSeconds seconds" -ForegroundColor Yellow

if ($DoPressKeyToFinish)
{
    # Needed for Visual Studio Code, otherwise the Write-Host "Finished..." is not displayed, for 
    # some reason (the Write-Host "Started..." is displayed, as are the Format-Table results; it's 
    # only the Write-Host after the results that isn't displayed.  Works fine in PowerShell Console 
    # and PowerShell ISE, just not Visual Studio Code).
    Read-Host "Press any key to continue..."
}