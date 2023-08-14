<#
.SYNOPSIS
Restarts one or more existing Windows services.

.DESCRIPTION
Checks whether a Windows service with the specified name exists and, if it does, stops it then  
restarts it.  A Windows service must be restarted to pick up changes to its config file (note 
that a restart is not required for a web site or web application as IIS restarts automatically 
when a web.config is changed).

.NOTES
Must be run with elevated permissions.

Uses the service name to specify the service, not the display name.  The service name can be 
found from the Services console: Select the service, right click and select "Properties" then 
the "General" tab.  The service name will be at the top of the General tab.
#>

$servicesToUpdate = @("JobMediatorService"
                    )

# If no path is specified for the log file it will be created in the directory this script 
# is running in.  Similarly, relative paths will be relative to the directory this script 
# is running in.
[string]$logFileName = "windowsservicerestart.log"

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
        $message = "RESULT: ONE OR MORE ERRORS ENCOUNTERED.  For details search log messages " `
            + "above for the text `"ERROR`" or `"WARNING:`"."
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
Restarts an existing Windows services.

.DESCRIPTION
Checks whether a Windows service with the specified name exists and, if it does, stops it then  
restarts it.  

A Windows service must be restarted to pick up changes to its config file.

.OUTPUTS 
Integer that may take one of the following values:
    0: Error:  One or more errors were encountered, preventing the restart of the Windows service;
    1: Partial Success:  NOT USED;
    2: Full Success:  The service was restarted. 

.NOTES
Uses the service name to specify the service, not the display name.  The service name can be 
found from the Services console: Select the service, right click and select "Properties" then 
the "General" tab.  The service name will be at the top of the General tab.
#>
function Restart-WindowsService (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$ServiceName,

    [Parameter(Mandatory=$False)]
    [string]$logFileName
    )
{
    Write-LogMessage "Restarting Windows service '$ServiceName'..." `
        -logFileName $logFileName

    $StatusValue = @{Failure=0; PartialFailure=1; FullSuccess=2}

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
        $resultMessage = "RESULT: Unable to stop Windows service '$ServiceName'.  " `
            + "You may need to manually stop and restart the service." 
        Write-LogMessage $resultMessage -logFileName $logFileName -ConsoleTextColor "Cyan"
        return $StatusValue.Failure
    }

    Write-LogMessage "Starting Windows service '$ServiceName' again..." `
        -logFileName $logFileName

    $succeeded = Start-ServiceController -ServiceController $serviceController `
        -logFileName $logFileName
    
    if (-not $succeeded)
        {
        $resultMessage = "RESULT: Unable to restart Windows service '$ServiceName'.  " `
            + "You may need to manually restart the service." 
        Write-LogMessage $resultMessage -logFileName $logFileName -ConsoleTextColor "Cyan"
        return $StatusValue.Failure
        }

    Write-LogMessage "RESULT: Windows service '$ServiceName' restarted successfully." `
        -logFileName $logFileName -ConsoleTextColor "Cyan"

    return $StatusValue.FullSuccess
}

Clear-Host

Write-LogHeader -title "Restarting Windows services" `
    -logFileName $logFileName -overwriteLogFile:$overwriteLogFile

$overallResult = $StatusValue.FullSuccess

foreach($serviceName in $servicesToUpdate)
{
    $result = Restart-WindowsService -ServiceName $serviceName -logFileName $logFileName
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