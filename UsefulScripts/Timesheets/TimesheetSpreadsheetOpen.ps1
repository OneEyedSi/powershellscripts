<#
.SYNOPSIS
By default, opens a timesheet spreadsheet in Excel for the current timesheet period and creates 
it if it doesn't exist.  Optionally, spreadsheets from past or future weeks may be opened instead.

.DESCRIPTION
Opens one or two timesheet spreadsheets in Excel.  Normally there is only one spreadsheet per 
timesheet period.  However, if month-end falls during the timesheet period there will be two 
timesheets: one for the old month and one for the new.  

For the current timesheet period normally only the spreadsheet applicable to the current day 
will be opened.  If month-end falls during the week, and the current day is before month-end, 
then the spreadsheet for the old month will be opened.  If the current day is after month-end 
then the spreadsheet for the new month will be opened. 

For example, if the timesheet period starts on Monday 29 August 2022 and the current date is 
31 August 2022 then spreadsheet "Timesheets_WeekStarting_20220829.xlsx" would be opened.  Next 
day, on 1 September 2022 (which is in the same week/timesheet period), spreadsheet 
"Timesheets_WeekStarting_20220829_NewMonth.xlsx" would be opened.

Switch parameter -ShowPreviousMonthTimesheet can be used after month-end in the current 
timesheet period to open the spreadsheet for the old month, as well as the spreadsheet for 
the new month.  In the above example, if -ShowPreviousMonthTimesheet is set, both spreadsheets 
"Timesheets_WeekStarting_20220829.xlsx" and "Timesheets_WeekStarting_20220829_NewMonth.xlsx" 
would be opened.

If the spreadsheet for the current timesheet period doesn't exist then the script will create it 
by copying the specified template file and giving the copied spreadsheet the appropriate name.  
The new spreadsheet will then be opened.

Spreadsheets for previous or future weeks can be opened by setting the -NumberOfWeeksOffset 
parameter.  -NumberOfWeeksOffset 1 opens the spreadsheet(s) for next week, 
-NumberOfWeeksOffset -1 opens the spreadsheet(s) from last week, -NumberOfWeeksOffset -2 opens 
the spreadsheet(s) from 2 weeks ago, and so on.

If month-end falls during the specified previous week then both the spreadsheets for the old 
month and the new month will be opened.

If a spreadsheet for a previous week does not exist then a warning message will be displayed.  
However, the spreadsheet will not be created if it does not exist (unlike the spreadsheet for the 
current week).

If month-end falls during the specified future week then only the spreadsheet for the old month 
will be opened.  The spreadsheet for the new month will not be opened.  This is based on the 
assumption that the user will only need to open the first future spreadsheet, not any subsequent 
future spreadsheets.

If a spreadsheet for a future week does not exist then it will be created.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5 or greater (tested on versions 5.1 and 7.2.6)
Version:		3.0.0
Date:			13 Aug 2023

---------------------------------------------------------------------------------------------------
Licence (ISC Licence):
----------------------------------
Copyright (c) 2021 by Simon Elms

Permission to use, copy, modify, and/or distribute this software for any purpose with or 
without fee is hereby granted, provided that the above copyright notice and this permission 
notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS 
SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE 
AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES 
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, 
NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR 
PERFORMANCE OF THIS SOFTWARE.
---------------------------------------------------------------------------------------------------
Revisions:
----------
3.0.0   13 Aug 2023     Simon Elms      Replace script parameter -NumberOfWeeksInPast with 
                                        -NumberOfWeeksOffset to allow future spreadsheets to be 
                                        opened.

2.0.0   19 Sep 2022     Simon Elms      Rewritten to allow the script to open past timesheets as 
                                        well as the current one.  Script parameters added.

1.1.1   16 May 2021     Simon Elms      Bug fix: System.DayOfWeek enum starts at Sunday = 0, not 
                                        Monday = 1 as previously thought.

1.1.0	6 Apr 2021		Simon Elms		Handle second timesheet if new month starts during week.

