<#
.SYNOPSIS
Runs specified SQL scripts against a SQL Server instance selected from a menu by the user.

.DESCRIPTION
The names of the SQL scripts to run must be listed at the top of this script, in the order in 
which they are to run (so, for example, list a script that creates a table before a script that 
creates a trigger on that table).  

As the SQL scripts are run the results are output to both the PowerShell console and to a log 
file, which can be kept as a record of the results of a deployment.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5 or greater (tested on version 5.1)
                sqlcmd, the SQL Server Commandline Utility, which needs to be on the Windows PATH.
                SqlServer PowerShell module (install from PowerShell Gallery, not installed as 
                                            part of SQL Server)
Version:		1.2.0
Date:			11 Oct 2022

When listing the SQL script file names, the file extensions are optional.  So a SQL script file 
name could be either like "script_name.sql" or simply "script_name".

The SQL scripts to run need to be in the same folder as this script.

This script does not need to be run on the SQL Server that is being updated.  It will connect to 
the server selected by the user as long as it can access that server remotely.

Permissions Required:
The login used to run the SQL scripts on the selected SQL Server should have the following 
permissions as a minimum:

    In the databases the scripts will execute in:
        Membership of the db_ddladmin database role;
        Membership of the db_datareader and db_datawriter database roles.

This will allow the SQL scripts run by this PowerShell script to create, update or delete 
database objects such as tables, views, stored procedures, functions and triggers.  It will also 
allow reading data from and writing data to tables in the database.

If the SQL scripts run by this PowerShell script will create, update or delete database users or 
roles, or change their permissions, the login will need the following additional permissions:

    In the databases the scripts will execute in:
        Either ALTER ANY USER permission or membership of the db_accessadmin database role;
        Either ALTER ANY ROLE permission or membership of the db_securityadmin database role.

Note that all the above permissions are included if the login is granted db_owner permissions on 
the database.

If the SQL scripts run by this PowerShell script will create, update or delete SQL Server logins, 
the login used to run the SQL scripts on the selected SQL Server will need the following 
additional permissions:

    At the server level:
        Either ALTER ANY LOGIN permission or membership of the securityadmin server role.

Naming Conventions in this Script: 
Parameters in this script at the script level and at the function level use PascalCase, with a 
leading capital.  This is to match the convention used in core PowerShell modules, which use 
PascalCase for parameters.  Local variables within a function use camelCase, with a leading 
lowercase letter.  Script-level variables use _camelCase, with a leading underscore.

WARNING: 
There is a bug in Invoke-Sqlcmd where an error in a SQL SELECT statement, such as 
"SELECT 1/0 AS Bang", will not be output to Invoke-Sqlcmd.  Worse, it will prevent other errors 
that follow it in the script from being output as well.  So if there is an error in a SELECT 
statement in a script that script will always appear to run successfully unless there is another 
error before the SELECT error.  Errors that do NOT originate in a SELECT statement, such as 
"Cannot drop the table 'dbo.MyTable', because it does not exist or you do not have permission." 
do not have this problem.

#>

$sqlScriptNames = @(
                    "SqlCmdVarTest"
                    "CodeStatus"
                    "Site"
                    )

# No changes needed below this point; the remaining code is generic.

# NOTE: All servers and credentials listed below are dummies, used for 
# illustration only.  They do not really exist.
[System.Object[]]$sqlServers = @(
                                    @{
                                        key="L"; 
                                        serverName="(localdb)\mssqllocaldb"; 
                                        useWindowsAuthentication=$True; 
                                        serverType="LOCALDB"; 
                                        menuText="(L)ocaldb"},
                                    @{
                                        key="D"; 
                                        serverName="DEV.DEV.LOCAL"; 
                                        useWindowsAuthentication=$True; 
                                        serverType="DEV"; 
                                        menuText="(D)ev"},
                                    @{
                                        key="T"; 
                                        serverName="TEST.DEV.LOCAL"; 
                                        useWindowsAuthentication=$True; 
                                        serverType="TEST"; 
                                        menuText="(T)est"},
                                    @{
                                        key="U"; 
                                        serverName="SQLTEST01.sit.local"; 
                                        userName="SitUser"; 
                                        password="qawsedrftg"; 
                                        serverType="UAT"; 
                                        menuText="(U)AT"}
                                    @{
                                        key="P"; 
                                        serverName="SQLPROD01.prod.local"; 
                                        userName="ProductionUser"; 
                                        password="Password1"; 
                                        serverType="LIVE"; 
                                        menuText="(P)roduction"
                                    }
                                )

