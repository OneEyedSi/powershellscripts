<#
.SYNOPSIS
By default, opens a timesheet spreadsheet in Excel for the current timesheet week, creating it 
if it doesn't exist.  Optionally, spreadsheets from past or future weeks may be opened instead.

.DESCRIPTION
Opens one or two timesheet spreadsheets in Excel.  Normally there is only one spreadsheet per 
timesheet week.  However, if month-end falls during the timesheet week there may be two 
timesheets: one for the old month and one for the new.

The script supports two timesheet patterns:
1. One timesheet per week, regardless of whether month-end falls within the timesheet week or not. 
2. One timesheet per week, except when month-end falls within the timesheet week.  In that case 
there will be two timesheets in the week, one for the old month and a second for the new month.

Which pattern is followed is determined by switch parameter -SplitWeekAtStartOfMonth.  If this 
switch parameter is not set then only one timesheet will be created for the timesheet week that 
month-end falls in.  If -SplitWeekAtStartOfMonth is set then a second timesheet will be created 
when month-end falls within the timesheet week.

Regardless of whether -SplitWeekAtStartOfMonth is set or not, for the current timesheet week 
normally only the spreadsheet applicable to the current day will be opened.  If 
-SplitWeekAtStartOfMonth is set and month-end falls during the week, and the current day is before 
month-end, then the spreadsheet for the old month will be opened.  If the current day is after 
month-end then the spreadsheet for the new month will be opened. 

For example, if -SplitWeekAtStartOfMonth is set and the timesheet week starts on Monday 
29 August 2022 and the current date is 31 August 2022 then spreadsheet 
"Timesheets_WeekStarting_20220829.xlsx" is opened.  Next day, on 1 September 2022 (which is 
in the same timesheet week), spreadsheet "Timesheets_WeekStarting_20220829_NewMonth.xlsx" would be 
opened.

Switch parameter -ShowPreviousMonthTimesheet only applies if -SplitWeekAtStartOfMonth is set. 
If -SplitWeekAtStartOfMonth is set then -ShowPreviousMonthTimesheet can be used after month-end in 
the current timesheet week to open the spreadsheet for the old month, as well as the spreadsheet 
for the new month.  

In the above example on 1 September 2022, if both -SplitWeekAtStartOfMonth and 
-ShowPreviousMonthTimesheet were set, both spreadsheets "Timesheets_WeekStarting_20220829.xlsx" and 
"Timesheets_WeekStarting_20220829_NewMonth.xlsx" would be opened.  If -ShowPreviousMonthTimesheet 
were not set then only spreadsheet "Timesheets_WeekStarting_20220829_NewMonth.xlsx" would be 
opened.

If the spreadsheet for the current timesheet week doesn't exist then the script will create it 
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
Version:		3.1.0
Date:			3 May 2025

---------------------------------------------------------------------------------------------------
Licence (MIT Licence):
----------------------------------
Copyright (c) 2021 by Simon Elms

Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
and associated documentation files (the "Software"), to deal in the Software without 
restriction, including without limitation the rights to use, copy, modify, merge, publish, 
distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the 
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or 
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING 
BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND 
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
---------------------------------------------------------------------------------------------------
Revisions:
----------
Versioning scheme (Semantic Versioning): major.minor.patch
	Major number: incremented for breaking changes (mainly if parameters are removed or changed);
	Minor number: incremented for non-breaking changes;
	Patch number: incremented for changes that don't affect functionality (for example, changes to 
                    comments) or for bug fixes.
----------
3.1.0   2 May 2025      Simon Elms      Add parameter -SplitWeekAtStartOfMonth to allow for a 
                                        second timesheet pattern, which has only one timesheet 
                                        for a timesheet week that includes month-end.

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
    {start date}:       The start date of the timesheet week.

    {new month text}:   If month-end falls in a timesheet week then two timesheets will exist, 
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

.PARAMETER SplitWeekAtStartOfMonth
Setting -SplitWeekAtStartOfMonth will create a new spreadsheet on the first day of the month, 
if the first day of the month falls in the middle of a working week.  If this parameter were not 
set then, on the first of the month, the same timesheet that was created at the start of the week 
would be opened.

.PARAMETER ShowPreviousMonthTimesheet
If the current timesheet week includes month-end, and the current date is after month-end, then 
setting -ShowPreviousMonthTimesheet will open both spreadsheets for the current week: The one for 
the old month as well as the one for the new month.  If this parameter were not set then only the 
spreadsheet for the new month would be opened (since the current date is in the new month).

This parameter has no effect if the current timesheet week does not include month-end.  In that 
case there would be only one spreadsheet for the week, and that spreadsheet would be opened 
regardless of whether -ShowPreviousMonthTimesheet were set or not.

This parameter has no effect if parameter -SplitWeekAtStartOfMonth is not set.  In that case there 
would be only one spreadsheet for the week, and that spreadsheet would be opened regardless of 
whether -ShowPreviousMonthTimesheet were set or not.

This parameter has no effect if the current date is before month-end.  In that case only the 
spreadsheet for the old month would be opened (since the new month has not started yet).  
-ShowPreviousMonthTimesheet would be ignored.

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
  [switch]$SplitWeekAtStartOfMonth,
  [switch]$ShowPreviousMonthTimesheet
)

