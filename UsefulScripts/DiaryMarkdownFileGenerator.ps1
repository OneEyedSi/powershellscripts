<#
.SYNOPSIS
Prints date headings for a markdown diary or, alternatively, generates an entire empty diary file for 
a given year.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
Version:		1.0.0 
Date:			22 June 2024

#>

$_year = 2024
$_generateFile = $true
# For case-sensitive format codes see "Custom date and time format strings", 
# https://learn.microsoft.com/en-us/dotnet/standard/base-types/custom-date-and-time-format-strings
$_dateEntryDateFormat = 'ddd d MMM'

# Only used if $_generateFile is $false
$_printEntriesOnlySettings = @{
    StartDate='2021-06-07'
}

# Only used if $_generateFile is $true
$_fileSettings = @{
    FolderPath = "C:\Diary"
    FileNameTemplate = 'Diary_{year}.md'
    TitleTemplate = 'Diary, {year}'
    OverwriteExistingFile = $true
    # WARNING: Take care if you set this.  It may result in you deleting an existing diary file.
    OverwriteExistingFile = $false
}

# -------------------------------------------------------------------------------------------------
# No changes needed below this point; the remaining code is generic.
# -------------------------------------------------------------------------------------------------

function GetDateEntry([DateTime]$Date, [string]$DateEntryDateFormat)
{
    $dateText = $Date.ToString($DateEntryDateFormat)
    $underline = '-' * $dateText.Length

    $entryText = @"
    
$dateText
$underline

"@

    return $entryText
}

function GetDiaryBody([DateTime]$StartDate, [string]$DateEntryDateFormat)
{
    $year = $StartDate.Year
    $nextYear = $year + 1

    $diaryBody = ''

    $date = $StartDate
    # Want double line spacing between entries but only a single line between the title and the 
    # first entry.
    $lineSpacer = ''
    while ($date.Year -lt $nextYear)
    {
        $dateEntry = GetDateEntry -Date $date -DateEntryDateFormat $DateEntryDateFormat
        $diaryBody += $lineSpacer + $dateEntry

        $date = $date.AddDays(1)
        $lineSpacer = "`r`n"
    }

    return $diaryBody
}

function GetDiaryText([DateTime]$StartDate, [string]$DateEntryDateFormat, [string]$TitleTemplate)
{
    $year = $StartDate.Year
    $titleText = $TitleTemplate -replace '{year}',$year
    $underline = '=' * $titleText.Length

    $diaryBody = GetDiaryBody -StartDate $StartDate -DateEntryDateFormat $DateEntryDateFormat

    $diaryText = @"
$titleText
$underline
$diaryBody
"@

    # Strip the final CR-LF from the body text (is adding an extra blank line we don't want).
    $textToRemove = "`r`n"
    $lastIndex = $diaryText.LastIndexOf($textToRemove)
    if ($lastIndex)
    {
        $diaryText = $diaryText.Remove($lastIndex)
    }

    return $diaryText
}

function NewDiaryFile([hashtable]$FileSettings, [int]$Year, [string]$DateEntryDateFormat)
{
    $fileName = $FileSettings.FileNameTemplate -replace '{year}',$year
    $filePath = Join-Path -Path $FileSettings.FolderPath -ChildPath $fileName

    if (-not $FileSettings.OverwriteExistingFile -and (Test-Path -Path $filePath -PathType Leaf))
    {
        throw "File $filePath already exists and OverwriteExistingFile is False.  Aborting diary creation."
    }
    
    $startDate = [DateTime]::new($Year, 1, 1)
    $diaryText = GetDiaryText -StartDate $startDate -DateEntryDateFormat $DateEntryDateFormat `
                            -TitleTemplate $FileSettings.TitleTemplate
    
    $diaryText | Out-File -FilePath $filePath

    return $filePath
}

Clear-Host

if ($_generateFile)
{
    $newFilePath = NewDiaryFile -FileSettings $_fileSettings -Year $_year -DateEntryDateFormat $_dateEntryDateFormat
    Write-Host "New diary file created: $newFilePath"
}
else 
{
    $startDate = [DateTime]::Parse($_printEntriesOnlySettings.StartDate)
    $diaryBody = GetDiaryBody -StartDate $startDate -DateEntryDateFormat $_dateEntryDateFormat
    Write-Host $diaryBody
}
