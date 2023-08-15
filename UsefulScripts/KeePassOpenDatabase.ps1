<#
.SYNOPSIS
Open the latest KeePass database.

.DESCRIPTION
Opens the latest version of a KeePass database.  As at August 2023 can open one database:

1. SimonsDatabase_xxx.kdbx:  Personal passwords and accounts.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5
Version:		1.0.1
Date:			10 Feb 2021

#>
Param
(
  [string]$DatabaseNameToOpen
)

$_keePassFolderPath = 'C:\KeePass'

$_database = @{
                Simon = 'SimonsDatabase_*.kdbx' 
            }

$_keePassExecutablePath = 'C:\Program Files (x86)\KeePass Password Safe 2\KeePass.exe'

# -------------------------------------------------------------------------------------------------
# NO NEED TO CHANGE ANYTHING BELOW THIS POINT, THE REMAINDER OF THE CODE IS GENERIC.
# -------------------------------------------------------------------------------------------------

function Open-KeePassDatabase ($KeePassExecutablePath, $DatabaseFolderPath, $DatabaseFilePattern)
{
    $databaseFilePath = Join-Path -Path $DatabaseFolderPath -ChildPath $DatabaseFilePattern

    # If there are multiple database files we only want the most recent 
    # (with the most recent version number).
    $databaseFile = Get-Item -Path $databaseFilePath | 
                        Sort-Object Name -Descending | 
                        Select-Object -First 1

    Start-Process $keePassExecutablePath $databaseFile.FullName
}

function Open-NamedDatabase ($DatabaseNameToOpen)
{
    $databaseFileToOpen = $_database[$DatabaseNameToOpen]

    Open-KeePassDatabase $_keePassExecutablePath $_keePassFolderPath $databaseFileToOpen
}

Open-NamedDatabase $DatabaseNameToOpen