$_defaultDatabase = "Transport"

$_logFileName = "release.log"
# If set overwrites any existing log file.  If cleared appends to an existing log file.  If 
# no log file exists a new one will be created, regardless of the setting of this variable.
$_overwriteLogFile = $True 
$_verboseLoggingOn = $True

<#
.SYNOPSIS
Gets the absolute path of the specified path.

.DESCRIPTION
Determines whether the filename supplied is an absolute or a relative path.  If it is 
absolute it is returned unaltered.  If it is relative then the folder this script is 
running in will be prepended to the filename.

.NOTES

#>
function Get-AbsolutePath (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$Path
    )
{
    if ([System.IO.Path]::IsPathRooted($Path))
    {
        return $Path
    }

    $Path = Join-Path $PSScriptRoot $Path

    return $Path
}

<#
.SYNOPSIS
Writes a message to the host and, optionally, to a log file.

.DESCRIPTION
Writes a string in the form of a log message: 
{datetime} | {calling function name} | {message}

.NOTES
{calling function name} will be "----" if the function is 
called from outside any other function, at the top level of 
the script.
#>
function Write-LogMessage (
    [Parameter(Mandatory=$True)]
    [AllowEmptyString()]
    [string]$Message,

    [Parameter(Mandatory=$False)]
    [string]$ConsoleTextColor,

    [Parameter(Mandatory=$False)]
    [string]$LogFileName,

    [Parameter(Mandatory=$False)]
    [switch]$WriteRawMessageOnly,

    [Parameter(Mandatory=$False)]
    [switch]$IsErrorMessage,

    [Parameter(Mandatory=$False)]
    [switch]$OverwriteLogFile
    )
{
    $timeText = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
    $callingFunctionName = (Get-Variable MyInvocation -Scope 1).Value.MyCommand.Name

    if (!$callingFunctionName)
    {
        $callingFunctionName = "----"
    }
    
    $errorText = ""

    if ($Message)
    {
        if ($IsErrorMessage)
        {
            $errorText = "ERROR: "
        }
        $outputMessage = "{0} | {1} | {2}{3}" -f $timeText, $callingFunctionName, $errorText, $Message
    }
    else
    { 
        if ($IsErrorMessage)
        {
            $errorText = " ERROR"
        }
        $outputMessage = "{0} |{1}" -f $timeText, $errorText
    }
        
    if ($WriteRawMessageOnly)
    {
        $outputMessage = $Message
        if (-not $outputMessage)
        {
            $outputMessage = " "
        }
    }

    if ($IsErrorMessage)
    {
        Write-Error $outputMessage
    }
    elseif ($ConsoleTextColor)
    {
        Write-Host $outputMessage -ForegroundColor $ConsoleTextColor
    }
    else
    {
        Write-Host $outputMessage
    }

    if (-not $LogFileName)
    {
        return
    }

    $LogFileName = $LogFileName.Trim()
    if (-not $LogFileName)
    {
        return
    }

    if (-not (Test-Path $LogFileName -IsValid))
    {
        # Fail silently so that every message output to the console doesn't include an error 
        # message.
        return
    }

    if ($OverwriteLogFile -or -not (Test-Path $LogFileName))
    {
        $outputMessage | Set-Content $LogFileName
    }
    else
    {
        $outputMessage | Add-Content $LogFileName
    }
}

<#
.SYNOPSIS
Writes a heading to the host and, optionally, to a log file.

.DESCRIPTION
Writes a heading that makes it obvious this is the start of a deployment.

