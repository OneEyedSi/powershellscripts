<#
.SYNOPSIS
Sets the credentials that an existing app pool runs under.

.DESCRIPTION
Checks whether an IIS app pool with the specified name exists and, if it does, updates the 
credentials it uses then stops and restarts it to pick up the change.

.NOTES
Must be run with elevated permissions.

Assembly Microsoft.Web.Administration, Version=7.0.0.0, must exist on the machine this script is 
running on.

For the app pool identity this module accepts standard aliases for built-in accounts, for example:
    1) Local System: "LocalSystem", "Local System", "System", "NT AUTHORITY\SYSTEM",
        ".\SYSTEM", ".\LOCALSYSTEM", "{computer name}\SYSTEM", etc;
    2) Local Service:  "LocalService", "Local Service", "Service", "NT AUTHORITY\SERVICE",
        ".\SERVICE" ".\LOCALSERVICE", "{computer name}\SERVICE", etc;
    3) Network Service: "NetworkService", "Network Service" and 
        "NT AUTHORITY\NETWORKSERVICE";
    4) Application Pool Identity: "ApplicationPoolIdentity", "Application Pool Identity", 
        "ApplicationPool Identity", "AppPoolIdentity", "App Pool Identity", "AppPool Identity".

#>
Import-Module WebAdministration 

<#
Format: A list of hash tables, one for each app pool to update.  Each hash table has three 
elements: 
   1) Name: Required.  The app pool name;
   2) Identity: Required.  The identity the app pool will run under.  This may be a built-in 
        account: one of ApplicationPoolIdentity, Local Service, Local System or Network Service.  
        Alternatively, it may be a Windows account;
   3) Password: Optional.  The password for the Windows account.  For a built-in account the 
        password will be ignored so may be left out or set to $null or an empty string.
