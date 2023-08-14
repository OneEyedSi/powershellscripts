<#
.SYNOPSIS
Sets the credentials that an existing Windows service runs under.

.DESCRIPTION
Checks whether a Windows service with the specified name exists and, if it does, updates 
the credentials it uses then stops and restarts it to pick up the change.

.NOTES
Must be run with elevated permissions.

Uses the service name to specify the service, not the display name.  The service name can be 
found from the Services console: Select the service, right click and select "Properties" then 
the "General" tab.  The service name will be at the top of the General tab.

For the service log-on this module accepts standard aliases for built-in accounts, for example:
    1) Local Service:  Can use "LocalService", "Local Service", "Service", "NT AUTHORITY\SERVICE",
        ".\SERVICE" ".\LOCALSERVICE", "{computer name}\SERVICE", etc;
    2) Network Service: Can use "NetworkService", "Network Service" and 
        "NT AUTHORITY\NETWORKSERVICE";
    3) Local System: Can use "LocalSystem", "Local System", "System", "NT AUTHORITY\SYSTEM",
        ".\SYSTEM", ".\LOCALSYSTEM", "{computer name}\SYSTEM", etc.

The built-in Local Service, Network Service and Local System accounts do not require passwords.  
If one of these accounts is specified to run the service then any password can be supplied (it 
will be ignored) or the password can be set to an empty string or $null. 
#>

$servicesToUpdate = @( `
                        @{Name="EDI Service"; `
                            LogOn="Local Service"; `
                            Password=""}, `
                        @{Name="Inbound Data Transfer"; `
                            LogOn="Local System"; `
                            Password=""} `
                    )

# If no path is specified for the log file it will be created in the directory this script 
# is running in.  Similarly, relative paths will be relative to the directory this script 
# is running in.
[string]$logFileName = "windowsservice.log"

# If set overwrites any existing log file.  If cleared appends to an existing log file.  If 
# no log file exists a new one will be created, regardless of the setting of this variable.
$overwriteLogFile = $False 

# Do not change these values, they're used in multiple places in the script.
$StatusValue = @{Failure=0; PartialFailure=1; FullSuccess=2}

<#
.SYNOPSIS
Gets the absolute path of the specified path.

.DESCRIPTION
Determines whether the filename supplied is an absolute or a relative path.  If it is 
absolute it is returned unaltered.  If it is relative then the path to the directory this 
script is running in will be prepended to the filename.

.NOTES

#>
function Get-AbsolutePath (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$path
    )
{
    if ([System.IO.Path]::IsPathRooted($path))
    {
        return $path
    }

    $path = Join-Path $PSScriptRoot $path

    return $path
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
    [string]$message,

    [Parameter(Mandatory=$False)]
    [string]$consoleTextColor,

    [Parameter(Mandatory=$False)]
    [string]$logFileName,

    [Parameter(Mandatory=$False)]
    [switch]$writeRawMessageOnly,

    [Parameter(Mandatory=$False)]
    [switch]$isWarningMessage,

    [Parameter(Mandatory=$False)]
    [switch]$isErrorMessage,

    [Parameter(Mandatory=$False)]
    [switch]$overwriteLogFile
    )
{
    $timeText = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
    $callingFunctionName = (Get-Variable MyInvocation -Scope 1).Value.MyCommand.Name

    if (!$callingFunctionName)
    {
        $callingFunctionName = "----"
    }
    
    $messageType = ""        
    if ($isErrorMessage)
    {
        $messageType = "ERROR"
    }
    elseif ($isWarningMessage)
    {
        $messageType = "WARNING"
    }

    if ($message)
    {
        if ($messageType)
        {
            $messageType = "$($messageType): "
        }
        $outputMessage = "{0} | {1} | {2}{3}" -f $timeText, $callingFunctionName, $messageType, $message
    }
    else
    { 
        if ($messageType)
        {
            $messageType = " $($messageType)"
        }
        $outputMessage = "{0} |{1}" -f $timeText, $messageType
    }
        
    if ($writeRawMessageOnly)
    {
        $outputMessage = $message
        if (-not $outputMessage)
        {
            $outputMessage = " "
        }
    }

    if ($isErrorMessage)
    {
        Write-Error $outputMessage
    }
    elseif ($isWarningMessage)
    {
        Write-Host $outputMessage -ForegroundColor "Yellow"
    }
    elseif ($consoleTextColor)
    {
        Write-Host $outputMessage -ForegroundColor $consoleTextColor
    }
    else
    {
        Write-Host $outputMessage
    }

    if (-not $logFileName)
    {
        return
    }

    $logFileName = $logFileName.Trim()
    if (-not $logFileName)
    {
        return
    }

    # Ensure that if a path is not specified the log file gets created in the same folder as 
    # this script is running in.
    $logFileName = Get-AbsolutePath $logFileName

    if (-not (Test-Path $logFileName -IsValid))
    {
        # Fail silently so that every message output to the console doesn't include an error 
        # message.
        return
    }

    if ($overwriteLogFile -or -not (Test-Path $logFileName))
    {
        $outputMessage | Set-Content $logFileName
    }
    else
    {
        $outputMessage | Add-Content $logFileName
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
    $title, 

    [Parameter(Mandatory=$False)]
    [string]$logFileName,

    [Parameter(Mandatory=$False)]
    [switch]$overwriteLogFile
    )
{
    $minLineLength = 50
    $lineLength = $title.Length
    if ($lineLength -lt $minLineLength)
    {
        $lineLength = $minLineLength
    }
    $horizontalLine = "=" * $lineLength

    Write-LogMessage $horizontalLine -logFileName $logFileName -writeRawMessageOnly `
        -overwriteLogFile:$overwriteLogFile

    Write-LogMessage $title -logFileName $logFileName -writeRawMessageOnly

    $dateText = (Get-Date).ToString("yyyy-MM-dd")
    $message = "Run date: {0}" -f $dateText
    Write-LogMessage $message -logFileName $logFileName -writeRawMessageOnly

    Write-LogMessage $horizontalLine -logFileName $logFileName -writeRawMessageOnly
}