.NOTES
Useful for repeated deployments, which may be written to the same log file.
#>
function Write-LogHeader (
    [Parameter(Mandatory=$True)]
    $SelectedServerDetails, 

    [Parameter(Mandatory=$False)]
    [string]$LogFileName,

    [Parameter(Mandatory=$False)]
    [switch]$OverwriteLogFile
    )
{
    $horizontalLine = "======================================================="
    Write-LogMessage $horizontalLine -LogFileName $LogFileName -WriteRawMessageOnly `
        -OverwriteLogFile:$OverwriteLogFile

    $dateText = (Get-Date).ToString("yyyy-MM-dd")
    $message = "Scripts run date: {0}" -f $dateText
    Write-LogMessage $message -LogFileName $LogFileName -WriteRawMessageOnly

    $message = "Running on {0} Server: {1}" -f $SelectedServerDetails.serverType, $SelectedServerDetails.serverName
    Write-LogMessage $message -LogFileName $LogFileName -WriteRawMessageOnly

    Write-LogMessage $horizontalLine -LogFileName $LogFileName -WriteRawMessageOnly
}

<#
.SYNOPSIS
Gets the user's choice of SQL Server to deploy to.

.DESCRIPTION
Returns a letter indicating which SQL Server the user wishes to run the scripts against.

.NOTES
Prompts the user to enter CTRL+C if they wish to abort the deployment.  Otherwise, the 
function will loop repeatedly until the user enters a valid letter.
#>
function Get-UserSelection (
    [Parameter(Mandatory=$True)]
    $SqlServers,

    [Parameter(Mandatory=$False)]
    [string]$LogFileName
    )
{
    Write-Host "Select the server to run the SQL scripts on (type a letter followed by the [Enter] key, or press CTRL+C to exit)"

    $menuTexts = $SqlServers | ForEach-Object {$_.menuText}
    $maxLength = ($menuTexts | Measure-Object -Maximum -Property Length).Maximum

    $tabLength = 8
    $numberTabs = [Math]::Ceiling($maxLength / $tabLength)
    if ($numberTabs * $tabLength -le $maxLength + 1) { $numberTabs++ }
    
    foreach ($server in $SqlServers)
    {
        $numberTabsToAdd = $numberTabs - [Math]::Floor($server.menuText.Length / $tabLength)
		$tabs = "`t" * $numberTabsToAdd
        Write-Host "`t$($server.menuText):$tabs$($server.serverName)"
    }

    $validSelections = $SqlServers | ForEach-Object {$_.key}
    $userSelection = ""

    while ($True)
    {
        $userSelection = Read-Host  
               
        ForEach ($validSelection in $validSelections)
        {
            if ($userSelection -eq $validSelection) 
            {
                return $validSelection
            }
        }
                
        Write-Host "Invalid selection.  Please try again or press CTRL+C to exit"
    }
}

<#
.SYNOPSIS
Gets the details of the SQL Server the user wishes to deploy to.

.DESCRIPTION
Gets the details of the SQL Server the user wishes to deploy to.  The details include the 
SQL Server instance name and the credentials needed to connect to the server.

.NOTES
#>
function Get-ServerDetails (
    [Parameter(Mandatory=$True)]
    $SqlServers, 
    
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$UserSelection,

    [Parameter(Mandatory=$False)]
    [string]$LogFileName
    )
{
    $selectedServerDetails = $SqlServers.Where({$_.key -eq $UserSelection})

    return $selectedServerDetails
}

<#
.SYNOPSIS
Parses the results of a SQL command and displays any errors or messages.

.DESCRIPTION