#>
$AppPoolDetails = @( `
                    @{Name=".NET v2.0"; `
                      Identity="App pool identity"; `
                      Password=$Null}, `
                    @{Name="TestWebServices"; `
                      Identity="ApplicationPoolIdentity"} `
                   )

# If no path is specified for the log file it will be created in the directory this script 
# is running in.  Similarly, relative paths will be relative to the directory this script 
# is running in.
[string]$LogFileName = "appPoolUpdate.log"

# If set overwrites any existing log file.  If cleared appends to an existing log file.  If 
# no log file exists a new one will be created, regardless of the setting of this variable.
$OverwriteLogFile = $False 

# Do not change these values, they're used in multiple places in the script.
$StatusValue = @{Failure=0; PartialFailure=1; Success=2}

<#
.SYNOPSIS
Gets the absolute path of the specified path.

.DESCRIPTION
Determines whether the path supplied is an absolute or a relative path.  If it is 
absolute it is returned unaltered.  If it is relative then the path to the directory this 
script is running in will be prepended to the specified path.

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

If the NoLog parameter is set Write-LogMessage will exit without performing any action; it will 
not write to either the host or to a log file.

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
    [switch]$IsWarningMessage,

    [Parameter(Mandatory=$False)]
    [switch]$IsErrorMessage,

    [Parameter(Mandatory=$False)]
    [switch]$NoLog,

    [Parameter(Mandatory=$False)]
    [switch]$OverwriteLogFile
    )
{
    if ($NoLog)
    {
        return
    }

    $TimeText = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
    $CallingFunctionName = (Get-Variable MyInvocation -Scope 1).Value.MyCommand.Name

    if (!$CallingFunctionName)
    {
        $CallingFunctionName = "----"
    }
    
    $MessageType = ""        
    if ($IsErrorMessage)
    {
        $MessageType = "ERROR"
    }
    elseif ($IsWarningMessage)
    {
        $MessageType = "WARNING"
    }

    if ($Message)
    {
        if ($MessageType)
        {
            $MessageType = "$($MessageType): "
        }
        $OutputMessage = "{0} | {1} | {2}{3}" -f $TimeText, $CallingFunctionName, $MessageType, $Message
    }
    else
    { 
        if ($MessageType)
        {
            $MessageType = " $($MessageType)"
        }
        $OutputMessage = "{0} |{1}" -f $TimeText, $MessageType
    }
        
    if ($WriteRawMessageOnly)
    {
        $OutputMessage = $Message
        if (-not $OutputMessage)
        {
            $OutputMessage = " "
        }
    }

    if ($IsErrorMessage)
    {
        Write-Error $OutputMessage
    }
    elseif ($IsWarningMessage)
    {
        Write-Host $OutputMessage -ForegroundColor "Yellow"
    }
    elseif ($ConsoleTextColor)
    {
        Write-Host $OutputMessage -ForegroundColor $ConsoleTextColor
    }
    else
    {
        Write-Host $OutputMessage
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

    # Ensure that if a path is not specified the log file gets created in the same folder as 
    # this script is running in.
    $LogFileName = Get-AbsolutePath $LogFileName

    if (-not (Test-Path $LogFileName -IsValid))
    {
        # Fail silently so that every message output to the console doesn't include an error 
        # message.
        return
    }

    if ($OverwriteLogFile -or -not (Test-Path $LogFileName))
    {
        $OutputMessage | Set-Content $LogFileName
    }
    else
    {
        $OutputMessage | Add-Content $LogFileName
    }
}

<#
.SYNOPSIS
Writes a heading to the host and, optionally, to a log file.

.DESCRIPTION
Writes a heading that makes it obvious the script has just started.

.NOTES
Useful for scripts that may be run repeatedly.
#>
function Write-LogHeader (
    [Parameter(Mandatory=$True)]
    $Title, 

    [Parameter(Mandatory=$False)]
    [string]$LogFileName,

    [Parameter(Mandatory=$False)]
    [switch]$OverwriteLogFile
    )
{
    $MinLineLength = 50
    $LineLength = $Title.Length
    if ($LineLength -lt $MinLineLength)
    {
        $LineLength = $MinLineLength
    }
    $HorizontalLine = "=" * $LineLength

    Write-LogMessage $HorizontalLine -LogFileName $LogFileName -writeRawMessageOnly `
        -overwriteLogFile:$OverwriteLogFile

    Write-LogMessage $Title -LogFileName $LogFileName -writeRawMessageOnly

    $DateText = (Get-Date).ToString("yyyy-MM-dd")
    $Message = "Run date: {0}" -f $DateText
    Write-LogMessage $Message -LogFileName $LogFileName -writeRawMessageOnly

    Write-LogMessage $HorizontalLine -LogFileName $LogFileName -writeRawMessageOnly
}

<#
.SYNOPSIS
Writes a footer to the host and, optionally, to a log file.

.DESCRIPTION
Writes a footer that makes it obvious the script has completed.

.PARAMETER ScriptResult
An integer indicating the overall result of the script.  Its value must be one of the following:
    0: Failure: One or more errors were encountered, preventing the update of any config file;
    1: Partial Failure: Some but not all config files were updated;
    2: Success: All config files were updated. 

.NOTES
Useful for scripts that may be run repeatedly.
#>
function Write-LogFooter (
    [Parameter(Mandatory=$True)]
    $ScriptResult,

    [Parameter(Mandatory=$False)]
    [string]$ResultText,

    [Parameter(Mandatory=$False)]
    [string]$LogFileName
    )
{
    $NL = [Environment]::NewLine

    $MessageColor = "Red"
    $ResultHeader = "RESULT: UNRECOGNISED RESULT CODE: $ScriptResult"

    $HeaderTerminator = ""
    if ($ResultText)
    {
        $HeaderTerminator = "; "
    }

    switch ($ScriptResult)
    {
        0   { 
                $MessageColor = "Red"
                $ResultHeader = "RESULT: FAILURE"
            }

        1   { 
                $MessageColor = "Yellow"
                $ResultHeader = "RESULT: PARTIAL FAILURE"
            }

        2   { 
                $MessageColor = "Green"
                $ResultHeader = "RESULT: SUCCESS"
            }
    }

    $Message = "$($ResultHeader)$($HeaderTerminator)$ResultText"

    # Write basic result as normal log message to make it easier for automated parsing.
    Write-LogMessage $ResultHeader -LogFileName $LogFileName 

    $MinLineLength = 50
    $maxLineLength = 100
    $LineLength = $Message.Length
    if ($LineLength -lt $MinLineLength)
    {
        $LineLength = $MinLineLength
    }
    elseif ($LineLength -gt $maxLineLength)
    {
        $LineLength = $maxLineLength
    }
    $HorizontalLine = "-" * $LineLength

    Write-LogMessage $HorizontalLine -LogFileName $LogFileName -writeRawMessageOnly

    Write-LogMessage $Message -consoleTextColor $MessageColor -LogFileName $LogFileName `
        -writeRawMessageOnly

    Write-LogMessage $HorizontalLine -LogFileName $LogFileName -writeRawMessageOnly
}

<#
.SYNOPSIS
Builds an error message that includes the details of an exception.

.DESCRIPTION
Builds an error message made up of an error header which describes the action that failed, the 
details of the exception that occurred, and an optional additional message.

.NOTES

#>
function Get-ExceptionErrorMessage (
    [Parameter(Mandatory=$True)]
    [ValidateNotNull()]
    [System.Exception]$Exception,

    [string]$ErrorHeader, 

    [string]$AdditionalMessage
    )
{
    $ErrorMessage = ""
    if (-not [string]::IsNullOrBlank($ErrorHeader))
    {
        $ErrorMessage += "$($ErrorHeader.Trim()): "
    }

    if (-not [string]::IsNullOrBlank($AdditionalMessage))
    {
        $AdditionalMessage = $AdditionalMessage.Trim()
        if (-not $AdditionalMessage.EndsWith("."))
        {
            $AdditionalMessage += "."
        }
        $ErrorMessage += "$($AdditionalMessage.Trim())  "
    }

    $InnerExceptionDetails = ""
    if ($Exception.InnerException)
    {
        $InnerExceptionDetails = " (inner exception - $(Get-ExceptionErrorMessage -Exception $Exception.InnerException))"
    }

    $ExceptionMessage = $Exception.Message
    if (-not $ExceptionMessage.EndsWith("."))
    {
        $ExceptionMessage += "."
    }
    $ExceptionDetails = "$($Exception.GetType().FullName): $($ExceptionMessage)$InnerExceptionDetails"
    $ErrorMessage += $ExceptionDetails
    return $ErrorMessage
}

<#
.SYNOPSIS
Gets the correct account name to use for common aliases of built-in accounts.

.DESCRIPTION
Gets the correct account name to use for common aliases of built-in accounts.  If the supplied 
login is not a built-in account it will be returned unchanged.

.OUTPUTS
String with the correct account name to use.  The string will take one of the following values:
    "LOCALSYSTEM"
    "NT AUTHORITY\LOCALSERVICE"
    "NT AUTHORITY\NETWORKSERVICE"
    "ApplicationPoolIdentity"
    or
    The original account name, unchanged.

.NOTES
Common aliases of built-in accounts include:
    1) Local System: "LocalSystem", "Local System", "System", "NT AUTHORITY\SYSTEM",
        ".\SYSTEM", ".\LOCALSYSTEM", "{computer name}\SYSTEM", etc;
    2) Local Service:  "LocalService", "Local Service", "Service", "NT AUTHORITY\SERVICE",
        ".\SERVICE" ".\LOCALSERVICE", "{computer name}\SERVICE", etc;
    3) Network Service: "NetworkService", "Network Service" and 
        "NT AUTHORITY\NETWORKSERVICE";
    4) Application Pool Identity: "ApplicationPoolIdentity", "Application Pool Identity", 
        "ApplicationPool Identity", "AppPoolIdentity", "App Pool Identity", "AppPool Identity".
