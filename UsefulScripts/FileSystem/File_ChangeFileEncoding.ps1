<#
.SYNOPSIS
Changes a file's encoding by copying it to a destination file with a different encoding.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
Version:		1.0.0 
Date:			9 Oct 2024

You can check file encoding by opening the file in either Visual Studio Code or Azure Data Studio.
The file encoding is shown near the far right of the status bar.

#>

$encoding = 'UTF8NoBOM'
$sourceFilePath = 'C:\Temp\Smartly\GetUserDetails.sql'
$destinationFilePath = 'C:\Temp\Smartly\UTF8\GetUserDetails.sql'

Get-Content $sourceFilePath | Out-File -Encoding $encoding $destinationFilePath