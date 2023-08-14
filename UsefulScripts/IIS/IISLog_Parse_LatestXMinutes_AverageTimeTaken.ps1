$currentDate = (get-date).ToString("yyMMdd")
$logFilePath = "C:\Users\here\Documents\IIS-log\u_ex$currentDate.log"
# For testing
$logFilePath = 'C:\inetpub\logs\LogFiles\W3SVC1\u_ex150409.log'

$cutoffOffsetMinutes = 5

# Skip comment lines at top of log file.
$logFileContents = (Get-Content $logFilePath).where({$_ -notLike "#[D,S-V]*" })

# Replace unwanted text in the line containing the columns.
$columnNames = (($logFileContents[0].TrimEnd()) -replace "#Fields: ", "").Split(" ")
$numberColumns = $columnNames.Count

# Get rows in log file from the last five minutes.
$cutoffTime = (Get-Date).AddMinutes(-1 * $cutoffOffsetMinutes).ToUniversalTime()
# For testing.
$cutoffTime = [DateTime]'2015-04-09 03:52:34'

$columnNamesToRetrieve = @('date', 'time', 'time-taken')
$timesTaken = @()

# Parse log file contents into table.  Only add desired columns in rows that are after 
# the specified cutoff time.
foreach ($logEntry in $logFileContents) 
{
    $logEntryColumns = $logEntry.split(' ')
    if ($logEntryColumns.Count -lt 5)
    {
        continue
    }
        
    $parsedDateOk = $False
    $parsedTimeOk = $False
    $parsedTimeTakenOk = $False
    [datetime]$parsedDate = [datetime]::MaxValue
    [timespan]$parsedTime = [timespan]::MaxValue
    [int]$parsedTimeTaken = 0
    for($i = 0; $i -lt $numberColumns; $i++)
    {
        $columnName = $columnNames[$i]
        if ($columnName -notin $columnNamesToRetrieve)
        {
            continue
        }

        if ($columnName -eq 'date')
        {
            $dateText = $logEntryColumns[$i]
            $parsedDateOk = [DateTime]::TryParse($dateText, [ref]$parsedDate)
            if (-not $parsedDateOk)
            {
                continue
            }
        }

        if ($columnName -eq 'time')
        {
            $timeText = $logEntryColumns[$i]
            $parsedTimeOk = [timespan]::TryParse($timeText, [ref]$parsedTime)
            if (-not $parsedTimeOk)
            {
                continue
            }
        }

        if ($columnName -eq 'time-taken')
        {
            $timeTakenText = $logEntryColumns[$i]
            $parsedTimeTakenOk = [int]::TryParse($timeTakenText, [ref]$parsedTimeTaken)
            if (-not $parsedTimeTakenOk)
            {
                continue
            }
        }
    }

    if (-not ($parsedDateOk -and $parsedTimeOk -and $parsedTimeTakenOk))
    {
        continue
    }

    $logEntryTime = $parsedDate + $parsedTime

    if ($logEntryTime -lt $cutoffTime)
    {
        continue
    }
    
    $timesTaken += $parsedTimeTaken
}

if ($timesTaken.count -eq 0)
{
    Write-Host "Unable to calculate average time taken from the IIS logs for the last $cutoffOffsetMinutes minutes."
}
else
{
    $averageTimetaken = ($timesTaken | Measure-Object -Average).Average
    Write-Host "Average request time (ms) for the last $cutoffOffsetMinutes minutes is: $averageTimetaken"
}