#>
function Get-AccountName (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$Login, 

    [Parameter(Mandatory=$False)]
    [string]$LogFileName,

    [Parameter(Mandatory=$False)]
    [switch]$NoLog
    )
{
    Write-LogMessage "Getting the account name for user '$Login'..." `
        -LogFileName $LogFileName -NoLog:$NoLog

    $UnaliasedLogOn = $Login

    # New-Service won't accept common aliases for built-in accounts.  Therefore if a known alias 
    # is specified convert to a form that New-Service will accept.
    if (("SYSTEM", "LOCALSYSTEM", "Local System") -contains $Login `
    -or $Login.EndsWith("SYSTEM") -or $Login.EndsWith("LOCALSYSTEM"))
    {
        #$UnaliasedLogOn = "NT AUTHORITY\SYSTEM"        
        $UnaliasedLogOn = "LOCALSYSTEM"        
    }
    elseif (("SERVICE", "LOCALSERVICE", "Local Service") -contains $Login `
    -or $Login.EndsWith("SERVICE") -or $Login.EndsWith("LOCALSERVICE"))
    {
        $UnaliasedLogOn = "NT AUTHORITY\LOCALSERVICE"
    }
    elseif (("NETWORKSERVICE", "Network Service") -contains $Login `
    -or $Login.EndsWith("NETWORKSERVICE"))
    {
        $UnaliasedLogOn = "NT AUTHORITY\NETWORKSERVICE"
    }
    elseif (("ApplicationPoolIdentity", "Application Pool Identity", "ApplicationPool Identity", `
            "AppPoolIdentity", "App Pool Identity", "AppPool Identity") -contains $Login)
    {
        $UnaliasedLogOn = "ApplicationPoolIdentity"
    }

    if ($UnaliasedLogOn -ne $Login)
    {
        Write-LogMessage "Account alias '$Login' has been mapped to underlying account '$UnaliasedLogOn'." `
            -LogFileName $LogFileName -NoLog:$NoLog
    }
    else
    {
        Write-LogMessage "Using login '$Login' unchanged." `
            -LogFileName $LogFileName -NoLog:$NoLog
    }

    return $UnaliasedLogOn
}

<#
.SYNOPSIS
Gets the value that will be set for the app pool Process Model.

.DESCRIPTION
Gets the value that will be set for the app pool Process Model.  This is the value that will be 
passed to:
    Set-ItemProperty -Path $AppPoolPath -Name ProcessModel -Value *VALUE PASSED HERE*

.PARAMETER AppPoolDetail
A hash table, with details of the app pool to update.  It has three elements: 
   1) Name: Required.  The app pool name;
   2) Identity: Required.  The identity the app pool will run under.  This may be a built-in 
        account: one of ApplicationPoolIdentity, Local Service, Local System or Network Service.  
        Alternatively, it may be a Windows account;
   3) Password: Optional.  The password for the Windows account.  For a built-in account the 
        password will be ignored so may be left out or set to $null or an empty string.

.OUTPUTS
A hash table that has up to three elements:
    1) IdentityType: Required.  One of the Microsoft.Web.Administration.ProcessModelIdentityType 
        enum values;
    2) UserName: Optional.  Only needed if the new identity for the app pool is NOT a built-in 
        account such as ApplicationPoolIdentity; 
    3) Password: Optional  Only needed if the new identity for the app pool is NOT a built-in 
        account such as ApplicationPoolIdentity.

.NOTES
Assembly Microsoft.Web.Administration must have been loaded before calling this function.
#>
function Get-AppPoolProcessModelValue (
        [Parameter(Mandatory=$True)]
        $AppPoolDetail,

        [Parameter(Mandatory=$False)]
        [string]$LogFileName,

        [Parameter(Mandatory=$False)]
        [switch]$NoLog
    )
{
    $AppPoolName = $AppPoolDetail.Name
    
    Write-LogMessage "Getting the Process Model values for app pool '$AppPoolName'..." `
        -LogFileName $LogFileName -NoLog:$NoLog
    
    # Use standard function to resolve possible aliases of built-in accounts.
    $UserName = Get-AccountName -Login $AppPoolDetail.Identity `
        -LogFileName $LogFileName -NoLog:$NoLog

    Write-LogMessage "De-aliased username is '$UserName'." -LogFileName $LogFileName -NoLog:$NoLog

    # The different values the IdentityType can take are specified here:
    #    "Process Model Settings for an Application Pool", 
    #    https://docs.microsoft.com/en-us/iis/configuration/system.applicationhost/applicationpools/add/processmodel#configuration
    # The values are specified in enum Microsoft.Web.Administration.ProcessModelIdentityType.
    # Assembly Microsoft.Web.Administration must have been loaded prior to calling this function.
    $IdentityType = [Microsoft.Web.Administration.ProcessModelIdentityType]

    $ProcessModelValues = @{ IdentityType=$IdentityType::ApplicationPoolIdentity }

    switch ($UserName)
    {
        "LOCALSYSTEM"  { 
                $ProcessModelValues.IdentityType=$IdentityType::LocalSystem
            }

        "NT AUTHORITY\LOCALSERVICE"   { 
                $ProcessModelValues.IdentityType=$IdentityType::LocalService
            }

        "NT AUTHORITY\NETWORKSERVICE"   { 
                $ProcessModelValues.IdentityType=$IdentityType::NetworkService
            }

        "ApplicationPoolIdentity"   { 
                $ProcessModelValues.IdentityType=$IdentityType::ApplicationPoolIdentity
            }

        default   { 
                $ProcessModelValues.IdentityType=$IdentityType::SpecificUser
                $ProcessModelValues.UserName=$UserName
                $ProcessModelValues.Password=$AppPoolDetail.Password
            }
    }

    $LogMessage = "The ProcessModel values for app pool '$AppPoolName' are: "

    # This enumerates through the keys of the ProcessModelValues, adding the keys and their values
    # to the log message.  For key "Password" don't display the value in the log message.
    $ProcessModelValues.Keys.ForEach{$LogMessage += "$_=" + (&{if ($_ -eq "Password") {"******; "} else { "$($ProcessModelValues[$_]); "}}) }

    Write-LogMessage $LogMessage -LogFileName $LogFileName -NoLog:$NoLog

    return $ProcessModelValues
}

<#
.SYNOPSIS
Checks that the specified hash table key exists and has a value.

.DESCRIPTION
Checks that the specified hash table key exists and has a value.

.OUTPUTS
String that represents an error message.  If the string is null or empty then the specified 
hash table key exists and has a value.

.NOTES
#>
function Test-HashTableElement (
    [Parameter(Mandatory=$True)]
    [System.Collections.Hashtable]$HashTable,
    
    [Parameter(Mandatory=$True)]
    [string]$KeyName
    )
{
    if (-not $HashTable)
    {
        return "Hash table has not been defined."
    }

    if (-not $HashTable.ContainsKey($KeyName))
    {
        return "Hash table does not contain key '$KeyName'."
    }

    if (-not $HashTable[$KeyName])
    {
        return "Value of hash table element '$KeyName' is not set."
    }

    return $Null
}

<#
.SYNOPSIS
Checks the details of a single app pool have been supplied in the correct format.

.DESCRIPTION
Checks the details of a single app pool have been supplied in the correct format.

.PARAMETER AppPoolDetail
A hash table, with details of the app pool to update.  It has three elements: 
   1) Name: Required.  The app pool name;
   2) Identity: Required.  The identity the app pool will run under.  This may be a built-in 
        account: one of ApplicationPoolIdentity, Local Service, Local System or Network Service.  
        Alternatively, it may be a Windows account;
   3) Password: Optional.  The password for the Windows account.  For a built-in account the 
        password will be ignored so may be left out or set to $null or an empty string.

.OUTPUTS
Hash table that has four elements:
    1) Id: A string that uniquely identifies the result in the output pipeline.  In this case the 
        Id will be the Name from the AppPoolDetail input parameter;
    2) Success: A boolean that indicates whether the specified app pool details are in the correct 
        format;
    3) ErrorMessages: An array of strings.  Each string is an error message.  If the app pool 
        details are in the correct format ErrorMessages should be an empty array;
    4) Value: Not used, set to $Null.

.NOTES
Assembly Microsoft.Web.Administration must have been loaded before calling this function.
#>
function Test-SingleAppPoolDetail (
        [Parameter(Mandatory=$True)]
        $AppPoolDetail,

        [Parameter(Mandatory=$False)]
        [string]$LogFileName
    )
{
    $Result = @{Id=$Null; Success=$False; ErrorMessages=@(); Value=$Null}
    $AppPoolName = $Null
    
    $ErrorMessageHeader = "Incorrect format for app pool details" 

    if ($AppPoolDetail -isnot [System.Collections.Hashtable])
    {
        $ErrorMessage = "$($ErrorMessageHeader): Expected app pool details to be a " `
            + "hash table, was actually a $($AppPoolDetail.GetType().Fullname)"

        Write-LogMessage $ErrorMessage -logFileName $LogFileName -isErrorMessage

        $Result.ErrorMessages +=  $ErrorMessage
        return $Result
    }
        
    $ErrorMessage = (Test-HashTableElement -HashTable $AppPoolDetail -KeyName "Name")
    if ($ErrorMessage)
    {
        $ErrorMessage = "$($ErrorMessageHeader): $ErrorMessage"

        Write-LogMessage $ErrorMessage -logFileName $LogFileName -isErrorMessage

        $Result.ErrorMessages +=  $ErrorMessage
    }
    else
    {
        $AppPoolName = $AppPoolDetail.Name
        $Result.Id = $AppPoolName
        $ErrorMessageHeader = "Incorrect format for app pool details '$AppPoolName'" 
    }    

    $ErrorMessage = (Test-HashTableElement -HashTable $AppPoolDetail -KeyName "Identity")
    if ($ErrorMessage)
    {
        $ErrorMessage = "$($ErrorMessageHeader): $ErrorMessage"

        Write-LogMessage $ErrorMessage -logFileName $LogFileName -isErrorMessage

        $Result.ErrorMessages +=  $ErrorMessage
    }  

    # Don't write log messsages to the log file for Get-AppPoolProcessModelValue since we're 
    # only logging errors in this function, not informational messages.
    $ProcessModelValuesToSet = Get-AppPoolProcessModelValue -AppPoolDetail $AppPoolDetail -NoLog

    # We only need to check Password for identity type SpecificUser.
    if ($ProcessModelValuesToSet.IdentityType `
        -eq [Microsoft.Web.Administration.ProcessModelIdentityType]::SpecificUser)
    {
        $ErrorMessage = (Test-HashTableElement -HashTable $AppPoolDetail -KeyName "Password")
        if ($ErrorMessage)
        {
            $ErrorMessage = "$($ErrorMessageHeader): $ErrorMessage"

            Write-LogMessage $ErrorMessage -logFileName $LogFileName -isErrorMessage

            $Result.ErrorMessages +=  $ErrorMessage
        }
    }

    if ($Result.ErrorMessages.Count -eq 0)
    {
        $Result.Success = $True
    }

    return $Result
}

<#
.SYNOPSIS
Checks the app pool was updated correctly.

.DESCRIPTION
Reads the app pool details and compares them to the values that should have been set.

.PARAMETER ProcessModelValuesToSet
A hash table with details of the new settings of the app pool process model.  
It has up to three elements:
    1) IdentityType: Required.  One of the Microsoft.Web.Administration.ProcessModelIdentityType 
        enum values;
    2) UserName: Optional.  Only needed if the new identity for the app pool is NOT a built-in 
        account such as ApplicationPoolIdentity; 
    3) Password: Optional  Only needed if the new identity for the app pool is NOT a built-in 
        account such as ApplicationPoolIdentity.

.OUTPUTS
Hash table that has four elements:
    1) Id: A string that uniquely identifies the result in the output pipeline.  In this case the 
        Id will be the Name from the AppPoolDetail input parameter;
    2) Success: A boolean that indicates whether the specified app pool was updated correctly or 
        not;
    3) ErrorMessages: An array of strings.  Each string is an error message.  If the app pool 
       was updated correctly ErrorMessages should be an empty array;
    4) Value: Not used, set to $Null.

.NOTES
Assembly Microsoft.Web.Administration must have been loaded before calling this function.

#>
function Test-UpdatedAppPool (
        [Parameter(Mandatory=$True)]
        $AppPoolName,

        [Parameter(Mandatory=$True)]
        $ProcessModelValuesToSet, 

        [Parameter(Mandatory=$False)]
        [string]$LogFileName
    )
{
    $Result = @{Id=$AppPoolName; Success=$False; ErrorMessages=@(); Value=$Null}

    $AppPoolPath = "IIS:\AppPools\$AppPoolName"

    $ErrorMessageHeader = "Unknown error updating app pool '$AppPoolName'"

    $UpdatedProcessModel = Get-ItemProperty -Path $AppPoolPath -Name ProcessModel 
        
    # ProcessModel.IdentityType returned by Get-ItemProperty is a string and  
    # $ProcessModelValuesToSet.IdentityType is a ProcessModelIdentityType enum value but we 
    # can still compare them.
    if ($UpdatedProcessModel.IdentityType -ne $ProcessModelValuesToSet.IdentityType)
    {            
        # Use $ProcessModelValuesToSet.IdentityType.ToString() to display only the enum value 
        # name.  If we left out ToString() we would get the full name of the enum value, 
        # including type name and namespace.
        $ErrorMessage = "$($ErrorMessageHeader): IdentityType was not set correctly.  " `
            + "Expected $($ProcessModelValuesToSet.IdentityType.ToString()); " `
            + "actual value $($UpdatedProcessModel.IdentityType)"

        Write-LogMessage $ErrorMessage -logFileName $LogFileName -isErrorMessage

        $Result.Success = $False
        $Result.ErrorMessages +=  $ErrorMessage
        return $Result
    }

    # We only need to check ProcessModel.UserName and ProcessModel.Password for identity type 
    # SpecificUser.
    if ($ProcessModelValuesToSet.IdentityType `
        -eq [Microsoft.Web.Administration.ProcessModelIdentityType]::SpecificUser)
    {
        if ($UpdatedProcessModel.UserName -ne $ProcessModelValuesToSet.UserName)
        {            
            $ErrorMessage = "$($ErrorMessageHeader): UserName was not set correctly.  " `
                + "Expected $($ProcessModelValuesToSet.UserName); " `
                + "actual value $($UpdatedProcessModel.UserName)"

            Write-LogMessage $ErrorMessage -logFileName $LogFileName -isErrorMessage

            $Result.Success = $False
            $Result.ErrorMessages +=  $ErrorMessage
            return $Result
        }

        if ($UpdatedProcessModel.Password -ne $ProcessModelValuesToSet.Password)
        {            
            $ErrorMessage = "$($ErrorMessageHeader): Password was not set correctly."

            Write-LogMessage $ErrorMessage -logFileName $LogFileName -isErrorMessage

            $Result.Success = $False
            $Result.ErrorMessages +=  $ErrorMessage
            return $Result
        }
    }

    $Result.Success = $True
    return $Result
}

