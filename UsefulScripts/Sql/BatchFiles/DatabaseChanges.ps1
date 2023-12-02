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
                sqlcmd, the SQL Server Commandline Utility, which needs to be on the Windows PATH.
                PowerShell modules:
                    (these will be installed automatically if not already installed)
                    SqlServer
                    Pslogg (logging module)
Version:		2.0.0
Date:			2 Dec 2023

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
                                        serverName="(localdb)\mssqllocaldb"; 
                                        useWindowsAuthentication=$True; 
                                        serverType="LOCALDB"; 
                                        menuText="(L)ocaldb"
                                    },
                                    @{
                                        key="D"; 
                                        serverName="DEV.DEV.LOCAL"; 
                                        useWindowsAuthentication=$True; 
                                        serverType="DEV"; 
                                        menuText="(D)ev"
                                    },
                                    @{
                                        key="T"; 
                                        serverName="TEST.DEV.LOCAL"; 
                                        useWindowsAuthentication=$True; 
                                        serverType="TEST"; 
                                        menuText="(T)est"
                                    },
                                    @{
                                        key="U"; 
                                        serverName="SQLTEST01.sit.local"; 
                                        userName="SitUser"; 
                                        password="qawsedrftg"; 
                                        serverType="UAT"; 
                                        menuText="(U)AT"
                                    },
                                    @{
                                        key="P"; 
                                        serverName="SQLPROD01.prod.local"; 
                                        userName="ProductionUser"; 
                                        password="Password1"; 
                                        serverType="LIVE"; 
                                        menuText="(P)roduction"
                                    }
                                )

# To run a script in a database other than the default database, include a USE <db name> statement 
# in the script.
$_defaultDatabase = "Test"

