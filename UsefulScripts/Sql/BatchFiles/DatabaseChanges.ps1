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
Requires:		PowerShell 5.1 or greater
                sqlcmd.exe, the SQL Server Commandline Utility, which needs to be on the Windows PATH.
                PowerShell modules:
                    (these will be installed automatically if not already installed)
                    - SqlServer
                    - Pslogg (logging module)
Version:		2.0.1
Date:			10 Dec 2024

When listing the SQL script file names, the file extensions are optional.  So a SQL script file 
name could be either like "script_name.sql" or simply "script_name".

The SQL scripts to run need to be in the same folder as this script.

This script does not need to be run on the SQL Server that is being updated.  It will connect to 
the server selected by the user as long as it can access that server remotely.

ServerType SQLCMD Variable:
This script will pass SQLCMD variable $(ServerType), set to the serverType selected by the user, 
into the SQL scripts being executed.  If the variable is present in a SQL script (it doesn't have 
to be) it can be used to vary data or script behaviour across different environments.  For 
example, a CASE statement in a SQL script could be used to save different email recipients to a 
table in the QA, UAT and LIVE environments.

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

#>

# -------------------------------------------------------------------------------------------------
# ADD RELEASE SCRIPTS HERE
# -------------------------------------------------------------------------------------------------
# Default file extension, if none is specified, is ".sql".
$_sqlScriptNames = @(
                    "SqlCmdVarTest"
                    "CreateTestTable1"
                    "CreateTestTable2"
                    )

# -------------------------------------------------------------------------------------------------
# No changes needed below this point; the remaining code is generic.
# -------------------------------------------------------------------------------------------------

#region Configuration *****************************************************************************

# Once configuration has been set up for the various servers it can be reused from one release to 
# the next, without changes.

# NOTE: All servers and credentials listed below are dummies, used for 
# illustration only.  They do not really exist.
[System.Object[]]$_sqlServers = @(
                                    @{
                                        key="L"; 
                                        connectionString="Server=(localdb)\mssqllocaldb;Database=Test;Trusted_Connection=yes;";
                                        serverType="LOCALDB"; 
                                        menuText="(L)ocaldb"
                                    },
                                    @{
                                        key="D"; 
                                        connectionString="Server=DEV.DEV.LOCAL;Database=Test;Trusted_Connection=yes;";
                                        serverType="DEV"; 
                                        menuText="(D)ev"
                                    },
                                    @{
                                        key="T"; 
                                        connectionString="Server=TEST.DEV.LOCAL;Database=Test;Trusted_Connection=yes;";
                                        serverType="TEST"; 
                                        menuText="(T)est"
                                    },
                                    @{
                                        key="U"; 
                                        connectionString="Server=SQLTEST01.sit.local;Database=Test;User ID=SitUser;Password=qawsedrftg;";
                                        serverType="UAT"; 
                                        menuText="(U)AT"
                                    },
                                    @{
                                        key="P"; 
                                        connectionString="Server=SQLPROD01.prod.local;Database=ProdDB;User ID=ProductionUser;Password=Password1;";
                                        serverType="LIVE"; 
                                        menuText="(P)roduction"
                                    }
                                )

# The log file will be created in the same folder as this script.  It will have the run date 
# automatically appended to the file name.  For example, "release_20231203.log"
$_logFileNameBaseName = "release.log"
# If set overwrites the log file for the current date, if it exists.  If cleared appends to that  
# existing file.  If no log file exists for the current date a new one will be created, regardless 
# of the setting of this variable.
# NOTE: After initially overwriting a log file, all subsequent log messages written to the same 
# file in the same PowerShell session will be appended to the file.
$_overwriteLogFile = $True 

$_sqlVerboseLoggingOn = $True

$_requiredModules = @('SqlServer', 'PsLogg')
$_moduleRepository = 'PSGallery'
$_proxyServerUrl = ''

#endregion Configuration **************************************************************************

<#
.SYNOPSIS
Checks whether the specified module is already installed and installs it if it isn't.

.DESCRIPTION
If the specified module is not already installed the function will attempt to install it 
assuming it has direct access to the repository.  If that fails it will attempt to install the 
module via a proxy server.

If this function installs a module it will be installed for the current user only, not for all 
users of the computer.