<#
.SYNOPSIS
Sets the identity of the specified app pool.

.DESCRIPTION
Sets the identity of the specified app pool.

.PARAMETER AppPoolDetail
A hash table, with details of the app pool to update.  It has three elements: 
   1) Name: Required.  The app pool name;
   2) Identity: Required.  The identity the app pool will run under.  This may be a built-in 
        account: one of ApplicationPoolIdentity, Local Service, Local System or Network Service.  
        Alternatively, it may be a Windows account;
   3) Password: Optional.  The password for the Windows account.  For a built-in account the 
        password will be ignored so may be left out or set to $null or an empty string.

.OUTPUTS
Hash table that has four elements:
    1) Id: A string that uniquely identifies the result in the output pipeline.  In this case the 
        Id will be the Name from the AppPoolDetail input parameter;
    2) Success: A boolean that indicates whether the identity of the specified app pool was 
        updated or not;
    3) ErrorMessages: An array of strings.  Each string is an error message.  If the app pool is 
        updated succcessfully ErrorMessages should be an empty array;
    4) Value: Not used, set to $Null.

.NOTES

#>
function Set-SingleAppPoolIdentity 
{
    # CmdletBinding attribute must be on first non-comment line of the function
    # and requires that the parameters be defined via the Param keyword rather 
    # than in parentheses outside the function body.
    [CmdletBinding()]
    Param
    (
        [Parameter(Position=0,
                    Mandatory=$True,
                    ValueFromPipeline=$True)]
        $AppPoolDetail,

        [Parameter(Position=1,
                    Mandatory=$False)]
        [string]$LogFileName
    )

    process
    {
        $Result = (Test-SingleAppPoolDetail -AppPoolDetail $AppPoolDetail -LogFileName $LogFileName)
        if (-not $Result.Success)
        {
            return $Result
        }
        
        $AppPoolName = $AppPoolDetail.Name
        $ErrorMessageHeader = "Unable to update app pool '$AppPoolName'"
        $Result.Success = $False

        Write-LogMessage "Setting the identity for app pool '$AppPoolName'..." `
            -LogFileName $LogFileName

        $AppPoolPath = "IIS:\AppPools\$AppPoolName"

        if (-not (Test-Path -Path $AppPoolPath))
        {
            $ErrorMessage = "$($ErrorMessageHeader): App pool not found."

            Write-LogMessage $ErrorMessage -logFileName $LogFileName -isErrorMessage

            $Result.ErrorMessages +=  $ErrorMessage
            return $Result
        }
        
        $ProcessModelValuesToSet = Get-AppPoolProcessModelValue -AppPoolDetail $AppPoolDetail `
            -LogFileName $LogFileName 

        try
        {            
            Set-ItemProperty -Path $AppPoolPath -Name ProcessModel -Value $ProcessModelValuesToSet            
        }
        catch [System.Exception]
        {
            $ErrorMessage = (Get-ExceptionErrorMessage -Exception $_.Exception `
                -ErrorHeader $ErrorMessageHeader `
                -AdditionalMessage "Error setting app pool identity")

            Write-LogMessage $ErrorMessage -logFileName $LogFileName -isErrorMessage

            $Result.Success = $False
            $Result.ErrorMessages +=  $ErrorMessage
            return $Result
        }        

        $Result = Test-UpdatedAppPool -AppPoolName $AppPoolName `
            -ProcessModelValuesToSet $ProcessModelValuesToSet -LogFileName $LogFileName
        if (-not $Result.Success)
        {
            return $Result
        }

        Write-LogMessage "Identity for app pool '$AppPoolName' updated successfully." `
            -LogFileName $LogFileName -ConsoleTextColor "Cyan"

        $Result.Success = $True
        return $Result
    }
}

