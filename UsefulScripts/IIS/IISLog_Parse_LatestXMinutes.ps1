$currentDate = (get-date).ToString("yyMMdd")
$logFilePath = "C:\Users\here\Documents\IIS-log\u_ex$currentDate.log"
# For testing
$logFilePath = 'C:\inetpub\logs\LogFiles\W3SVC1\u_ex150409.log'

# Skip comment lines at top of log file.
$logFileContents = (Get-Content $logFilePath).where({$_ -notLike "#[D,S-V]*" })

# Replace unwanted text in the line containing the columns.
$columnNames = (($logFileContents[0].TrimEnd()) -replace "#Fields: ", "").Split(" ")
$numberColumns = $columnNames.Count

# Get rows in log file from the last five minutes.
$cutoffTime = (Get-Date).AddMinutes(-5).ToUniversalTime()
# For testing.
$cutoffTime = [DateTime]'2015-04-09 03:52:34'

# Create a DataTable to write the log contents into.
$columnNamesToRetrieve = @('date','time','cs-uri-stem','cs-uri-query','sc-status','time-taken')
$logTable = New-Object System.Data.DataTable "IISLog"
foreach ($name in $columnNames) 
{
    if ($name -notin $columnNamesToRetrieve)
    {
        continue
    }
    $newColumn = New-Object System.Data.DataColumn $name, ([string])
    $logTable.Columns.Add($newColumn)
}

# Parse log file contents into table.  Only add desired columns in rows that are after 
# the specified cutoff time.
foreach ($logEntry in $logFileContents) 
{
    $logEntryColumns = $logEntry.split(' ')
    if ($logEntryColumns.Count -lt 5)
    {
        continue
    }

    $logTableRow = $logTable.NewRow()
    $parsedDateOk = $False
    $parsedTimeOk = $False
    [datetime]$parsedDate = [datetime]::MaxValue
    [timespan]$parsedTime = [timespan]::MaxValue
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

        $logTableRow[$columnName] = $logEntryColumns[$i]
    }

    if (-not ($parsedDateOk -and $parsedTimeOk))
    {
        continue
    }

    $logEntryTime = $parsedDate + $parsedTime

    if ($logEntryTime -lt $cutoffTime)
    {
        continue
    }
    
    $logTable.Rows.Add($logTableRow)
}

$logTable