.NOTES
#>
function Get-SqlResult 
{
    # CmdletBinding attribute must be on first non-comment line of the function
    # and requires that the parameters be defined via the Param keyword rather 
    # than in parentheses outside the function body.
    [CmdletBinding()]
    Param
    (
        [Parameter(Position=1,
                    Mandatory=$True,
                    ValueFromPipeline=$True)]
        $sqlResult,

        [Parameter(Position=2,
                    Mandatory=$False)]
        [switch]$VerboseLoggingOn,

        [Parameter(Position=3,
                    Mandatory=$False)]
        [string]$LogFileName
    )

    begin
    {
        $wasSuccessful = $True
    }

    process
    {
        if ($sqlResult -is [System.Management.Automation.ErrorRecord])
        {
            $wasSuccessful = $False

            $errorRecord = [System.Management.Automation.ErrorRecord]$sqlResult

            if ($errorRecord.ErrorDetails -and $errorRecord.ErrorDetails.Message)
            {
                Write-LogMessage $errorRecord.ErrorDetails.Message `
                    -LogFileName $LogFileName -IsErrorMessage
            }
            
            if ($errorRecord.Exception)
            {
                if ($errorRecord.Exception.Message)
                {
                    # It seems like a single exception may include multiple errors in the 
                    # exception message, one error per line.  Align the errors on different 
                    # lines under the first error.
                    $message = $errorRecord.Exception.Message `
                        -replace "`r`n", ("`r`n{0}" -f (" " * 50))
                    Write-LogMessage $message -LogFileName $LogFileName -IsErrorMessage
                }
            }
        }
        elseif ($VerboseLoggingOn `
        -and $sqlResult -is [System.Management.Automation.InformationalRecord])
        {
            # InformationalRecord can be a DebugRecord, a VerboseRecord or a WarningRecord.
                        
            $infoRecord = [System.Management.Automation.InformationalRecord]$sqlResult

            if ($infoRecord.Message)
            {
                $recordType = "Info"
                if ($sqlResult -is [System.Management.Automation.VerboseRecord])
                {
                    # Invoke-SqlCmd should only output VerboseRecord or ErrorRecord.
                    $recordType = "Verbose"
                }
                $message = "{0}: {1}" -f $recordType, $infoRecord.Message
                Write-LogMessage $message -LogFileName $LogFileName 
            }
        }
    }

    end
    {
        return $wasSuccessful
    }
}

<#
.SYNOPSIS
Executes a single SQL script or query against a specified SQL Server instance.

.DESCRIPTION

.NOTES
#>
function Invoke-Sql 
{
    # CmdletBinding attribute must be on first non-comment line of the function
    # and requires that the parameters be defined via the Param keyword rather 
    # than in parentheses outside the function body.
    [CmdletBinding()]
    Param
    (
        [Parameter(Position=1,
                    Mandatory=$True)]
        $SelectedServerDetails, 

        [Parameter(Position=2,
                    Mandatory=$True)]
        [string]$DefaultDatabase,

        [Parameter(Position=3,
                    Mandatory=$False)]
        [string]$LogFileName,

        [Parameter(Position=4,
                    Mandatory=$False)]
        [switch]$VerboseLoggingOn, 

        [Parameter(Position=5,
                    Mandatory=$False,
                    ValueFromPipelineByPropertyName=$True)]
        [string]$SqlScriptFileName, 

        [Parameter(Position=5,
                    Mandatory=$False,
                    ValueFromPipelineByPropertyName=$True)]
        [string]$SqlQuery
    )

    process
    {
        $result = @{wasSuccessful=$False; output=$null}

        $optionalParameters = @{}
        if ((-not $SelectedServerDetails.ContainsKey("useWindowsAuthentication")) `
        -or (-not $SelectedServerDetails.useWindowsAuthentication))
        {
            $optionalParameters = @{UserName=$SelectedServerDetails.userName; `
                                    Password=$SelectedServerDetails.password}
        }

        if (-not $SqlScriptFileName -and -not $SqlQuery)
        {
            Write-LogMessage "Neither SQL script file nor SQL query supplied." `
                -LogFileName $LogFileName -IsErrorMessage
            return $result
        }

        $commandType = ""
        $command = ""
        if ($SqlScriptFileName)
        {
            $SqlScriptFileName = $SqlScriptFileName.Trim()
            if ([System.IO.Path]::GetExtension($SqlScriptFileName).ToLower() -ne ".sql")
            {
                $SqlScriptFileName = $SqlScriptFileName + ".sql"
            }

            $commandType = "script"
            $command = $SqlScriptFileName
            
            $SqlScriptFileName = Get-AbsolutePath $SqlScriptFileName
            
            $optionalParameters.InputFile = $SqlScriptFileName
        }
        elseif ($SqlQuery)
        {
            $optionalParameters.Query = $SqlQuery
            $commandType = "query"
            $command = $SqlQuery
        }

        $message = "Executing SQL {0} `"{1}`"..." -f $commandType, $command
        Write-LogMessage $message -LogFileName $LogFileName

        try
        {
            # TODO: Get ServerType variable working.  Currently throws an error if the SQL 
            # script contains a sqlcmd variable $(ServerType).
            $serverType = $SelectedServerDetails.serverType
            $serverTypeVariableDefinition = @("ServerType = '$serverType'")
            # *>&1 means all streams (eg Verbose, Error) are merged into pipeline output.
            $result.output = (Invoke-Sqlcmd -ServerInstance $SelectedServerDetails.serverName `
                -Database $DefaultDatabase -Variable $serverTypeVariableDefinition `
                -OutputSqlErrors $True -Verbose @optionalParameters) *>&1

            $result.wasSuccessful = ($result.output `
            | Get-SqlResult -VerboseLoggingOn:$VerboseLoggingOn -LogFileName $LogFileName)
            
            if ($result.wasSuccessful)
            {
                $message = "RESULT: SQL {0} executed successfully." -f $commandType
                Write-LogMessage $message -LogFileName $LogFileName
            }
            else
            {
                $message = "RESULT: Error while executing SQL {0}." -f $commandType
                Write-LogMessage $message -LogFileName $LogFileName
            }         

            return $result
        }
        catch
        {
            $message = "{0} - {1}" -f $_.Exception.GetType().Name, $_.Exception.Message
            Write-LogMessage $message -LogFileName $LogFileName -IsErrorMessage

            $result.wasSuccessful = $False
            return $result
        }
    }
}