.NOTES
Cannot include logging in this function because it will be used to install the logging module 
if it's not already installed.
#>
function Install-RequiredModule (
    [string]$ModuleName,
    [string]$RepositoryName,
    [string]$ProxyUrl
    )
{
    Write-Output "    Checking whether PowerShell module '$ModuleName' is installed..."

    # "Get-InstalledModule -Name <module name>" will throw a non-terminating error if the module 
    # is not installed.  Don't want to display the error so silently continue.
    if (Get-InstalledModule -Name $ModuleName `
        -ErrorAction SilentlyContinue -WarningAction SilentlyContinue)
    {
        Write-Output "    Module '$ModuleName' is installed."
        return
    }
    
    Write-Output "    Installing PowerShell module '$ModuleName'..."

    # Repository probably has too many modules to enumerate them all to find the name.  So call 
    # "Find-Module -Repository $RepositoryName -Name $ModuleName" which will raise a 
    # non-terminating error if the module isn't found.

    # Silently continue on error because the error message isn't user friendly.  We'll display 
    # our own error message if needed.
    if ((Find-Module -Repository $RepositoryName -Name $ModuleName `
        -ErrorAction SilentlyContinue -WarningAction SilentlyContinue).Count -eq 0)
    {
        throw "Module '$ModuleName' not found in repository '$RepositoryName'.  Exiting."
    }

    try
    {
        # Ensure the repository is trusted otherwise the user will get an "untrusted repository"
        # warning message.
        $repositoryInstallationPolicy = (Get-PSRepository -Name $RepositoryName |
                                            Select-Object -ExpandProperty InstallationPolicy)
        if ($repositoryInstallationPolicy -ne 'Trusted')
        {
            Set-PSRepository -Name $RepositoryName -InstallationPolicy Trusted
        }
    }
    catch 
    {
        throw "Module repository '$RepositoryName' not found.  Exiting."
    }
    
    try
    {        
        # If Install-Module fails because it's behind a proxy we want to fail silently, without 
        # displaying any message to scare the user.  
        # Errors from Install-Module are non-terminating.  They won't be caught using try - catch 
        # unless ErrorAction is set to Stop. 
        Install-Module -Name $ModuleName -Repository $RepositoryName `
            -Scope CurrentUser -ErrorAction Stop -WarningAction SilentlyContinue
    }
    catch 
    {
        # Try again, this time with proxy details, if we have them.

        if ([string]::IsNullOrWhiteSpace($ProxyUrl))
        {
            throw "Unable to install module '$ModuleName' directly and no proxy server details supplied.  Exiting."
        }

        $proxyCredential = Get-Credential -Message 'Please enter credentials for proxy server'

        # No need to Silently Continue this time.  We want to see the error details.  Convert 
        # non-terminating errors to terminating via ErrorAction Stop.   
        Install-Module -Name $ModuleName -Repository $RepositoryName `
            -Proxy $ProxyUrl -ProxyCredential $proxyCredential `
            -Scope CurrentUser -ErrorAction Stop
    }

    if (-not (Get-InstalledModule -Name $ModuleName -ErrorAction SilentlyContinue))
    {
        throw "Unknown error installing module '$ModuleName' from repository '$RepositoryName'.  Exiting."
    }

    Write-Output "    Module '$ModuleName' successfully installed."
}

<#
.SYNOPSIS
Sets up the Pslogg logging module to write to the PowerShell host and to a log file.

.DESCRIPTION

.NOTES
#>
function Initialize-Logger (
    [string]$LogFileName,
    [switch]$OverwriteLogFile
    )
{
    $fileNameIsValid = Test-Path $LogFileName -IsValid

    if (-not $fileNameIsValid)
    {
        $message = "'$LogFileName' is not a valid file name." `
            + "  Please correct the file name and try again.  Exiting."
        throw $message
    }

    Set-LogConfiguration -LogLevel VERBOSE -WriteToHost
    Set-LogConfiguration -LogFileName $LogFileName -ExcludeDateFromFileName:$False `
        -EnableFileLoggingFromScript -OverwriteLogFile:$OverwriteLogFile
    Set-LogConfiguration -CategoryInfoItem 'Success', @{ Color = 'Green' }
    Set-LogConfiguration -CategoryInfoItem 'Failure', @{ Color = 'Red' }
    Set-LogConfiguration -CategoryInfoItem 'Result', @{ Color = 'Cyan' }
    Set-LogConfiguration -MessageFormat '{TimeStamp} | {CallerName} | {MessageLevel} | {Message}'
}

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
Logs the raw log message, without any other fields like a timestamp.

.DESCRIPTION
Logs the raw log message, without any other fields like a timestamp.

.NOTES
#>
function Write-RawLogMessage (
    [Parameter(Mandatory=$True)]
    [string]$Message
    )
{
    Write-LogMessage -Message $Message -MessageFormat '{Message}'
}

<#
.SYNOPSIS
Writes a heading to the host and to the log file.

.DESCRIPTION
Writes a heading that makes it obvious this is the start of a deployment.

.NOTES
Useful for repeated deployments, which may be written to the same log file.
#>
function Write-LogHeader (
    [Parameter(Mandatory=$True)]
    $SelectedServerDetails,

    [Parameter(Mandatory=$False)]
    [string]$LogFileName
    )
{
    $horizontalLine = "======================================================="
    Write-RawLogMessage $horizontalLine

    $dateText = (Get-Date).ToString("yyyy-MM-dd")
    $message = "Scripts run date: {0}" -f $dateText
    Write-RawLogMessage $message

    $message = "Running on $($SelectedServerDetails.serverType) Server: $($SelectedServerDetails.serverName)"
    Write-RawLogMessage $message

    $message = "Default database to run scripts against: $($SelectedServerDetails.databaseName)"
    Write-RawLogMessage $message

    $loggerConfiguration = Get-LogConfiguration
    if ($loggerConfiguration `
        -and $loggerConfiguration.LogFile `
        -and $loggerConfiguration.LogFile.WriteFromScript `
        -and $loggerConfiguration.LogFile.Name)
    {
        $message = "Results logged to: $($loggerConfiguration.LogFile.FullPathReadOnly)"
        Write-RawLogMessage $message
    }

    Write-RawLogMessage $horizontalLine
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
    $SqlServers
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
Converts a connection string into a hashtable of key-value pairs.

