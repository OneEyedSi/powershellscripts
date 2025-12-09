<#
.SYNOPSIS
Changes file encoding by copying files from a source directory to a destination directory with a 
different encoding.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
Version:		2.0.0 
Date:			3 Oct 2025

You can check file encoding by opening the file in Visual Studio Code.  The file encoding is shown 
near the far right of the status bar.

To copy only one file, set $sourceFilter to the file name, e.g. 'MyFile.txt'.

To manually change the file encoding of a file in Visual Studio Code, left-click on the encoding in the 
status bar, then select "Save with Encoding" from the dropdown menu and choose the desired encoding.

For a list of supported encodings see Out-File > Encoding section at, 
https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/out-file?view=powershell-7.5#-encoding ,

Common ones are:
    'ascii' - 7-bit ASCII
    'utf8' - UTF-8 with BOM
    'utf8NoBOM' - UTF-8 without BOM
    'utf7' - UTF-7
    'utf32' - UTF-32 with BOM
    'bigendianutf32' - UTF-32BE with BOM
    'unicode' - UTF-16LE with BOM
    'bigendianunicode' - UTF-16BE with BOM

#>


$encoding = 'utf8NoBOM'
$sourceDirectoryPath = 'C:\Temp\UTF8BOM'
$destinationDirectoryPath = 'C:\Temp\UTF8NoBOM'
$sourceFilter = '*.txt'

Get-ChildItem -Path $sourceDirectoryPath -Filter $sourceFilter -File | 
    ForEach-Object {
        $sourceFilePath = $_.FullName
        $destinationFilePath = Join-Path -Path $destinationDirectoryPath -ChildPath $_.Name
        Write-Host "Copying file using encoding ${encoding}: $($_.FullName)"
        Get-Content $sourceFilePath | Out-File -Encoding $encoding $destinationFilePath
    }