# --------------------------------------------------------------------------------------------------------------------------
# No changes needed below this point; the remaining code is generic.
# --------------------------------------------------------------------------------------------------------------------------

<#
.SYNOPSIS
Determines whether the specified path is an absolute path or a relative one.

.DESCRIPTION

.NOTES
We cannot use [system.io.path]::IsPathFullyQualified($Path) as that was introduced in .NET Core 2.1 
and Windows PowerShell 5.1 is built on top of .NET Framework 4.5.

[system.io.path]::IsPathRooted($Path) considers paths that start with a separator, such as 
"\MyFolder\Myfile.txt" to be rooted.  So we can't use IsPathRooted by itself to determine if a path 
is absolute or not.

This function is based on Stackoverflow answer https://stackoverflow.com/a/35046453/216440.
#>
function Test-PathIsAbsolute ([string]$Path)
{
    # GetPathRoot('\\MyServer\MyFolder\MyFile.txt') returns '\\MyServer\MyFolder', not a separator 
    # character.
    $pathRoot = [system.io.path]::GetPathRoot($Path)    
    $leadingCharacterIsSeparator = ($pathRoot.Equals([system.io.path]::DirectorySeparatorChar.ToString()) `
                                -or $pathRoot.Equals([system.io.path]::AltDirectorySeparatorChar.ToString()))
    $isPathAbsolute = ([system.io.path]::IsPathRooted($Path) -and -not $leadingCharacterIsSeparator)

    return $isPathAbsolute
}

<#
.SYNOPSIS
Converts the specified path to an absolute path.

.DESCRIPTION
If the specified path is absolute it is returned unchanged.  If the specified path is relative it 
will be converted to absolute.  Relative paths are considered to be rooted on the folder 
containing this script when it runs.
#>
function Get-AbsolutePath ([string]$Path)
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
timesheet week.

.DESCRIPTION
If -SplitWeekAtStartOfMonth is false then the function will always return $false.  Otherwise, it 
will only return $true if the specified timesheet is in the current timesheet week or a past 
one, and month-end falls withing that timesheet week.  

The function will always return $false for future timesheet weeks, regardless of whether 
month-end falls within the timesheet week or not.  This is based on the assumption that the 
user is unlikely to need to view any timesheets after the first future one.
#>
function Test-ShowNewMonthTimesheetForWeek ([datetime]$TimesheetStartDate, 
    [switch]$SplitWeekAtStartOfMonth)
{
    if (-not $SplitWeekAtStartOfMonth)
    {
        return $false
    }

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
Gets the start date of the timesheet week, as well as whether a timesheet should be displayed 
for the new month, if month-end falls during the specified timesheet week.

.DESCRIPTION
If -NumberOfWeeksOffset is not supplied or is 0 then the start date of the current timesheet is 
returned.  Timesheets start on a Monday so if today is a Monday it returns today's date, otherwise 
it will return the date of the Monday within the last week.

If -NumberOfWeeksOffset is a positive integer then the date returned will be n weeks after the 
most recent Monday, where n is the value of -NumberOfWeeksOffset.  If -NumberOfWeeksOffset is a 
negative integer then the date returned will be n weeks before the most recent Monday.

If -SplitWeekAtStartOfMonth is not set then the value of ShowNewMonthTimesheet returned will 
always be $false.
#>
function Get-TimesheetDateInfo ([int]$NumberOfWeeksOffset, [switch]$SplitWeekAtStartOfMonth)
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
    $showNewMonthTimesheet = Test-ShowNewMonthTimesheetForWeek `
        -TimesheetStartDate $timesheetStartDate -SplitWeekAtStartOfMonth:$SplitWeekAtStartOfMonth

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
    [int]$NumberOfWeeksOffset, [switch]$SplitWeekAtStartOfMonth, 
    [switch]$ShowPreviousMonthTimesheet)
{
    $TimesheetTemplateFilePath = Get-AbsolutePath -Path $TimesheetTemplateFilePath
    $TimesheetFilePattern = Get-AbsolutePath -Path $TimesheetFilePattern

    $isInPastTimesheetPeriod = ($NumberOfWeeksOffset -lt 0)
    $isInFutureTimesheetPeriod = ($NumberOfWeeksOffset -gt 0)

    $timesheetDateInfo = Get-TimesheetDateInfo -NumberOfWeeksOffset $NumberOfWeeksOffset `
        -SplitWeekAtStartOfMonth:$SplitWeekAtStartOfMonth

    $showTimesheetFromStartOfWeek = $SplitWeekAtStartOfMonth -and $ShowPreviousMonthTimesheet

    # For previous timesheet weeks always show the timesheet from the start of the timesheet 
    # period (there may be two timesheets if month-end falls during the timesheet week).
    # For the current timesheet week always show the timesheet from the start of the timesheet 
    # period if there is no second timesheet to display.
    # For future timesheet weeks always show the timesheet from the start of the timesheet 
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
    
    # If month-end occurs during the timesheet week and it's past month-end then display the 
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
    -SplitWeekAtStartOfMonth:$SplitWeekAtStartOfMonth `
    -ShowPreviousMonthTimesheet:$ShowPreviousMonthTimesheet


