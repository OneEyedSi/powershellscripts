<#
.SYNOPSIS
Finds all files in the tree under the root directory with the specified name.

.DESCRIPTION
This script recursively searches files in the root directory, sub-directories of the root, 
sub-sub-directories, etc, for the specified file name.

The specified file name may include the "*" and "?" wildcards but does not support regular 
expressions.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
Version:		1.0.0 
Date:			6 Sep 2020

This script requires PowerShell 5.1 to allow it to handle paths longer than the Windows 
MAX_PATH value of 260 characters.

Note the use of the -Filter parameter for Get-ChildItem, rather than the -Include parameter.
-Filter is implemented in the FileSystem provider.  -Include in implemented in PowerShell.  So 
-Filter is more efficient because it only returns the filtered results to PowerShell, whereas 
-Include returns all results then filters them in PowerShell.  

See Stackoverflow post "Difference between -include and -filter in get-childitem", 
https://stackoverflow.com/questions/28600923/difference-between-include-and-filter-in-get-childitem

#>
Clear-Host

$RootDirectoryPath = 'C:\Temp'
$FileNameToFind = '*.etf'

# These workarounds for viewing long paths were specified in the following Stackoverflow 
#   thread: "Handling Path Too Long Exception with New-PSDrive", 
#   https://stackoverflow.com/questions/46308030/handling-path-too-long-exception-with-new-psdrive/ 

# Path with a drive letter, eg "C:\sss\xxx.txt"
if ($RootDirectoryPath -match '^\w:')
{
    $RootDirectoryPath = '\\?\' + $RootDirectoryPath
}
# UNC path, eg "\\aaa\sss\xxx.txt"
elseif ($RootDirectoryPath -match '^\\\\')
{
    $RootDirectoryPath = '\\?\UNC\' + $RootDirectoryPath
}

# To view paths longer than MAX_PATH characters must use -LiteralPath parameter, not -Path.
Get-ChildItem -LiteralPath $RootDirectoryPath -Filter $FileNameToFind -File -Recurse