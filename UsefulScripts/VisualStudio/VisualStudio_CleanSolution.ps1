<#
.SYNOPSIS
Cleans a Visual Studio solution by removing the .vs directory and bin/obj directories.

.DESCRIPTION
Cleans a Visual Studio solution by removing the .vs directory and bin/obj directories.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
Version:		1.0.0
Date:			23 Mar 2026

#>

$_solutionFilePath = "C:\Projects\Test.sln"

$rootFolderPath = Split-Path -Path $_solutionFilePath -Parent

# Need to use -Force to ensure we get hidden .vs folder.
Get-ChildItem -Path $rootFolderPath -Include '.vs','bin','obj' -Directory -Recurse -Force | Remove-Item -Recurse -Force