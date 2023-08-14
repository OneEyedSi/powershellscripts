<#
.SYNOPSIS
Tests SQL connectivity without using Invoke-Sqlcmd.

.NOTES
***LACKS ERROR-HANDLING--do not use against Prod for fear of dangling connections.***

Blake Burgess C/O Datacom South Island
04 October 2017.

BlakeB@datacom.co.nz

#>
$sqlConnectionStrings = @(
                            "Database=DummyDB;Server=DummyServer;Trusted_Connection=True;Application Name=OnTime2.Account.Services.UAT;"
                        )
$query = "select top (2) name from sys.tables;"

Clear-Host
$allOk = $true

foreach ($connectionString in $sqlConnectionStrings) {
	
    Write-Host 
	Write-Host "Testing connection string $connectionString..." -ForegroundColor Yellow
	
	$dt = New-Object System.Data.DataTable
	$conn = New-Object System.Data.SqlClient.SqlConnection

    try
    {
	    $conn.ConnectionString = $connectionString
	    $conn.Open();

	    $cmd = New-Object System.Data.SqlClient.SqlCommand
	    $cmd.Connection = $conn
	    $cmd.CommandText = $query

	    $r = $cmd.ExecuteReader()
        
        $consoleTextColor = "Green"
        $resultText = "Connection OK"
        if (-not $r.HasRows)
        {
            $allOk = $false
            $consoleTextColor = "Red"
            $resultText = "Connection FAILED"
        }
        
	    $dt.Load($r)
        $dt | ft -a

        Write-Host $resultText -ForegroundColor $consoleTextColor
    }
    catch 
    {
        Write-Host $_.Exception.Message -ForegroundColor Red
        $allOk = $false
    }
    finally
    {
        if ($conn -ne $null)
        {
            $conn.Dispose()
        }
    }
}

Write-Host 
$resultText = "ALL CONNECTIONS OK"
$consoleTextColor = "Green"
if (-not $allOk)
{
    $resultText = "ERROR: AT LEAST ONE CONNECTION FAILED"
    $consoleTextColor = "Red"
}
Write-Host $resultText -ForegroundColor $consoleTextColor