1.0.0	10 Feb 2021		Simon Elms		Original version.
---------------------------------------------------------------------------------------------------

Naming Conventions in this Script: 
----------------------------------
To match the convention used in core PowerShell modules, function and script-level parameter names 
use PascalCase, with a leading capital.  

Local variable names within a function use camelCase, with a leading lowercase letter.  

Script-level variable names use _camelCase, with a leading underscore.

Function Design Philosophy:
----------------------------------
All functions are pure functions, relying only on their input parameters, not on variables 
declared outside the function.  For example, functions should not read script-level variables 
or parameters directly.  Instead, script-level variables or parameters should be passed into 
functions via function parameters.

In addition, functions do not modify values passed in as arguments.  Instead, updated values 
should be passed out via function return values.

This allows each function to be tested independently of higher level functions or script code.

.PARAMETER TimesheetTemplateFilePath
The path to the blank spreadsheet used as a template for creating new timesheet spreadsheets.

To create a new timesheet spreadsheet the template is copied and the copy is given an appropriate 
name.

The template file path may contain wildcard characters, such as '*'.  In that case the template 
file with the most recent version number will be used.

If the template file path is a relative path, it will be relative to the folder containing this 
script.

.PARAMETER TimesheetFilePattern
The pattern used to determine the filename of the timesheet spreadsheet to open.

Valid placeholders:
    {start date}:       The start date of the timesheet period.

    {new month text}:   If month-end falls in a timesheet period then two timesheets will exist, 
                        for the old month and the new one.  The two timesheet filenames will be 
                        almost identical, but will be distinguished by the text replacing the 
                        {new month text} placeholder.

If the pattern is a relative path, it will be relative to the folder containing this script.

.PARAMETER NumberOfWeeksOffset
Allows spreadsheets from future or previous weeks to be opened, as well as the spreadsheet(s) for 
the current week.  

For example, setting -NumberOfWeeksOffset 1 will open the spreadsheet for next week, while 
setting -NumberOfWeeksOffset -1 will open the spreadsheet(s) from last week. 

Leaving -NumberOfWeeksOffset unset, or setting it to 0, will open the spreadsheet(s) for the 
current week.

.PARAMETER ShowPreviousMonthTimesheet
If the current timesheet period includes month-end, and the current date is after month-end, then 
setting -ShowPreviousMonthTimesheet will open both spreadsheets for the current week: The one for 
the old month as well as the one for the new month.  If this parameter were not set then only the 
spreadsheet for the new month would be opened (since the current date is in the new month).

This parameter has no effect if the current date is before month-end.  In that case only the 
spreadsheet for the old month would be opened (since the new month has not started yet).  
-ShowPreviousMonthTimesheet would be ignored.

This parameter has no effect if the current timesheet period does not include month-end.  In that 
case there would be only one spreadsheet for the week, and that spreadsheet would be opened 
regardless of whether -ShowPreviousMonthTimesheet were set or not.

This parameter has no effect on spreadsheets from past weeks.  If opening the spreadsheets for a 
past week that includes month-end, both spreadsheets for that week would be opened, the one for 
the old month and the one for the new month, regardless of whether -ShowPreviousMonthTimesheet 
were set or not.

This parameter has no effect on spreadsheets from future weeks.  If opening the spreadsheet for a 
future week that includes month-end, only the first spreadsheet for that week would be opened, 
regardless of whether -ShowPreviousMonthTimesheet were set or not.
#>
Param
(    
  [string]$TimesheetTemplateFilePath = '.\Timesheets_WeekStarting_BLANK_*.xlsx',
  [string]$TimesheetFilePattern = 'C:\Users\SimonE\OneDrive - Datacom\Working\Datacom\Timesheets\Timesheets_WeekStarting_{start date}{new month text}.xlsx',
  [int]$NumberOfWeeksOffset,
  [switch]$ShowPreviousMonthTimesheet
)