# The log file will be created in the same folder as this script.
$_logFileName = "release.log"
# If set overwrites any existing log file.  If cleared appends to an existing log file.  If 
# no log file exists a new one will be created, regardless of the setting of this variable.
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
    Write-Output "Checking whether PowerShell module '$ModuleName' is installed..."

    # "Get-InstalledModule -Name <module name>" will throw a non-terminating error if the module 
    # is not installed.  Don't want to display the error so silently continue.
    if (Get-InstalledModule -Name $ModuleName `
        -ErrorAction SilentlyContinue -WarningAction SilentlyContinue)
    {
        Write-Output "Module '$ModuleName' is installed."
        return
    }
    
    Write-Output "Installing PowerShell module '$ModuleName'..."

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

    Write-Output "Module '$ModuleName' successfully installed."
}

<#
.SYNOPSIS
Sets up the Pslogg logging module to write to the PowerShell host and to a log file.

.DESCRIPTION
Sets up the Pslogg logging module to write to the PowerShell host and to a log file.

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

    Set-LogConfiguration -LogFileName $_logFileName -ExcludeDateFromFileName:$False `
        -LogLevel VERBOSE -WriteToHost -EnableFileLoggingFromScript
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

    $message = "Running on {0} Server: {1}" -f $SelectedServerDetails.serverType, $SelectedServerDetails.serverName
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
    [string]$UserSelection
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
        [AllowNull()]
        [Parameter(Position=1,
                    Mandatory=$True,
                    ValueFromPipeline=$True)]
        $sqlResult,

        [Parameter(Position=2,
                    Mandatory=$False)]
        [switch]$SqlVerboseLoggingOn
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
                    Mandatory=$True)]
        [string]$DefaultDatabase,

        [Parameter(Position=3,
                    Mandatory=$False)]
        [switch]$SqlVerboseLoggingOn, 

        [Parameter(Position=4,
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
            Write-LogMessage "Neither SQL script file nor SQL query supplied." -IsError
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
        Write-LogMessage $message

        try
        {
            # Pass sqlcmd variable $(ServerType), set to the serverType selected by the user, 
            # into the SQL script or command.
            $serverType = $SelectedServerDetails.serverType
            $serverTypeVariableDefinition = @{ServerType=$serverType}
            # *>&1 means all streams (eg Verbose, Error) are merged into pipeline output.
            $result.output = (Invoke-Sqlcmd -ServerInstance $SelectedServerDetails.serverName `
                -Database $DefaultDatabase -Variable $serverTypeVariableDefinition `
                -OutputSqlErrors $True -Verbose -IncludeSqlUserErrors @optionalParameters) *>&1

            $result.wasSuccessful = ($result.output `
            | Get-SqlResult -SqlVerboseLoggingOn:$SqlVerboseLoggingOn)
            
            if ($result.wasSuccessful)
            {
                $message = "RESULT: SQL {0} executed successfully." -f $commandType
                Write-LogMessage $message -Category Result
            }
            else
            {
                $message = "RESULT: Error while executing SQL {0}." -f $commandType
                Write-LogMessage $message -IsError
            }         

            return $result
        }
        catch
        {
            $message = "{0} - {1}" -f $_.Exception.GetType().Name, $_.Exception.Message
            Write-LogMessage $message -IsError

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
    [string]$UserSelection
    )
{
    Write-LogMessage "Checking selected server details..."

    $message = $null

    if (-not $SelectedServerDetails)
    {
        $message = "No server details for user selection '{0}'" -f $UserSelection
        Write-LogMessage $message -IsError
        return $False
    }   

    if (-not $SelectedServerDetails.ContainsKey("serverName"))
    {
        $message = "Server name missing for user selection '{0}'" -f $UserSelection
        Write-LogMessage $message -IsError
        return $False
    }   

    if (-not $SelectedServerDetails.ContainsKey("serverType"))
    {
        $message = "Server type missing for user selection '{0}'" -f $UserSelection
        Write-LogMessage $message -IsError
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
            Write-LogMessage $message -IsError
            return $False
        }
    }    

    if ($message)
    {
        Write-LogMessage $message -IsError

        Write-LogMessage "RESULT: Selected server details are not valid." -IsError

        return $False
    }

    Write-LogMessage "RESULT: Selected server details okay." 

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
    [switch]$SqlVerboseLoggingOn
    )
{
    $message = "Checking the existence of default database '{0}' on SQL Server {1}..." `
        -f $DefaultDatabase, $SelectedServerDetails.serverName
    Write-LogMessage $message 

    if (-not $DefaultDatabase -or -not $DefaultDatabase.Trim())
    {
        Write-LogMessage "No default database supplied." -IsError

        Write-LogMessage "RESULT: No default database supplied." -IsError

        return $False
    }

    $SqlQuery = "SELECT name FROM sys.databases WHERE name = '{0}'" -f $DefaultDatabase
    $result = Invoke-Sql -SelectedServerDetails $SelectedServerDetails `
        -DefaultDatabase $DefaultDatabase -SqlVerboseLoggingOn:$SqlVerboseLoggingOn `
        -SqlQuery $SqlQuery

    if (-not $result -or -not $result.wasSuccessful)
    {
        $message = "Database {0} not found on SQL Server {1}" `
            -f $DefaultDatabase, $SelectedServerDetails.serverName
        Write-LogMessage $message -IsError

        Write-LogMessage "RESULT: Database not found." -IsError

        return $False
    }    

    Write-LogMessage "RESULT: Database found."

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
    [switch]$SqlVerboseLoggingOn,

    [Parameter(Mandatory=$False)]
    [string]$LogFileName
    )
{
    $userSelection = Get-UserSelection $SqlServers
    $selectedServerDetails =  Get-ServerDetails $SqlServers $userSelection
    
    Write-LogHeader -SelectedServerDetails $selectedServerDetails -LogFileName $LogFileName

    $startTime = Get-Date

    $serverDetailsOk = Test-ServerDetails -SelectedServerDetails $selectedServerDetails `
        -UserSelection $userSelection

    if (-not $serverDetailsOk)
    {
        return
    }

    $defaultDatabaseExists = Test-DefaultDatabase -SelectedServerDetails $selectedServerDetails `
        -DefaultDatabase $DefaultDatabase -SqlVerboseLoggingOn:$SqlVerboseLoggingOn

    if (-not $defaultDatabaseExists)
    {
        return
    }

    $message = "Executing SQL scripts on server {0}..." -f $selectedServerDetails.serverName
    Write-LogMessage $message 

    $allScriptsSuccessful = $True
    $SqlScriptNames `
    | Select-Object @{Name="sqlScriptFileName"; Expression={$_}} `
    | Invoke-Sql -SelectedServerDetails $selectedServerDetails `
                                -DefaultDatabase $DefaultDatabase `
                                -SqlVerboseLoggingOn:$SqlVerboseLoggingOn `
    | ForEach-Object { if (-not $_.wasSuccessful) {$allScriptsSuccessful = $False} }
    
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

foreach($module in $_requiredModules)
{
    Install-RequiredModule -ModuleName $module -RepositoryName $_moduleRepository -ProxyUrl $_proxyServerUrl
}

Initialize-Logger -LogFileName $_logFileName -OverwriteLogFile:$_overwriteLogFile
Write-Output ''

Update-Database -SqlServers $_sqlServers -DefaultDatabase $_defaultDatabase `
    -SqlScriptNames $_sqlScriptNames -SqlVerboseLoggingOn:$_sqlVerboseLoggingOn `
    -LogFileName $_logFileName