<#
.SYNOPSIS
Updates the specified app pools.

.DESCRIPTION
Updates the specified app pools, setting the identity of each one.

.PARAMETER AppPoolDetails
A list of hash tables, one for each app pool to update.  Each hash table has three 
elements: 
   1) Name: Required.  The app pool name;
   2) Identity: Required.  The identity the app pool will run under.  This may be a built-in 
        account: one of ApplicationPoolIdentity, Local Service, Local System or Network Service.  
        Alternatively, it may be a Windows account;
   3) Password: Optional.  The password for the Windows account.  For a built-in account the 
        password will be ignored so may be left out or set to $null or an empty string.

.OUTPUTS
Hash table that has four elements:
    1) Id: A string that uniquely identifies the result in the output pipeline.  In this case the 
        Id will be the Name from the AppPoolDetail input parameter;
    2) Success: A boolean that indicates whether the identity of the specified app pool was 
        updated or not;
    3) ErrorMessages: An array of strings.  Each string is an error message.  If the app pool is 
        updated succcessfully ErrorMessages should be an empty array;
    4) Value: Not used, set to $Null.

.NOTES
Assembly Microsoft.Web.Administration, Version=7.0.0.0, must exist on the machine this script is 
running on.  It will be loaded by this function.

#>
function Update-AppPool (
        [Parameter(Mandatory=$True)]
        $AppPoolDetails,

        [Parameter(Mandatory=$False)]
        [string]$LogFileName
    )
{
    # Functions called by Set-SingleAppPoolIdentity need assembly Microsoft.Web.Administration to 
    # be loaded before they are called.  
    # Loading the assembly takes only 1 ms.
    Add-Type -AssemblyName "Microsoft.Web.Administration, Version=7.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35"

    Clear-Host

    $NumberOfAppPoolsToUpdate = $AppPoolDetails.Count
    Write-LogHeader -Title "Updating $NumberOfAppPoolsToUpdate app pools" `
        -LogFileName $logFileName -OverwriteLogFile:$OverwriteLogFile

    $ConsolidatedResults = $AppPoolDetails | Set-SingleAppPoolIdentity -LogFileName $LogFileName

    $NL = [Environment]::NewLine
    #$StatusValue = @{Failure=0; PartialFailure=1; Success=2}

    $NumberOfResults = $ConsolidatedResults.Count
    $NumberOfSuccessfulResults = $ConsolidatedResults.Where{$_.Success}.Count

    $ResultText = $Null
    $OverallResult = $StatusValue.Failure

    switch ($NumberOfSuccessfulResults)
    {
        0                   {
                                $OverallResult = $StatusValue.Failure
                                $ResultText = "No app pools were updated.$NL" `
                                    + "For details of the problems search log messages " `
                                    + "above for the text `"ERROR`"."
                            }
        $NumberOfResults    {
                                $OverallResult = $StatusValue.Success
                            }
        default             {
                                $OverallResult = $StatusValue.PartialFailure
                                $ItemsText = "app pools were"
                                if ($NumberOfSuccessfulResults -eq 1)
                                {
                                    $ItemsText = "app pool was"
                                }
                                $FailedIds = $ConsolidatedResults.Where{-not $_.Success}.ForEach("Id") -join ", "
                                $ResultText = "Only $NumberOfSuccessfulResults " `
                                    + "$ItemsText updated successfully out of " `
                                    + "$NumberOfResults.$NL" `
                                    + "App pools that FAILED: $FailedIds.$NL" `
                                    + "For details of the problems search log messages " `
                                    + "above for the text `"ERROR`" or `"WARNING`"."
                                break
                            }
    }

    Write-LogFooter -ScriptResult $OverallResult -ResultText $ResultText -LogFileName $LogFileName
}

Update-AppPool $AppPoolDetails $LogFileName