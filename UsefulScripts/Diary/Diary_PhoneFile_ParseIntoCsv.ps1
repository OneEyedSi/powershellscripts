<#
.SYNOPSIS
Reads the diary file from the phone, parses each line and writes the output to a CSV file.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 7.6
Version:		1.0.0 
Date:			6 May 2026

I've been recording diary entries on my phone for several years, as a basic text file.  I copied 
the file to my laptop and now want to parse it and convert it to a CSV file to make it easier 
to copy the contents into a spreadsheet and my Markdown diary.

Sample lines in the file:

M 15/5/2023 87.7 2500
Tu 16/5 87.5 2800 Atc giving out foil fundraiser
M 5/6 none 3400 Lunch w K then drive home. K said didn't sleep much thinking of workmates and accident, reckoned had 3 h sleep in 3 d
F 9/6 89 1300 bike to cemetery 27m 53s
Sa 10/6

So columns are:
    1) Required: 1 or 2 character abbreviation of day of week
    2) Required: Date as either d/m or d/m/yyyy
    3) Optional: Weight as either a number or 'none' (without quotes)
    4) Optional: Steps as a number
    5) Optional: Notes

#>

$diaryFilePath = 'C:\Temp\Diary2023-2026.txt'
$csvFilePath = 'C:\Temp\Diary2023-2026.csv'

# DayOfWeek: Required. 1 or 2 upper or lower case letters
# DayMonth: Required. {1 or 2 digits}/{1 or 2 digits}
# Year: Optional. Non-capturing group starting with /, followed by capture group to capture 4-digit year
# Weight: Optional. Non-capturing group starting with a space, 
#                   followed by capture group to capture either "none" or {digits followed by optional decimal place and further digits}
# Steps: Optional. Non-capturing group starting with a space, followed by capture group to capture several digits
# Notes: Optional. Non-capturing group starting with a space, followed by capture group that captures any characters
$regexPattern = '^(?<DayOfWeek>[a-z|A-Z]{1,2}) (?<DayMonth>\d{1,2}/\d{1,2})(?:/(?<Year>\d{4}))?(?: (?<Weight>none|\d+(?:\.\d+)?))?(?: (?<Steps>\d+))?(?: (?<Notes>.*))?$'

$contents = Get-Content $diaryFilePath

$year = '1234'
$placeholder = 'none'
$parsedEntries = foreach ($line in $contents) 
{
    if ($line -match $regexPattern) 
    {
        $weight = $placeholder
        $steps = $placeholder

        if ($matches['Year']) 
        {
            $year = $matches['Year']
        }
        if ($matches['Weight']) 
        {
            $weight = $matches['Weight']
        }
        if ($matches['Steps']) 
        {
            $steps = $matches['Steps']
        }
        [PSCustomObject]@{
            DayOfWeek = $matches['DayOfWeek']
            Date = $matches['DayMonth'] + '/' + $year
            Year = $year
            Weight = $weight
            Steps = $steps
            Notes = $matches['Notes']
        }
    }
}

$parsedEntries | Export-Csv -Path $csvFilePath -NoTypeInformation