<#
.SYNOPSIS
Opens the current diary file.

.DESCRIPTION
Opens the current diary file.  If the diary file doesn't exist it will be created and then opened.

The $_year variable at the head of the script can be set to a specific year to open the diary for that year.  For example:
    $_year = 2023

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
Version:		1.0.0 
Date:			11 Aug 2024

#>

$_year = [datetime]::Now.Year
$_generateFile = $true
# For case-sensitive format codes see "Custom date and time format strings", 
# https://learn.microsoft.com/en-us/dotnet/standard/base-types/custom-date-and-time-format-strings
$_dateEntryDateFormat = 'ddd d MMM'

$_fileSettings = @{
    FolderPath = "C:\Diary"
    FileNameTemplate = 'Diary_{year}.md'
    TitleTemplate = 'Diary, {year}'
}

# -------------------------------------------------------------------------------------------------
# No changes needed below this point; the remaining code is generic.
# -------------------------------------------------------------------------------------------------

function GetDateText([DateTime]$Date, [string]$DateEntryDateFormat)
{
    return $Date.ToString($DateEntryDateFormat)
}

function GetDateHeading([DateTime]$Date, [string]$DateEntryDateFormat)
{
    $dateText = GetDateText $Date $DateEntryDateFormat
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
        $dateEntry = GetDateHeading -Date $date -DateEntryDateFormat $DateEntryDateFormat
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

function NewDiaryFile([string]$FilePath, [hashtable]$FileSettings, [int]$Year, [string]$DateEntryDateFormat)
{
    $startDate = [DateTime]::new($Year, 1, 1)
    $diaryText = GetDiaryText -StartDate $startDate -DateEntryDateFormat $DateEntryDateFormat `
                            -TitleTemplate $FileSettings.TitleTemplate
    
    $diaryText | Out-File -FilePath $FilePath
}

function OpenDiaryFile([hashtable]$FileSettings, [int]$Year, [string]$DateEntryDateFormat)
{
    $fileName = $FileSettings.FileNameTemplate -replace '{year}',$Year
    $filePath = Join-Path -Path $FileSettings.FolderPath -ChildPath $fileName

    if (-not (Test-Path -Path $filePath -PathType Leaf))
    {
        NewDiaryFile $filePath $FileSettings $Year $DateEntryDateFormat
    }

    Invoke-Item -LiteralPath $filePath

    return $filePath
}

Clear-Host

$filePath = OpenDiaryFile -FileSettings $_fileSettings -Year $_year -DateEntryDateFormat $_dateEntryDateFormat
Write-Host "Diary file $filePath should now be open for editing."
