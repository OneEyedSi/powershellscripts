<#
.SYNOPSIS
Finds and replaces text in files in a directory tree.

.DESCRIPTION
Finds and replaces the specified text in files under a specified root directory.  Recursively 
searches for files in sub-folders, sub-sub-folders, etc.  The files to update can be filtered via 
a regular expression:  Only file names that match the regular expression are selected to be 
updated.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1 or greater (tested on versions 5.1 and 7.2.6)
Version:		2.0.0
Date:			4 Nov 2022

Naming Conventions in this Script: 
To match the convention used in core PowerShell modules, function and script-level parameter names 
use PascalCase, with a leading capital.  

Local variable names use camelCase, with a leading lowercase letter.

---------------------------------------------------------------------------------------------------
Revisions
------------------
Versioning scheme (Semantic Versioning): major.minor.patch
	Major number: incremented for breaking changes (mainly in the variables set by user);
	Minor number: incremented for non-breaking changes;
	Patch number: incremented for bug fixes and minor corrections.
------------------
2.0.0   4 Nov 2022      Simon Elms      Rewritten to allow multiple find+replace operations on each 
                                        file.

1.0.0	??      		Simon Elms		Original version.
---------------------------------------------------------------------------------------------------
#>

$rootFolderPath = "C:\Temp"
$fileNameFilter = "1669707620smiley-classic-icon_cyan6.svg"
$textToFindAndReplacement = @(
                                # Element 0: Text to find; element 1: Replacement text
                                @("fill:#f75e1e", "fill:#1feef4"),
                                @("fill:#f7941e", "fill:#20eef4"),
                                @("fill:#f7951e", "fill:#22eef4"),
                                @("fill:#f7961d", "fill:#24eef4"),
                                @("fill:#f7971d", "fill:#26eef4"),
                                @("fill:#f7981d", "fill:#27eef4"),
                                @("fill:#f7991c", "fill:#29eff4"),
                                @("fill:#f89a1c", "fill:#2beff4"),
                                @("fill:#f89b1c", "fill:#2deff4"),
                                @("fill:#f89c1b", "fill:#2eeff4"),
                                @("fill:#f89d1b", "fill:#30eff4"),
                                @("fill:#f89e1b", "fill:#32eff4"),
                                @("fill:#f89f1b", "fill:#34f0f5"),
                                @("fill:#f8a01a", "fill:#35f0f5"),
                                @("fill:#f8a11a", "fill:#37f0f5"),
                                @("fill:#f8a21a", "fill:#39f0f5"),
                                @("fill:#f8a319", "fill:#3bf0f5"),
                                @("fill:#f8a419", "fill:#3cf1f5"),
                                @("fill:#f8a519", "fill:#3ef1f5"),
                                @("fill:#f9a618", "fill:#40f1f5"),
                                @("fill:#f9a718", "fill:#42f1f5"),
                                @("fill:#f9a818", "fill:#43f1f5"),
                                @("fill:#f9a917", "fill:#45f1f5"),
                                @("fill:#f9aa17", "fill:#47f2f5"),
                                @("fill:#f9ab17", "fill:#49f2f6"),
                                @("fill:#f9ac16", "fill:#4af2f6"),
                                @("fill:#f9ad16", "fill:#4cf2f6"),
                                @("fill:#f9ae16", "fill:#4ef2f6"),
                                @("fill:#f9af15", "fill:#50f2f6"),
                                @("fill:#f9b015", "fill:#51f3f6"),
                                @("fill:#f9b115", "fill:#53f3f6"),
                                @("fill:#fab215", "fill:#55f3f6"),
                                @("fill:#fab314", "fill:#57f3f6"),
                                @("fill:#fab414", "fill:#58f3f6"),
                                @("fill:#fab514", "fill:#5af4f6"),
                                @("fill:#fab613", "fill:#5cf4f6"),
                                @("fill:#fab713", "fill:#5ef4f7"),
                                @("fill:#fab813", "fill:#5ff4f7"),
                                @("fill:#fab912", "fill:#61f4f7"),
                                @("fill:#faba12", "fill:#63f4f7"),
                                @("fill:#fabb12", "fill:#65f5f7"),
                                @("fill:#fabc11", "fill:#66f5f7"),
                                @("fill:#fabd11", "fill:#68f5f7"),
                                @("fill:#fbbe11", "fill:#6af5f7"),
                                @("fill:#fbbf10", "fill:#6cf5f7"),
                                @("fill:#fbc010", "fill:#6df5f7"),
                                @("fill:#fbc110", "fill:#6ff6f7"),
                                @("fill:#fbc20f", "fill:#71f6f7"),
                                @("fill:#fbc30f", "fill:#73f6f8"),
                                @("fill:#fbc30f", "fill:#74f6f8"),
                                @("fill:#fbc40f", "fill:#76f6f8"),
                                @("fill:#fbc50e", "fill:#78f7f8"),
                                @("fill:#fbc60e", "fill:#7af7f8"),
                                @("fill:#fbc70e", "fill:#7bf7f8"),
                                @("fill:#fbc80d", "fill:#7df7f8"),
                                @("fill:#fcc90d", "fill:#7ff7f8"),
                                @("fill:#fcca0d", "fill:#81f7f8"),
                                @("fill:#fccb0c", "fill:#82f8f8"),
                                @("fill:#fccc0c", "fill:#84f8f8"),
                                @("fill:#fccd0c", "fill:#86f8f8"),
                                @("fill:#fcce0b", "fill:#88f8f9"),
                                @("fill:#fccf0b", "fill:#89f8f9"),
                                @("fill:#fcd00b", "fill:#8bf8f9"),
                                @("fill:#fcd10a", "fill:#8df9f9"),
                                @("fill:#fcd20a", "fill:#8ff9f9"),
                                @("fill:#fcd30a", "fill:#90f9f9"),
                                @("fill:#fcd409", "fill:#92f9f9"),
                                @("fill:#fdd509", "fill:#94f9f9"),
                                @("fill:#fdd609", "fill:#96faf9"),
                                @("fill:#fdd709", "fill:#97faf9"),
                                @("fill:#fdd808", "fill:#99faf9"),
                                @("fill:#fdd908", "fill:#9bfaf9"),
                                @("fill:#fdda08", "fill:#9dfafa"),
                                @("fill:#fddb07", "fill:#9efafa"),
                                @("fill:#fddc07", "fill:#a0fbfa"),
                                @("fill:#fddd07", "fill:#a2fbfa"),
                                @("fill:#fdde06", "fill:#a4fbfa"),
                                @("fill:#fddf06", "fill:#a5fbfa"),
                                @("fill:#fde006", "fill:#a7fbfa"),
                                @("fill:#fee105", "fill:#a9fbfa"),
                                @("fill:#fee205", "fill:#abfcfa"),
                                @("fill:#fee305", "fill:#acfcfa"),
                                @("fill:#fee404", "fill:#aefcfa"),
                                @("fill:#fee504", "fill:#b0fcfa"),
                                @("fill:#fee604", "fill:#b2fcfb"),
                                @("fill:#fee703", "fill:#b3fdfb"),
                                @("fill:#fee803", "fill:#b5fdfb"),
                                @("fill:#fee903", "fill:#b7fdfb"),
                                @("fill:#feea03", "fill:#b9fdfb"),
                                @("fill:#feeb02", "fill:#bafdfb"),
                                @("fill:#feec02", "fill:#bcfdfb"),
                                @("fill:#ffed02", "fill:#befefb"),
                                @("fill:#ffee01", "fill:#c0fefb"),
                                @("fill:#ffef01", "fill:#c1fefb"),
                                @("fill:#fff001", "fill:#c3fefb"),
                                @("fill:#fff100", "fill:#c5fefb"),
                                @("fill:#fff200", "fill:#c7fffc")
                                
                            )

Clear-Host

$matchingFiles = Get-ChildItem $rootFolderPath -Filter $fileNameFilter -Recurse 
foreach($file in $matchingFiles)
{
    Write-Host "Processing file $file..."

    $initialHash = Get-FileHash $file.PSPath

    # Raw switch is needed when replacing CR-LF because, by default, the contents are returned as 
    # an array of strings broken at a linefeed.  The Raw switch returns the entire contents as a 
    # single string.
    $fileContent = (Get-Content $file.PsPath -Raw)
    foreach($findAndReplacementPair in $textToFindAndReplacement)
    {
       $fileContent = $fileContent -replace $findAndReplacementPair[0],$findAndReplacementPair[1]
    }
    Set-Content -Path $file.PsPath -Value $fileContent

    $finalHash = Get-FileHash $file.PSPath

    if ($finalHash.Hash -eq $initialHash.Hash)
    {
        Write-Host "Text not found; file not updated"
    }
    else
    {
        Write-Host "File updated"
    }
    Write-Host ""
}