.DESCRIPTION
Splits the connection string on the separator character then splits each part again into 
key and value, and adds them to a hashtable.

.NOTES
#>
function Convert-ConnectionStringToHashtable (
    [Parameter(Mandatory=$True)]
    [string[]]$ConnectionString
    )
{
    if ([string]::IsNullOrWhiteSpace($ConnectionString))
    {
        return $null
    }

    $connectionStringParts = $ConnectionString.Split(';')

    $hashTable = @{}
    foreach($part in $connectionStringParts)
    {
        $keyValuePair = $part.Split('=')
        if ($keyValuePair.Length -eq 2)
        {
            $key = $keyValuePair[0]
            $value = $keyValuePair[1]
            $hashTable[$key] = $value
        }
    }

    return $hashTable
}

<#
.SYNOPSIS
Reads a value from a hashtable.

.DESCRIPTION
While this function can read a value from any hashtable it is designed to read a value from a 
hashtable converted from a SQL Server connection string.  SQL Server connection strings can have 
multiple alternative keys for the same property.  For example, "User", "User ID", or "UID" for the 
SQL Server login name.  So the function has to take an array of possible key names, rather than a 
single key name, to extract from the connection string.  The function will return the value for 
the first of the possible keys it encounters in the hashtable.

.NOTES
ASSUMPTION: That all values in the hashtable are strings.
#>
function Read-HashtableValue (
    [Parameter(Mandatory=$True)]
    [hashtable]$Hashtable,
    
    [Parameter(Mandatory=$True)]
    [string[]]$PossibleKeyNames
    )
{
    if ($Hashtable -eq $null -or $Hashtable.Count -eq 0)
    {
        return $null
    }
    if (-not $PossibleKeyNames)
    {
        return $null
    }

    foreach($key in $PossibleKeyNames)
    {
        $value = $Hashtable[$key]
        if (-not [string]::IsNullOrWhiteSpace($value))
        {
            return $value
        }
    }

    return $null
}

<#
.SYNOPSIS
Gets the details of the SQL Server the user wishes to deploy to.

.DESCRIPTION
Gets the details of the SQL Server the user wishes to deploy to.  The details include the 
SQL Server instance name and the credentials needed to connect to the server.

