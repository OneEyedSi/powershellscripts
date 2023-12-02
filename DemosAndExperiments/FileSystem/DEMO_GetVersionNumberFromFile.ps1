<#
.SYNOPSIS
Reads a version number from a text file and converts it into an array of parts.

.DESCRIPTION
Expects the version number to be of the form "1", "1.2", "1.2.3", or "1.2.3.4".  

Also compares two version numbers of the form "1.2.3.4", to determine whether a file should be 
updated or not.

.OUTPUTS
The array of parts returned will have 1-4 elements, each of which is an integer.

If no version number is found $Null is returned.

.NOTES 
Expects Lorem.txt to be in the same folder as this script.
#>

#region Helper Functions **************************************************************************

function Write-Title ($TitleText)
{
    Write-Host
    Write-Host $TitleText
    Write-Host ("-" * $TitleText.Length)
}

function Write-TimeTaken ([datetime]$StartTime)
{
    $endTime = Get-Date
    $timeTaken = New-TimeSpan -Start $StartTime -End $endTime

    Write-Host "Finished in $($timeTaken.TotalSeconds) seconds" -ForegroundColor Yellow
}

#endregion

#region Main Functions ****************************************************************************

function Get-ScriptVersionNumber (
    [string]$ScriptPath
    )
{     
    $versionArray = @(0, 0, 0, 0)

    if (-not (Test-Path $ScriptPath))
    {
        return $versionArray
    }

    # Regex Pattern to retrieve version number from a line of text:
    #    ^                  The text matching the pattern must be at the start of the line
    #    \s*                Optional whitespaces (zero or more)
    #    #*                 Optional "#" characters (zero or more)
    #    \s*                Optional whitespaces (zero or more)
    #    Version            Required word "Version" (NB: We're doing a case-insensitive comparison)
    #    \s*                Optional whitespaces (zero or more)
    #    :                  Required character ":"
    #    \s*                Optional whitespaces (zero or more)
    #    (                  Start of capture group to capture the version number
    #      \d{1,12}         Required 1-12 digits
    #      (?:\.\d{1,12}){0,3}    Optional non-capturing group: period (fullstop) followed by 1-12 
    #                             digits.  The group may appear 0-3 times
    #    )                  End of capture group to capture the version number

    # So we're looking for lines that start something like:
    <#

        #   Version  :   1.10.2.345678
      ^ ^ ^         ^  ^   ^
      | | |         |  |   |
      | |  \        | /    Number can have 1-4 parts
      | | Optional spaces
      | One or more "#"
      Optional spaces

      or       
            Version  :   1.10.2.345678
            (as above but without any "#" at the start of the line, for version numbers embedded 
            in block comments)

      A minimal version might be (without any spaces, and with only one part to the version number):

      #Version:1

    #> 
     
    $matchInfo = Select-String -Path $ScriptPath -Pattern '^\s*#*\s*Version\s*:\s*(\d{1,12}(?:\.\d{1,12}){0,3})'

    if (-not $matchInfo)
    {
        return $versionArray
    }

    # We're only interested in the first match.
    $match = $matchInfo.Matches[0]

    # Group 0 is the whole match, group 1 is the text from the capture group.
    if ($match.Groups.Count -eq 1)
    {
        return $versionArray
    }

    $versionNumberText = $match.Groups[1].Value
    $tempArray = $versionNumberText.Split('.').ForEach([int])

    # Ensure array returned has four parts.  If not pad with trailing zeros.
    for($i=0; $i -lt $tempArray.Count; $i++)
    {
        $versionArray[$i] = $tempArray[$i]
    }

    return $versionArray
}

function Test-FileNeedsUpdate (
    [array]$ExistingFileVersionArray, 
    [array]$NewFileVersionArray
    )
{    
    if (-not $ExistingFileVersionArray -or $ExistingFileVersionArray.Count -eq 0)
    {
        return $True
    }

    if (-not $NewFileVersionArray -or $NewFileVersionArray.Count -eq 0)
    {
        return $False
    }

    for($i=0; $i -lt 4; $i++)
    {
        $existingNumber = $ExistingFileVersionArray[$i]
        $newNumber = $NewFileVersionArray[$i]

        if ($existingNumber -lt $newNumber)
        {
            return $True
        }
        if ($existingNumber -gt $newNumber)
        {
            return $False
        }
    }

    # All four parts of the version numbers are identical so no need to upgrade.
    return $False
}

#endregion

#region Test Functions ****************************************************************************

function Write-VersionTestResult (
    [array]$ExistingFileVersionArray, 
    [array]$NewFileVersionArray
    )
{   
    Write-Host 
    Write-Host "Existing number: $($ExistingFileVersionArray -join '.')"
    Write-Host "New number: $($NewFileVersionArray -join '.')"

    Write-Host "Should file be updated: $(Test-FileNeedsUpdate $ExistingFileVersionArray $NewFileVersionArray)"
}

#endregion

Clear-Host

$versionNumberArray = Get-ScriptVersionNumber "$PSScriptRoot\Lorem.txt"

if (-not $versionNumberArray)
{
    Write-Host 'No version number found.'
    exit 0
}

Write-Host "Number of parts in version number: $($versionNumberArray.Count)."

Write-Host 'Version number parts:'
Foreach($part in $versionNumberArray)
{
    Write-Host "Value: ${part}; Type: $($part.GetType().FullName)"
}

Write-VersionTestResult @(0, 0, 0, 0) @(0, 0, 0, 0)

Write-VersionTestResult @(0, 0, 0, 1) @(0, 0, 0, 0)
Write-VersionTestResult @(0, 0, 1, 0) @(0, 0, 0, 0)
Write-VersionTestResult @(0, 1, 0, 0) @(0, 0, 0, 0)
Write-VersionTestResult @(1, 0, 0, 0) @(0, 0, 0, 0)

Write-VersionTestResult @(0, 0, 0, 0) @(0, 0, 0, 1)
Write-VersionTestResult @(0, 0, 0, 0) @(0, 0, 1, 0)
Write-VersionTestResult @(0, 0, 0, 0) @(0, 1, 0, 0)
Write-VersionTestResult @(0, 0, 0, 0) @(1, 0, 0, 0)

Write-VersionTestResult @(1, 2, 33, 44) @(1, 2, 33, 44)
Write-VersionTestResult @(1, 2, 33, 44) @(1, 3, 0, 0)