<#
.SYNOPSIS
Writes a footer to the host and, optionally, to a log file.

.DESCRIPTION
Writes a footer that makes it obvious the script has completed.

.PARAMETER scriptResult
An integer indicating the overall result of the script.  Its value must be one of the following:
    0: Failure: One or more errors were encountered, preventing the setting of the credentials 
        for one or more services;
    1: Partial Failure: The credentials of all services were updated but one or more services 
        were not restarted;
    2: Success: The credentials of all services were updated and all services were restarted. 

.NOTES
Useful for scripts that may be run repeatedly.
#>
function Write-LogFooter (
    [Parameter(Mandatory=$True)]
    $scriptResult,

    [Parameter(Mandatory=$False)]
    [string]$logFileName
    )
{
    $nl = [Environment]::NewLine

    $messageColor = "Red"
    $message = "RESULT: UNRECOGNISED RESULT CODE: $scriptResult."

    switch ($scriptResult)
    {
        0  { 
        $messageColor = "Red"
        $message = "RESULT: ONE OR MORE ERRORS ENCOUNTERED.  For details search log messages above for the text `"ERROR:`"."
    }
        1  { 
            $messageColor = "Yellow"
            $message = "RESULT: ALL SERVICE CREDENTIALS WERE UPDATED BUT ONE OR MORE SERVICES WERE NOT RESTARTED.$($nl)" `
                + "For details search log messages above for the text `"ERROR:`" or `"WARNING:`"."
        }
        2  { 
            $messageColor = "Green"
            $message = "RESULT: No errors encountered."
        }
    }

    $minLineLength = 50
    $maxLineLength = 100
    $lineLength = $message.Length
    if ($lineLength -lt $minLineLength)
    {
        $lineLength = $minLineLength
    }
    elseif ($lineLength -gt $maxLineLength)
    {
        $lineLength = $maxLineLength
    }
    $horizontalLine = "-" * $lineLength

    Write-LogMessage $horizontalLine -logFileName $logFileName -writeRawMessageOnly

    Write-LogMessage $message -consoleTextColor $messageColor -logFileName $logFileName `
        -writeRawMessageOnly

    Write-LogMessage $horizontalLine -logFileName $logFileName -writeRawMessageOnly
}

<#
.SYNOPSIS
Gets the correct account name to use for common aliases of built-in accounts.

.DESCRIPTION
Gets the correct account name to use for common aliases of built-in accounts.

.NOTES
#>
function Get-AccountName (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$serviceLogOn, 

    [Parameter(Mandatory=$False)]
    [string]$logFileName
    )
{
    Write-LogMessage "Getting the account name for user '$serviceLogOn'..." `
        -logFileName $logFileName

    $unaliasedLogOn = $serviceLogOn

    # New-Service won't accept common aliases for built-in accounts.  Therefore if a known alias 
    # is specified convert to a form that New-Service will accept.
    if (("SYSTEM", "LOCALSYSTEM", "Local System") -contains $serviceLogOn `
    -or $serviceLogOn.EndsWith("SYSTEM") -or $serviceLogOn.EndsWith("LOCALSYSTEM"))
    {
        #$unaliasedLogOn = "NT AUTHORITY\SYSTEM"        
        $unaliasedLogOn = "LOCALSYSTEM"        
    }
    elseif (("SERVICE", "LOCALSERVICE", "Local Service") -contains $serviceLogOn `
    -or $serviceLogOn.EndsWith("SERVICE") -or $serviceLogOn.EndsWith("LOCALSERVICE"))
    {
        $unaliasedLogOn = "NT AUTHORITY\LOCALSERVICE"
    }
    elseif (("NETWORKSERVICE", "Network Service") -contains $serviceLogOn `
    -or $serviceLogOn.EndsWith("NETWORKSERVICE"))
    {
        $unaliasedLogOn = "NT AUTHORITY\NETWORKSERVICE"
    }

    if ($unaliasedLogOn -ne $serviceLogOn)
    {
        Write-LogMessage "User alias '$serviceLogOn' has been mapped to underlying user '$unaliasedLogOn'." `
            -logFileName $logFileName
    }
    else
    {
        Write-LogMessage "Using login '$serviceLogOn' unchanged." `
            -logFileName $logFileName
    }

    return $unaliasedLogOn
}

<#
.SYNOPSIS
Determines whether the call to a method on a Win32_Service object succeeded or failed.

.DESCRIPTION
Determines whether the call to a method on a Win32_Service object succeeded or failed.  If the 
attempt failed a description of the error is returned.

.OUTPUTS 
System.Collections.Hashtable with the following elements:
    1) ReturnValue: String that echoes the $methodReturnValue parameter;
    2) Succeeded: Boolean that indicates whether the method succeeded or not, based on the value 
        of the $methodReturnValue parameter;
    3) ErrorDescription: String with a brief description of the error that caused the method to 
        fail.  If the method succeeded the ErrorDescription will be an empty string.

.NOTES
The return values and their meanings are from:
    1) "Change method of the Win32_Service class", https://msdn.microsoft.com/en-us/library/aa384901(v=vs.85).aspx;
    2) "StartService method of the Win32_Service class", https://msdn.microsoft.com/en-us/library/aa393660(v=vs.85).aspx;
    3) "StopService method of the Win32_Service class", https://msdn.microsoft.com/en-us/library/aa393673(v=vs.85).aspx
All three methods have the same possible return values.

#>
function Resolve-ServiceMethodReturnValue (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$methodReturnValue
    )
{
    $result = @{ReturnValue=$methodReturnValue; `
                Succeeded=$False; `
                ErrorDescription=""}

    if ($methodReturnValue -eq "0")
    {
        $result.Succeeded = $True
        return $result
    }

    $result.ErrorDescription = "[NO DESCRIPTION SUPPLIED]"
    switch ($methodReturnValue)
    {
        1  { $result.ErrorDescription = "Not Supported" }
        2  { $result.ErrorDescription = "Access Denied" }
        3  { $result.ErrorDescription = "Dependent Services Running" }
        4  { $result.ErrorDescription = "Invalid Service Control Code" }
        5  { $result.ErrorDescription = "Service Cannot Currently Accept Control Code" }
        6  { $result.ErrorDescription = "Service Not Running" }
        7  { $result.ErrorDescription = "Service Request Timeout" }
        8  { $result.ErrorDescription = "Unknown Failure" }
        9  { $result.ErrorDescription = "Path To Service Executable Not Found" }
        10 { $result.ErrorDescription = "Service Already Running" }
        11 { $result.ErrorDescription = "Service Database Locked" }
        12 { $result.ErrorDescription = "Service Dependency Missing" }
        13 { $result.ErrorDescription = "Service Dependency Failure" }
        14 { $result.ErrorDescription = "Service Disabled" }
        15 { $result.ErrorDescription = "Service Logon Failed" }
        16 { $result.ErrorDescription = "Service Marked For Deletion" }
        17 { $result.ErrorDescription = "Service Has No Execution Thread" }
        18 { $result.ErrorDescription = "Status Circular Dependency" }
        19 { $result.ErrorDescription = "Status Duplicate Name" }
        20 { $result.ErrorDescription = "Status Invalid Name" }
        21 { $result.ErrorDescription = "Status Invalid Parameter" }
        22 { $result.ErrorDescription = "Status Invalid Service Account" }
        23 { $result.ErrorDescription = "Status Service Exists" }
        24 { $result.ErrorDescription = "Service Already Paused" }
    }

    return $result
}

<#
.SYNOPSIS
Changes the credentials for the specified Windows service object.

.DESCRIPTION
Changes the credentials for the specified Windows service object then logs the result.

.OUTPUTS
Boolean indicating whether the change was successful or not.

.NOTES

#>
function Set-ServiceObjectCredentials (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    $ServiceObject,
    
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$AccountName,
    
    [Parameter(Mandatory=$False)]
    [string]$Password, 

    [Parameter(Mandatory=$False)]
    [string]$logFileName
    )
{
    $returnValue = ($ServiceObject.Change($null,$null,$null,$null,$null,$null,$AccountName,$Password)).ReturnValue
    $result = Resolve-ServiceMethodReturnValue -methodReturnValue $returnValue

    if ($result.Succeeded)
    {
        Write-LogMessage "Account name has been changed." -logFileName $logFileName
        return $True
    }

    Write-LogMessage "Error attempting to change the account name: $($result.ErrorDescription) (return value $returnValue)" `
        -logFileName $logFileName -isErrorMessage

    return $False
}

<#
.SYNOPSIS
Stops the specified Windows service controller.

.DESCRIPTION
Stops the specified Windows service controller.

.OUTPUTS
Boolean indicating whether the stop was successful or not.

.NOTES

#>
function Stop-ServiceController (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    $ServiceController,

    [Parameter(Mandatory=$False)]
    [string]$logFileName
    )
{
    if ($ServiceController.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Stopped)
    {
        Write-LogMessage "Windows service already stopped." `
            -logFileName $logFileName -isWarningMessage
        # Return false to prevent the parent function from attempting to restart the service: If 
        # if was stopped originally we don't want to start it.
        return $False
    }

    try
    {
        $startTime = (Get-Date)
        Stop-Service $ServiceController

        if ($ServiceController.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Stopped)
        {
            $endTime = (Get-Date)
            $timeDifference = New-TimeSpan -Start $startTime -End $endTime

            Write-LogMessage "Windows service stopped.  Time taken to stop: $($timeDifference.TotalMilliseconds) ms" `
                -logFileName $logFileName
            return $True
        }

        Write-LogMessage "Unable to stop Windows service.  Current status: $($ServiceController.Status)." `
            -logFileName $logFileName -isErrorMessage
        return $False
    }
    catch
    {
        $message = "{0} - {1}" -f $_.Exception.GetType().Name, $_.Exception.Message
        Write-LogMessage $message -logFileName $logFileName -isErrorMessage

        return $False
    }
}

<#
.SYNOPSIS
Starts the specified Windows service controller.

.DESCRIPTION
Starts the specified Windows service controller.

.OUTPUTS
Boolean indicating whether the start was successful or not.

.NOTES

#>
function Start-ServiceController (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    $ServiceController,

    [Parameter(Mandatory=$False)]
    [string]$logFileName
    )
{
    if ($ServiceController.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running)
    {
        Write-LogMessage "Windows service already running." `
            -logFileName $logFileName -isWarningMessage
        # Return false because this is an illegal state: The service should have previously 
        # been stopped.
        return $False
    }

    try
    {
        $startTime = (Get-Date)
        Start-Service $ServiceController

        if ($ServiceController.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running)
        {
            $endTime = (Get-Date)
            $timeDifference = New-TimeSpan -Start $startTime -End $endTime

            Write-LogMessage "Windows service is running.  Time taken to start: $($timeDifference.TotalMilliseconds) ms" `
                -logFileName $logFileName
            return $True
        }

        Write-LogMessage "Unable to start Windows service.  Current status: $($ServiceController.Status)." `
            -logFileName $logFileName -isErrorMessage
        return $False
    }
    catch
    {
        $message = "{0} - {1}" -f $_.Exception.GetType().Name, $_.Exception.Message
        Write-LogMessage $message -logFileName $logFileName -isErrorMessage

        return $False
    }
}

<#
.SYNOPSIS
Sets the credentials for the specified Windows service.

.DESCRIPTION
Checks whether a Windows service with the specified name exists and, if it does, updates 
the credentials it uses then stops and restarts it to pick up the change.

.OUTPUTS 
Integer that may take one of the following values:
    0: Error:  One or more errors were encountered, preventing the update of the service credentials;
    1: Partial Success:  The credentials of the service were updated but the service was not restarted;
    2: Full Success:  The credentials of the service were updated and the service was restarted. 

.NOTES
Uses the service name to specify the service, not the display name.  The service name can be 
found from the Services console: Select the service, right click and select "Properties" then 
the "General" tab.  The service name will be at the top of the General tab.

The password parameter is optional since built-in accounts Local Service, Local System and 
Network Service do not have passwords.
#>
function Set-ServiceCredentials (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$ServiceName,
    
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$LogOn,
    
    [Parameter(Mandatory=$False)]
    [string]$Password, 

    [Parameter(Mandatory=$False)]
    [string]$logFileName
    )
{
    Write-LogMessage "Setting the account that Windows service '$ServiceName' runs under..." `
        -logFileName $logFileName

    $StatusValue = @{Failure=0; PartialFailure=1; FullSuccess=2}
     
    # Have to operate on a WMI object as the ServiceController object returned from Get-Service 
    # has no method or property that can set the credentials of an existing Windows service.  
    # Likewise, there is no cmdlet that will do it.  
    $service = Get-WmiObject Win32_Service -Filter "Name='$ServiceName'"

    if (-not $service)
    {
        Write-LogMessage "No Windows service found with name '$ServiceName'." `
            -logFileName $logFileName -isErrorMessage
        return $StatusValue.Failure
    }

    $AccountName = Get-AccountName -serviceLogOn $LogOn -logFileName $logFileName

    Write-LogMessage "Changing the account that Windows service '$ServiceName' runs under to $AccountName'..." `
        -logFileName $logFileName

    $succeeded = Set-ServiceObjectCredentials -ServiceObject $service `
        -AccountName $AccountName -Password $Password -logFileName $logFileName

    if (-not $succeeded)
    {
        return $StatusValue.Failure
    }

    # Being a bit paranoid here: Stop the service and verify it's stopped before restarting it, 
    # rather than just doing a restart.  Sometimes a service restarts so fast it's hard to tell 
    # whether it actually did stop and restart.

    # For stopping and starting the service we can use cmdlets which are much easier to work 
    # with than WMI service objects.

    $serviceController = Get-Service $ServiceName

    Write-LogMessage "Stopping Windows service '$ServiceName'..." `
        -logFileName $logFileName

    $succeeded = Stop-ServiceController -ServiceController $serviceController `
        -logFileName $logFileName
    
    if (-not $succeeded)
    {
        $resultMessage = "RESULT: Unable to stop Windows service '$ServiceName' but the " `
            + "service credentials were updated.  You may need to manually stop and restart " `
            + "the service to pick up the change." 
        Write-LogMessage $resultMessage -logFileName $logFileName -ConsoleTextColor "Cyan"
        return $StatusValue.PartialFailure
    }

    Write-LogMessage "Re-starting Windows service '$ServiceName'..." `
        -logFileName $logFileName

    $succeeded = Start-ServiceController -ServiceController $serviceController `
        -logFileName $logFileName
    
    if (-not $succeeded)
        {
        $resultMessage = "RESULT: Unable to restart Windows service '$ServiceName' but the " `
            + "service credentials were updated.  You may need to manually restart " `
            + "the service to pick up the change." 
        Write-LogMessage $resultMessage -logFileName $logFileName -ConsoleTextColor "Cyan"
        return $StatusValue.PartialFailure
        }

    Write-LogMessage "RESULT: Windows service '$ServiceName' updated successfully." `
        -logFileName $logFileName -ConsoleTextColor "Cyan"

    return $StatusValue.FullSuccess
}

Clear-Host

Write-LogHeader -title "Changing the credentials that Windows services run under" `
    -logFileName $logFileName -overwriteLogFile:$overwriteLogFile

$overallResult = $StatusValue.FullSuccess

foreach($service in $servicesToUpdate)
{
    $result = Set-ServiceCredentials -ServiceName $service.Name `
        -LogOn $service.LogOn -Password $service.Password -logFileName $logFileName
    if ($result -eq $StatusValue.Failure)
    {
        $overallResult = $StatusValue.Failure
    }
    elseif($result -eq $StatusValue.PartialFailure -and $overallResult -ne $StatusValue.Failure)
    {
        $overallResult = $StatusValue.PartialFailure
    }
}

Write-LogFooter -scriptResult $overallResult -logFileName $logFileName