function Test-PathIsAbsolute ($Path)
{
    # Can't use [system.io.path]::IsPathFullyQualified($Path) as that was introduced in .NET Core 2.1 
    # and Windows PowerShell 5.1 is built on top of .NET Framework 4.5.

    # [system.io.path]::IsPathRooted($Path) considers paths that start with a separator, such as 
    # "\MyFolder\Myfile.txt" to be rooted.  So we can't use IsPathRooted by itself to determine if a 
    # path is absolute or not.
    # Following code based on Stackoverflow answer https://stackoverflow.com/a/35046453/216440
    
    # GetPathRoot('\\MyServer\MyFolder\MyFile.txt') returns '\\MyServer\MyFolder', not a separator 
    # character.
    $pathRoot = [system.io.path]::GetPathRoot($Path)    
    $leadingCharacterIsSeparator = ($pathRoot.Equals([system.io.path]::DirectorySeparatorChar.ToString()) `
                                -or $pathRoot.Equals([system.io.path]::AltDirectorySeparatorChar.ToString()))
    $isPathAbsolute = ([system.io.path]::IsPathRooted($Path) -and -not $leadingCharacterIsSeparator)

    return $isPathAbsolute
}

function Get-AbsolutePath ($Path)
{
    if (-not $Path)
    {
        return $null
    }

    $Path = $Path.Trim()
    if (Test-PathIsAbsolute -Path $Path)
    {
        return $Path
    }

    if ($Path.StartsWith("."))
    {
        $Path = $Path.Substring(1)
    }

    # $PSScriptRoot returns the path to the folder containing this running script.
    return Join-Path -Path $PSScriptRoot -ChildPath $Path
}

<#
.SYNOPSIS
Determines whether to show the new month's timesheet, if month-end falls within the given 
timesheet period.

.DESCRIPTION
Will only return true if the specified timesheet is the current timesheet period or a past one, 
and month-end falls withing that timesheet period.  Will always return false for future timesheet 
periods, regardless of whether month-end falls within the timesheet period or not.  This is based 
on the assumption that the user is unlikely to need to view any timesheets after the first future 
one.
#>
function Test-ShowNewMonthTimesheetForWeek ($TimesheetStartDate)
{
    $timesheetEndDate = $TimesheetStartDate.AddDays(6)
    $testDate = $timesheetEndDate
    $currentDate = (Get-Date).Date
    $isFutureTimesheetPeriod = ($TimesheetStartDate -gt $currentDate)
    if (-not $isFutureTimesheetPeriod -and ($currentDate -lt $testDate))
    {
        $testDate = $currentDate
    }

    $showNewMonthTimesheet = (-not $isFutureTimesheetPeriod -and 
                            ($testDate.Month -gt $TimesheetStartDate.Month))
    return $showNewMonthTimesheet
}

<#
.SYNOPSIS
Gets the start date of the timesheet period, as well as whether a timesheet should be displayed 
for the new month, if month-end falls during the specified timesheet period.

.DESCRIPTION
If -NumberOfWeeksOffset is not supplied or is 0 then the start date of the current timesheet is 
returned.  Timesheets start on a Monday so if today is a Monday it returns today's date, otherwise 
it will return the date of the Monday within the last week.

If -NumberOfWeeksOffset is a positive integer then the date returned will be n weeks after the 
most recent Monday, where n is the value of -NumberOfWeeksOffset.  If -NumberOfWeeksOffset is a 
negative integer then the date returned will be n weeks before the most recent Monday.
#>
function Get-TimesheetDateInfo ([int]$NumberOfWeeksOffset)
{
    $currentDate = (Get-Date).Date
    $referenceDate = $currentDate
    if ($NumberOfWeeksOffset)
    {
        $referenceDate = $currentDate.AddDays(7 * $NumberOfWeeksOffset)
    }

    # In System.DayOfWeek enum Sunday is start of week = 0.
    # However, for timesheets Monday is start of week = 1.
    # So want Sunday to be part of previous week timesheet.
    $daysFromMonday = ($referenceDate.DayOfWeek.value__ + 6) % 7

    $timesheetStartDate = $referenceDate.AddDays(-1 * $daysFromMonday)
    $showNewMonthTimesheet = Test-ShowNewMonthTimesheetForWeek -TimesheetStartDate $timesheetStartDate

    return @{
                TimesheetPeriodStartDate = $timesheetStartDate
                ShowNewMonthTimesheet = $showNewMonthTimesheet
            }
}

function Get-TimesheetFilePath ($TimesheetFilePattern, $TimesheetPeriodStartDate, 
    [switch]$IsNewMonth)
{
    $startOfWeekDateText = $TimesheetPeriodStartDate.ToString('yyyyMMdd')
    $newMonthText = ''

    if ($IsNewMonth)
    {
        $newMonthText = '_NewMonth'
    }

    $timesheetFilePath = $TimesheetFilePattern -replace '{start date}',$startOfWeekDateText `
                                            -replace '{new month text}',$newMonthText

    return $timesheetFilePath
}

function New-TimesheetFile ($TimesheetTemplateFilePath, $TimesheetFilePath)
{
    # If there are multiple template files we only want the most recent 
    # (with the most recent version number).
    $templateFile = Get-Item -Path $TimesheetTemplateFilePath | 
                        Sort-Object Name -Descending | 
                        Select-Object -First 1

    if (-not $templateFile)
    {
        Write-Error "No template file found that matches pattern '$TimesheetTemplateFilePath'."
        return $false
    }

    try
    {
        Copy-Item -Path $templateFile.FullName -Destination $TimesheetFilePath
    }
    catch
    {
        Write-Error "Failed to create new timesheet file '$TimesheetFilePath' from template $($templateFile.FullName).  Error: $($_.Exception.Message)"
        return $false
    }

    return $true
}

function Get-TimesheetFile ($TimesheetTemplateFilePath, $TimesheetFilePath, $IsInPastTimesheetPeriod)
{
    if (-not (Test-Path $TimesheetFilePath))
    {
        $fileExists = $false
        if ($IsInPastTimesheetPeriod)
        {
            Write-Warning "Old timesheet file '$TimesheetFilePath' not found."
        }
        else
        {
            $fileExists = New-TimesheetFile -TimesheetTemplateFilePath $TimesheetTemplateFilePath `
                                -TimesheetFilePath $TimesheetFilePath
        }

        if (-not $fileExists)
        {
            return $null
        }
    }

    $timesheetFile = Get-Item -Path $TimesheetFilePath

    if (-not $timesheetFile)
    {
        Write-Error "Unable to retrieve timesheet file '$TimesheetFilePath'.  Unknown error."
        return $null
    }

    return $timesheetFile
}

function Show-Process($Process, $Hwnd, [Switch]$Maximize)
{
    # Based on code from following blog post:
    # https://community.idera.com/database-tools/powershell/powertips/b/tips/posts/bringing-window-in-the-foreground

    $sig = '
        [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
        [DllImport("user32.dll")] public static extern int SetForegroundWindow(IntPtr hwnd);
        '
  
    $Mode = if ($Maximize) { 3 } else { 4 }

    $type = Add-Type -MemberDefinition $sig -Name WindowAPI -PassThru

    if ($Process -and -not $Hwnd)
    {
        $Hwnd = $Process.MainWindowHandle
    }
    
    $null = $type::ShowWindowAsync($Hwnd, $Mode)
    $null = $type::SetForegroundWindow($Hwnd) 
}

function Open-Spreadsheet ($TimesheetTemplateFilePath, $TimesheetFilePath, $IsInPastTimesheetPeriod) 
{
    $timesheetFile = Get-TimesheetFile -TimesheetTemplateFilePath $TimesheetTemplateFilePath `
                        -TimesheetFilePath $TimesheetFilePath `
                        -IsInPastTimesheetPeriod $IsInPastTimesheetPeriod

    if (-not $timesheetFile)
    {
        return
    }

    try
    {
        $excel = New-Object -ComObject Excel.Application
    }
    catch
    {
        Write-Error "Error opening Excel: $($_.Exception.Message)"
        return
    }

    try
    {
        $workbook = $excel.Workbooks.Open($timesheetFile.FullName)

        if ($workbook)
        {
            $excel.Visible = $true
            Write-Host "Workbook '$($timesheetFile.FullName)' should now be open." -ForegroundColor Yellow
        }
        else
        {
            Write-Error "Workbook '$($timesheetFile.FullName)' does not appear to have opened in Excel: Unknown error."
            return
        }
    }
    catch
    {
        Write-Error "Error opening spreadsheet '$($timesheetFile.FullName)' in Excel: $($_.Exception.Message)"
        return
    }

    try
    {
        Show-Process -Hwnd $excel.Hwnd -Maximize
    }
    catch
    {
         Write-Error "Error maximising spreadsheet '$($timesheetFile.FullName)': $($_.Exception.Message)"
    }
}

function Open-TimesheetFile ($TimesheetTemplateFilePath, $TimesheetFilePattern, 
    [int]$NumberOfWeeksOffset, [switch]$ShowPreviousMonthTimesheet)
{
    $TimesheetTemplateFilePath = Get-AbsolutePath -Path $TimesheetTemplateFilePath
    $TimesheetFilePattern = Get-AbsolutePath -Path $TimesheetFilePattern

    $isInPastTimesheetPeriod = ($NumberOfWeeksOffset -lt 0)
    $isInFutureTimesheetPeriod = ($NumberOfWeeksOffset -gt 0)

    $timesheetDateInfo = Get-TimesheetDateInfo $NumberOfWeeksOffset

    $showTimesheetFromStartOfWeek = $ShowPreviousMonthTimesheet

    # For previous timesheet periods always show the timesheet from the start of the timesheet 
    # period (there may be two timesheets if month-end falls during the timesheet period).
    # For the current timesheet period always show the timesheet from the start of the timesheet 
    # period if there is no second timesheet to display.
    # For future timesheet periods always show the timesheet from the start of the timesheet 
    # period.
    if ($isInPastTimesheetPeriod -or $isInFutureTimesheetPeriod -or 
        -not $timesheetDateInfo.ShowNewMonthTimesheet)
    {
        $showTimesheetFromStartOfWeek = $true
    }

    if ($showTimesheetFromStartOfWeek)
    {
        $timesheetFilePath = Get-TimesheetFilePath -TimesheetFilePattern $TimesheetFilePattern `
                                -TimesheetPeriodStartDate $timesheetDateInfo.TimesheetPeriodStartDate
        
        Open-Spreadsheet -TimesheetTemplateFilePath $TimesheetTemplateFilePath `
            -TimesheetFilePath $timesheetFilePath -IsInPastTimesheetPeriod $isInPastTimesheetPeriod
    }
    
    # If month-end occurs during the timesheet period and it's past month-end then display the 
    # timesheet for the new month.
    if ($timesheetDateInfo.ShowNewMonthTimesheet)
    {
        $timesheetFilePath = Get-TimesheetFilePath -TimesheetFilePattern $TimesheetFilePattern `
                            -TimesheetPeriodStartDate $timesheetDateInfo.TimesheetPeriodStartDate `
                            -IsNewMonth

        Open-Spreadsheet -TimesheetTemplateFilePath $TimesheetTemplateFilePath `
            -TimesheetFilePath $timesheetFilePath -IsInPastTimesheetPeriod $isInPastTimesheetPeriod
    }
}

Clear-Host

Open-TimesheetFile -TimesheetTemplateFilePath $TimesheetTemplateFilePath `
    -TimesheetFilePattern $TimesheetFilePattern `
    -NumberOfWeeksOffset $NumberOfWeeksOffset `
    -ShowPreviousMonthTimesheet:$ShowPreviousMonthTimesheet


