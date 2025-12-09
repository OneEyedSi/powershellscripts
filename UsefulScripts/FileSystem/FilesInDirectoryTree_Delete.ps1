<#
.SYNOPSIS
Recursively deletes files in specified root directory and in all sub-folders, sub-sub-folders, etc.

.DESCRIPTION
Recursively deletes files in specified root directory and in all sub-folders, sub-sub-folders, etc.

The filename pattern determines which files are to be deleted.  To delete all files set the 
pattern to '*.*'.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
Version:		1.0.0 
Date:			5 Aug 2023

#>
$RootDirectoryPath = "C:\Temp\DeleteCopiesDemo"
$FileNamePattern = '* - Copy.*'

Clear-Host

# Remove the -WhatIf once you've confirmed the correct files are being targeted for deletion.
Get-ChildItem $RootDirectoryPath -Filter $FileNamePattern -Recurse -File | Remove-Item -WhatIf