<#
.SYNOPSIS
Checks that required server details have been supplied.

.DESCRIPTION

.NOTES
#>
function Test-ServerDetails (
    [Parameter(Mandatory=$True)]
    $SelectedServerDetails, 
    
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$UserSelection, 

    [Parameter(Mandatory=$False)]
    [string]$LogFileName
    )
{
    Write-LogMessage "Checking selected server details..." -LogFileName $LogFileName

    $message = $null

    if (-not $SelectedServerDetails)
    {
        $message = "No server details for user selection '{0}'" -f $UserSelection
        Write-LogMessage $message -LogFileName $LogFileName -IsErrorMessage
        return $False
    }   

    if (-not $SelectedServerDetails.ContainsKey("serverName"))
    {
        $message = "Server name missing for user selection '{0}'" -f $UserSelection
        Write-LogMessage $message -LogFileName $LogFileName -IsErrorMessage
        return $False
    }   

    if (-not $SelectedServerDetails.ContainsKey("serverType"))
    {
        $message = "Server type missing for user selection '{0}'" -f $UserSelection
        Write-LogMessage $message -LogFileName $LogFileName -IsErrorMessage
        return $False
    }

    if ((-not $SelectedServerDetails.ContainsKey("useWindowsAuthentication")) `
    -or (-not $SelectedServerDetails.useWindowsAuthentication))
    {
        if ((-not $SelectedServerDetails.ContainsKey("userName")) `
        -or (-not $SelectedServerDetails.ContainsKey("password")))
        {
            $message = "userName and/or password not supplied for server {0}." `
                -f $SelectedServerDetails.serverName
            Write-LogMessage $message -LogFileName $LogFileName -IsErrorMessage
            return $False
        }
    }    

    if ($message)
    {
        Write-LogMessage $message -LogFileName $LogFileName -IsErrorMessage

        Write-LogMessage "RESULT: Selected server details are not valid." -LogFileName $LogFileName

        return $False
    }

    Write-LogMessage "RESULT: Selected server details okay." -LogFileName $LogFileName

    return $True
}

<#
.SYNOPSIS
Checks that the default database exists on the selected SQL Server.

.DESCRIPTION

.NOTES
#>
function Test-DefaultDatabase (
    [Parameter(Mandatory=$True)]
    $SelectedServerDetails, 
    
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$DefaultDatabase,

    [Parameter(Mandatory=$False)]
    [switch]$VerboseLoggingOn, 

    [Parameter(Mandatory=$False)]
    [string]$LogFileName
    )
{
    $message = "Checking the existence of default database '{0}' on SQL Server {1}..." `
        -f $DefaultDatabase, $SelectedServerDetails.serverName
    Write-LogMessage $message -LogFileName $LogFileName

    if (-not $DefaultDatabase -or -not $DefaultDatabase.Trim())
    {
        Write-LogMessage "No default database supplied." -LogFileName $LogFileName -IsErrorMessage

        Write-LogMessage "RESULT: No default database supplied." -LogFileName $LogFileName

        return $False
    }

    $SqlQuery = "SELECT name FROM sys.databases WHERE name = '{0}'" -f $DefaultDatabase
    $result = Invoke-Sql -SelectedServerDetails $SelectedServerDetails `
        -DefaultDatabase $DefaultDatabase -VerboseLoggingOn:$VerboseLoggingOn `
        -SqlQuery $SqlQuery -LogFileName $LogFileName

    if (-not $result -or -not $result.wasSuccessful)
    {
        $message = "Database {0} not found on SQL Server {1}" `
            -f $DefaultDatabase, $SelectedServerDetails.serverName
        Write-LogMessage $message -LogFileName $LogFileName -IsErrorMessage

        Write-LogMessage "RESULT: Database not found." -LogFileName $LogFileName 

        return $False
    }    

    Write-LogMessage "RESULT: Database found." -LogFileName $LogFileName

    return $True
}

<#
.SYNOPSIS
Executes the specified SQL scripts against the user's choice of SQL Server instance.

.DESCRIPTION
Prompts the user to select which server to deploy to, then executes each of the listed SQL 
scripts against that server.

.NOTES
#>
function Update-Database (
    [Parameter(Mandatory=$True)]
    $SqlServers,

    [Parameter(Mandatory=$True)]
    [string]$DefaultDatabase,

    [Parameter(Mandatory=$True)]
    [string[]]$SqlScriptNames,

    [Parameter(Mandatory=$False)]
    [switch]$VerboseLoggingOn, 

    [Parameter(Mandatory=$False)]
    [string]$LogFileName,

    [Parameter(Mandatory=$False)]
    [switch]$OverwriteLogFile
    )
{
    Clear-Host 

    $LogFileName = Get-AbsolutePath $LogFileName

    $fileNameIsValid = Test-Path $LogFileName -IsValid

    if (-not $fileNameIsValid)
    {
        $message = "'$LogFileName' is not a valid file name." `
            + "  Please correct the file name and try again."
        Write-Error $message
        return
    }

    $userSelection = Get-UserSelection $SqlServers
    $selectedServerDetails =  Get-ServerDetails $SqlServers $userSelection
    
    Write-LogHeader -SelectedServerDetails $selectedServerDetails -LogFileName $LogFileName `
        -OverwriteLogFile:$OverwriteLogFile

    $startTime = Get-Date

    $serverDetailsOk = Test-ServerDetails -SelectedServerDetails $selectedServerDetails `
        -UserSelection $userSelection -LogFileName $LogFileName

    if (-not $serverDetailsOk)
    {
        return
    }

    $defaultDatabaseExists = Test-DefaultDatabase -SelectedServerDetails $selectedServerDetails `
        -DefaultDatabase $DefaultDatabase -VerboseLoggingOn:$VerboseLoggingOn `
        -LogFileName $LogFileName

    if (-not $defaultDatabaseExists)
    {
        return
    }

    $message = "Executing SQL scripts on server {0}..." -f $selectedServerDetails.serverName
    Write-LogMessage $message -LogFileName $LogFileName

    $allScriptsSuccessful = $True
    $SqlScriptNames `
    | Select-Object @{Name="sqlScriptFileName"; Expression={$_}} `
    | Invoke-Sql -SelectedServerDetails $selectedServerDetails `
                                -DefaultDatabase $DefaultDatabase `
                                -VerboseLoggingOn:$VerboseLoggingOn `
                                -LogFileName $LogFileName `
    | ForEach-Object { if (-not $_.wasSuccessful) {$allScriptsSuccessful = $False} }
    
    $endTime = Get-Date
    $timeTaken = $endTime - $startTime    
    $message = "Finished running scripts.  Time taken: {0:hh\:mm\:ss\.fff} hh:mm:ss." -f $timeTaken
    Write-LogMessage $message -LogFileName $LogFileName

    $messageColor = "Green"
    $message = "RESULT: No errors encountered."
    if (-not $allScriptsSuccessful)
    {
        $messageColor = "Red"
        $message = "RESULT: ONE OR MORE ERRORS ENCOUNTERED.  For details search log messages above for the text `"ERROR:`"."
    }
    Write-LogMessage $message -ConsoleTextColor $messageColor -LogFileName $LogFileName

    Write-LogMessage "==============================" `
        -LogFileName $LogFileName -WriteRawMessageOnly
    Write-LogMessage " " -LogFileName $LogFileName -WriteRawMessageOnly
}


Update-Database -SqlServers $_sqlServers -DefaultDatabase $_defaultDatabase `
    -SqlScriptNames $_sqlScriptNames -VerboseLoggingOn:$_verboseLoggingOn `
    -LogFileName $_logFileName -OverwriteLogFile:$_overwriteLogFile