.NOTES
The lists of possible key names come from "SqlConnection.ConnectionString Property", 
https://learn.microsoft.com/en-us/dotnet/api/system.data.sqlclient.sqlconnection.connectionstring
#>
function Get-ServerDetails (
    [Parameter(Mandatory=$True)]
    $SqlServers, 
    
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$UserSelection
    )
{
    $selectedServerDetails = $SqlServers | Where-Object{$_.key -eq $UserSelection}

    # This should never happen as Get-UserSelection should ensure the user chooses a valid 
    # selection.  But it can't hurt to be careful.
    if (-not $selectedServerDetails)
    {
        $message = "No server details found for user selection '$UserSelection'."
        Write-LogMessage $message -IsError
        return $null
    }

    if (-not $SelectedServerDetails.ContainsKey("serverType"))
    {
        $message = "Selected server '$UserSelection' has no connection string specified."
        Write-LogMessage $message -IsError
        return $False
    }

    if (-not $selectedServerDetails.ContainsKey('connectionString'))
    {
        $message = "Selected server '$UserSelection' has no connection string specified."
        Write-LogMessage $message -IsError
        return $null
    }

    $connectionDetails = Convert-ConnectionStringToHashtable -ConnectionString $selectedServerDetails.connectionString

    if (-not $connectionDetails)
    {
        $message = "Unable to parse connection string for selected server '$UserSelection'."
        Write-LogMessage $message -IsError
        return $null
    }

    $serverName = Read-HashtableValue -Hashtable $connectionDetails `
        -PossibleKeyNames 'Data Source','Server','Address','Addr','Network Address'

    if (-not $serverName)
    {
        $message = "Server name not found in connection string for selected server '$UserSelection'."
        Write-LogMessage $message -IsError
        return $null
    }

    $selectedServerDetails.serverName = $serverName

    $databaseName = Read-HashtableValue -Hashtable $connectionDetails `
        -PossibleKeyNames 'Initial Catalog','Database'

    if (-not $databaseName)
    {
        $message = "Database name not found in connection string for selected server '$UserSelection'."
        Write-LogMessage $message -IsError
        return $null
    }

    $selectedServerDetails.databaseName = $databaseName

    $trustedConnection = Read-HashtableValue -Hashtable $connectionDetails `
        -PossibleKeyNames 'Integrated Security','Trusted_Connection'

    $SelectedServerDetails.useWindowsAuthentication =  `
        ($trustedConnection -and $trustedConnection -in  @('true', 'yes', 'sspi'))

    if (-not $SelectedServerDetails.useWindowsAuthentication)
    {
        $SelectedServerDetails.userName = Read-HashtableValue -Hashtable $connectionDetails `
            -PossibleKeyNames 'User ID','UID','User'
            
        $SelectedServerDetails.password = Read-HashtableValue -Hashtable $connectionDetails `
        -PossibleKeyNames 'Password','PWD'
    }

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
        [AllowNull()]
        [Parameter(Position=1,
                    Mandatory=$True,
                    ValueFromPipeline=$True)]
        $sqlResult,

        [Parameter(Mandatory=$False)]
        [switch]$SqlVerboseLoggingOn,

        [Parameter(Mandatory=$False)]
        [switch]$ExpectNonNullResult
    )

    begin
    {
        $wasSuccessful = $True
    }

    process
    {
        if ($ExpectNonNullResult -and $sqlResult -eq $null)
        {
            $wasSuccessful = $false
        }
        elseif ($sqlResult -is [System.Management.Automation.ErrorRecord])
        {
            $wasSuccessful = $False

            $errorRecord = [System.Management.Automation.ErrorRecord]$sqlResult

            if ($errorRecord.ErrorDetails -and $errorRecord.ErrorDetails.Message)
            {
                Write-LogMessage $errorRecord.ErrorDetails.Message -IsError
            }
            
            if ($errorRecord.Exception -and $errorRecord.Exception.Message)
            {
                # It seems like a single exception may include multiple errors in the 
                # exception message, one error per line.  Flatten to a single line.
                $message = $errorRecord.Exception.Message -replace "`r`n", ""
                Write-LogMessage $message -IsError
            }
        }
        elseif ($SqlVerboseLoggingOn `
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
                Write-LogMessage $message 
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
                    Mandatory=$False)]
        [switch]$SqlVerboseLoggingOn, 

        [Parameter(Position=3,
                    Mandatory=$False,
                    ValueFromPipelineByPropertyName=$True)]
        [string]$SqlScriptFileName, 

        [Parameter(Position=4,
                    Mandatory=$False,
                    ValueFromPipelineByPropertyName=$True)]
        [string]$SqlQuery,

        [Parameter(Mandatory=$False)]
        [switch]$ExpectNonNullResult,

        [Parameter(Mandatory=$False)]
        [switch]$SuppressErrorLogging
    )

    process
    {
        $result = @{wasSuccessful=$False; output=$null}

        if (-not $SqlScriptFileName -and -not $SqlQuery)
        {
            Write-LogMessage "Neither SQL script file nor SQL query supplied." -IsError
            return $result
        }

        $optionalParameters = @{}
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

        if ($SelectedServerDetails.useExplicitConnectionDetails)
        {
            $optionalParameters.ServerInstance = $SelectedServerDetails.serverName
            $optionalParameters.Database = $SelectedServerDetails.databaseName

            if (-not $SelectedServerDetails.useWindowsAuthentication)
            {
                $optionalParameters.UserName = $SelectedServerDetails.userName
                $optionalParameters.Password = $SelectedServerDetails.password
            }
        }
        else 
        {
            $optionalParameters.ConnectionString = $SelectedServerDetails.connectionString
        }

        $message = "Executing SQL $commandType `"$command`"..."
        Write-LogMessage $message

        try
        {
            # Pass sqlcmd variable $(ServerType), set to the serverType selected by the user, 
            # into the SQL script or command.
            $serverType = $SelectedServerDetails.serverType
            $serverTypeVariableDefinition = @{ServerType=$serverType}
            # *>&1 means all streams (eg Verbose, Error) are merged into pipeline output.
            # Note splatting operator on @optionalParameters.
            # -ErrorAction Stop turns non-terminating errors into terminating errors that will 
            # be caught by the catch block.
            $result.output = (Invoke-Sqlcmd `
                -Variable $serverTypeVariableDefinition `
                -OutputSqlErrors $True -IncludeSqlUserErrors `
                -Verbose @optionalParameters) *>&1

            $result.wasSuccessful = ($result.output |
                Get-SqlResult -SqlVerboseLoggingOn:$SqlVerboseLoggingOn -ExpectNonNullResult:$ExpectNonNullResult)
            
            if ($result.wasSuccessful)
            {
                $message = "RESULT: SQL $commandType executed successfully."
                Write-LogMessage $message -Category Result
            }
            else
            {
                $message = "RESULT: Error or unexpected result while executing SQL $commandType."
                Write-LogMessage $message -IsError
            }         

            return $result
        }
        catch
        {
            if (-not $SuppressErrorLogging)
            {
                $message = "{0} - {1}" -f $_.Exception.GetType().Name, $_.Exception.Message
                Write-LogMessage $message -IsError
            }

            $result.wasSuccessful = $False
            return $result
        }
    }
}

<#
.SYNOPSIS
Checks the connection to the SQL Server instance specified in the server details.

.DESCRIPTION

.NOTES
#>
function Test-SqlServer (
    [Parameter(Mandatory=$True)]
    $SelectedServerDetails
    )
{
    $sqlServerName = $SelectedServerDetails.serverName

    # Server name  should be checked by Get-ServerDetails but it can't hurt to be careful.
    if ([string]::IsNullOrWhiteSpace($sqlServerName))
    {
        $message = "SQL Server name not found for selected server '$UserSelection'."
        Write-LogMessage $message -IsError
        return $false
    }

    $message = "Checking the connection to SQL Server '$sqlServerName'..."
    Write-LogMessage $message

    $databaseName = $SelectedServerDetails.databaseName
    $SelectedServerDetails.databaseName = 'master'
    $SelectedServerDetails.useExplicitConnectionDetails = $true

    $SqlQuery = "SELECT @@VERSION;"
    $result = Invoke-Sql -SelectedServerDetails $SelectedServerDetails `
        -SqlVerboseLoggingOn -SqlQuery $SqlQuery -ExpectNonNullResult -SuppressErrorLogging

    $SelectedServerDetails.databaseName = $databaseName
    $SelectedServerDetails.useExplicitConnectionDetails = $false

    if (-not $result -or -not $result.wasSuccessful)
    {
        Write-LogMessage "RESULT: Connection to SQL Server failed." -IsError

        return $False
    }    

    Write-LogMessage "RESULT: Successfully connected to SQL Server." -Category Result

    return $True
}

<#
.SYNOPSIS
Checks that the database specified in the server details exists on the selected SQL Server.

.DESCRIPTION

.NOTES
#>
function Test-Database (
    [Parameter(Mandatory=$True)]
    $SelectedServerDetails
    )
{
    $databaseName = $SelectedServerDetails.databaseName
    $sqlServerName = $SelectedServerDetails.serverName

    # Database name should be checked by Get-ServerDetails but it can't hurt to be careful.
    if ([string]::IsNullOrWhiteSpace($databaseName))
    {
        $message = "Database name not found for selected server '$UserSelection'."
        Write-LogMessage $message -IsError
        return $false
    }
    $message = "Checking the existence of database '$databaseName' on SQL Server '$sqlServerName'..."
    Write-LogMessage $message

    $SelectedServerDetails.databaseName = 'master'
    $SelectedServerDetails.useExplicitConnectionDetails = $true

    $SqlQuery = "SELECT name FROM sys.databases WHERE name = '$databaseName';"
    $result = Invoke-Sql -SelectedServerDetails $SelectedServerDetails `
        -SqlVerboseLoggingOn -SqlQuery $SqlQuery -ExpectNonNullResult

    $SelectedServerDetails.databaseName = $databaseName
    $SelectedServerDetails.useExplicitConnectionDetails = $false

    if (-not $result -or -not $result.wasSuccessful)
    {
        Write-LogMessage "RESULT: Database not found." -IsError

        return $False
    }    

    Write-LogMessage "RESULT: Database found." -Category Result

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
    [string[]]$SqlScriptNames,

    [Parameter(Mandatory=$False)]
    [switch]$SqlVerboseLoggingOn,

    [Parameter(Mandatory=$False)]
    [string]$LogFileName
    )
{
    $userSelection = Get-UserSelection $SqlServers
    $selectedServerDetails =  Get-ServerDetails $SqlServers $userSelection

    if (-not $selectedServerDetails)
    {
        return
    }
    
    Write-LogHeader -SelectedServerDetails $selectedServerDetails -LogFileName $LogFileName

    $startTime = Get-Date

    $canConnectToSqlServer = Test-SqlServer -SelectedServerDetails $selectedServerDetails

    if (-not $canConnectToSqlServer)
    {
        return
    }

    $defaultDatabaseExists = Test-Database -SelectedServerDetails $selectedServerDetails

    if (-not $defaultDatabaseExists)
    {
        return
    }

    $message = "Executing SQL scripts on server '$($selectedServerDetails.serverName)'..." 
    Write-LogMessage $message 

    $allScriptsSuccessful = $True
    $SqlScriptNames |
        Select-Object @{Name="SqlScriptFileName"; Expression={$_}} |
        Invoke-Sql -SelectedServerDetails $selectedServerDetails `
                        -SqlVerboseLoggingOn:$SqlVerboseLoggingOn |
        ForEach-Object { if (-not $_.wasSuccessful) {$allScriptsSuccessful = $False} }
    
    $endTime = Get-Date
    $timeTaken = $endTime - $startTime    
    $message = "Finished running scripts.  Time taken: {0:hh\:mm\:ss\.fff} hh:mm:ss." -f $timeTaken
    Write-LogMessage $message 

    $resultCategory = 'Success'
    $message = "RESULT: No errors encountered."
    if (-not $allScriptsSuccessful)
    {
        $resultCategory = 'Failure'
        $message = "RESULT: ONE OR MORE ERRORS ENCOUNTERED.  For details search log messages above for the text `"ERROR:`"."
    }
    Write-LogMessage $message -Category $resultCategory

    Write-RawLogMessage "==============================" 
    Write-RawLogMessage " "
}

Clear-Host 

Write-Output 'Checking required PowerShell modules are installed:'
foreach($module in $_requiredModules)
{
    Install-RequiredModule -ModuleName $module -RepositoryName $_moduleRepository -ProxyUrl $_proxyServerUrl
}

Initialize-Logger -LogFileName $_logFileNameBaseName -OverwriteLogFile:$_overwriteLogFile
Write-Output ''

Update-Database -SqlServers $_sqlServers -SqlScriptNames $_sqlScriptNames `
    -SqlVerboseLoggingOn:$_sqlVerboseLoggingOn -LogFileName $_logFileNameBaseName