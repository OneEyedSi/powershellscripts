<#
.SYNOPSIS
Installs a Windows service or re-installs it if it already exists.

.DESCRIPTION
Checks whether a Windows service with the specified name exists and, if it 
does, stops and uninstalls it.  A new version will be installed and started.

.NOTES
Must be run with elevated permissions.

If the display name is not supplied the diplay name will be set to the service name.

The description and the startup type are optional.

If the source directory path is not supplied the executable that the service is going to run 
must already be in the target directory, along with any associated config files and DLLs.

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

[string]$serviceName = "MyWinService3rdInstance"
[string]$serviceDisplayName = "" # MyWinService Third Instance
[string]$serviceDescription = "MyWinService Third Description" # MyWinService Third Description
[string]$serviceExecutableName = "MyWinService.exe"
[string]$serviceSourceDirectoryPath = "" # "...\IT\C#\DemoCode\UnityWithWindowsServiceDemo\MyWinService\bin\Debug"
[string]$serviceTargetDirectoryPath = "C:\Git\UAT2_Environment\WindowsServiceTest3"
[string]$serviceStartupType = "Automatic"

# See notes above about the aliases that can be used for Local Service, Network Service and 
#    Local System, and the passwords to use with them.
[string]$serviceLogOn = "Local Service"
[string]$servicePassword = ""

# In general you shouldn't need to change the recovery options.
[string]$serviceFirstFailureAction = "Restart"
[int]$serviceFirstRestartDelayMilliseconds = 60000
[string]$serviceSecondFailureAction = "Restart"
[int]$serviceSecondRestartDelayMilliseconds = 120000
[string]$serviceSubsequentFailuresAction = "No Action"
[int]$serviceSubsequentRestartDelayMilliseconds = 300000
[string]$serviceOnFailureRebootMessage = ""
[string]$serviceOnFailureRunCommand = ""
[string]$serviceOnFailureCommandParameters = ""
[int]$serviceResetFailCountAfterSeconds = 24 * 60 * 60     # 1 day

# Ensure script stops on first error rather than continuing, which is the default action.
$ErrorActionPreference = "Stop"

<#
.SYNOPSIS
Writes a message to the host.

.DESCRIPTION
Writes a string to the host in the form of a log message: 
{datetime} | {calling function name} | {message}

.NOTES
{calling function name} will be "----" if the function is 
called from outside any other function, at the top level of 
the script.
#>
function Write-LogMessage (
    [Parameter(Mandatory=$True)]
    [AllowEmptyString()]
    [string]$message
    )
{
    $timeText = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
    $callingFunctionName = (Get-Variable MyInvocation -Scope 1).Value.MyCommand.Name

    if (!$callingFunctionName)
    {
        $callingFunctionName = "----"
    }
    
    if ($message)
    {
        $outputMessage = "{0} | {1} | {2}" -f $timeText, $callingFunctionName, $message
    }
    else
    {
         $outputMessage = "{0} |" -f $timeText
    }

    Write-Host $outputMessage
}

<#
.SYNOPSIS
Stops and removes an existing Windows service.

.DESCRIPTION
Checks if a Windows services exists and, if so, stops and removes it.

.NOTES
#>
function Uninstall-WindowsService (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$serviceName
    )
{
    Write-LogMessage "Checking if there is an existing service with name '$serviceName'..."

    # 60x faster than using Get-WmiObject -Class Win32_Service -Filter "Name='$ServiceName'".
    $service = Get-Service $serviceName -ErrorAction Ignore

    if ($service -eq $null)
    {
        Write-LogMessage "No service found with name '$serviceName'."
        return
    }

    Write-LogMessage "Service '$serviceName' found."

    Write-LogMessage "Stopping service '$serviceName'..."

    $service | Set-Service -Status Stopped

    Write-LogMessage "Service '$serviceName' stopped."

    Write-LogMessage "Uninstalling service '$serviceName'..."

    # There is no Remove-Service cmdlet so have to use sc.exe.  Can just call sc.exe directly 
    # from Powershell.  
    # NOTE: Must include the file extension, "sc.exe", because "sc" is an alias for Set-Content.
    sc.exe delete $ServiceName

    Write-LogMessage "Existing service '$serviceName' has been uninstalled."
}

<#
.SYNOPSIS
Creates the specified directory, if required, by copying from a 
specified source directory.

.DESCRIPTION
Checks if the specified target directory exists and, if it doesn't, 
copies the source directory and its contents to the target location.
#>
function Copy-Directory (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$sourceDirectoryPath, 

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$targetDirectoryPath
    )
{
    Write-LogMessage "Checking if target directory $targetDirectoryPath exists..."
     
    if (Test-Path $targetDirectoryPath)
    {
        Write-LogMessage "Target directory $targetDirectoryPath found."
        Return
    }

    Write-LogMessage "Target directory $targetDirectoryPath not found."

    Write-LogMessage "Copying from source directory '$sourceDirectoryPath'..."

    if (!(Test-Path $sourceDirectoryPath))
    {
        $errorMessage = "Source directory '$sourceDirectoryPath' not found.  Cannot copy to target directory.  Aborting."
        throw $errorMessage
    }

    Copy-Item $sourceDirectoryPath $targetDirectoryPath -recurse

    Write-LogMessage "Target directory $targetDirectoryPath has been created."
}

<#
.SYNOPSIS
Builds the credentials that the service will run under.

.DESCRIPTION
Builds the credentials that the service will run under.

.NOTES
#>
function Get-WindowsServiceCredentials (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$serviceLogOn,
    
    [Parameter(Mandatory=$False)]
    [string]$servicePassword
    )
{
    Write-LogMessage "Building the service credentials for user '$serviceLogOn'..."

    $unaliasedLogOn = $serviceLogOn

    # New-Service won't accept common aliases for built-in accounts.  Therefore if a known alias 
    # is specified convert to a form that New-Service will accept.
    if (("SYSTEM", "LOCALSYSTEM", "Local System") -contains $serviceLogOn `
    -or $serviceLogOn.EndsWith("SYSTEM") -or $serviceLogOn.EndsWith("LOCALSYSTEM"))
    {
        $unaliasedLogOn = "NT AUTHORITY\SYSTEM"        
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
        Write-LogMessage "User alias '$serviceLogOn' has been mapped to underlying user '$unaliasedLogOn'..."
    }

    # Password is required when creating a PSCredential, even though LOCAL SYSTEM, LOCAL SERVICE 
    # or NETWORK SERVICE accounts do not have passwords.  So if no password is supplied use a 
    # dummy.
    if (!$servicePassword)
    {
        $servicePassword = "dummy"
    }
        
    # Password must be converted to a SecureString before being passed as an argument to 
    # PSCredential constructor.
    $securePassword = ConvertTo-SecureString $servicePassword -AsPlainText -Force

    $credentials = New-Object -Typename System.Management.Automation.PSCredential -ArgumentList ($unaliasedLogOn, $securePassword)

    Write-LogMessage "Service credentials built."

    return $credentials
}

<#
.SYNOPSIS
Validates a failure option for a Windows service.

.DESCRIPTION

.NOTES
#>
function Validate-WindowsServiceFailureAction (
    [Parameter(Mandatory=$True)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$Name,
    
    [Parameter(Mandatory=$False)]
    [string]$FailureAction
    )
{
    if (($null, "", "No Action", "Restart", "Restart Service", 
        "Reboot", "Restart Computer", "Run", "Run Program") -notcontains $FailureAction)
    {
        # Valid values are in pairs which are synonymous.  eg "" is the same as "No Action".
        $errorMessage = "Cannot configure recovery options for service '$Name': " `
            + "Illegal failure action '$FailureAction'.  Valid values are: " `
            + "'', 'No Action', " `
            + "'Restart', 'Restart Service', " `
            + "'Reboot', 'Restart Computer', " `
            + "'Run', 'Run Program'."
        throw $errorMessage
        return
    }  
}

<#
.SYNOPSIS
Formats a failure action for a Windows service so it is compatible with sc.exe.

.DESCRIPTION

.NOTES
#>
function Format-WindowsServiceFailureAction (
    [Parameter(Mandatory=$True)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$FailureAction,
    
    [Parameter(Mandatory=$False)]
    [int]$RestartDelayMilliseconds
    )
{
    if ($RestartDelayMilliseconds -eq 0)
    {
        $RestartDelayMilliseconds = 60000   # 1 minute
    }

    if (!$FailureAction -or $FailureAction -eq "No Action")
    {
        return ""
    }

    if ($FailureAction -eq "Restart Service")
    {
        return "Restart/$RestartDelayMilliseconds"
    }

    if ($FailureAction -eq "Restart Computer")
    {
        return "Reboot/$RestartDelayMilliseconds"
    }

    if ($FailureAction -eq "Run Program")
    {
        return "Run/$RestartDelayMilliseconds"
    }

    return "$FailureAction/$RestartDelayMilliseconds"
}

<#
.SYNOPSIS
Builds the command to run on failure of a Windows service.

.DESCRIPTION
Combines the executable path and command-line parameters into a single command which will be run 
on failure of a Windows service.  

.NOTES
sc.exe is used to set the failure options and it is fussy about the formatting of a command and 
its parameters.  This function takes care of the formatting of the command.
#>
function Get-FailureCommand (
    [Parameter(Mandatory=$True)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$OnFailureRunCommand,
    
    [Parameter(Mandatory=$False)]
    [string]$OnFailureCommandParameters
    )
{
    if (!$OnFailureRunCommand)
    {
        return $null
    }

    Write-LogMessage "Building command to run on failure from executable '$OnFailureRunCommand' and parameters '$OnFailureCommandParameters'..."

    # Formatting required by sc.exe is complicated:
    #    1) If there are command-line parameters then the entire command-line (path to the 
    #        executable followed by the command-line parameters to be passed to the command) needs 
    #        to be enclosed in double quotes;
    #    2) The path to the executable also needs to be enclosed in double quotes if there are 
    #        spaces in the path (eg C:\Program Files\...).  So the path to the executable will need 
    #        to be enclosed in nested double quotes if parameters are supplied;
    #    3) If the command parameters also contain double quotes then these are also nested inside 
    #        the double quotes enclosing the entire command-line;
    #    4) Nested double quotes have to be escaped via backslashes for sc.exe;
    #    5) Nested double quotes have to be escaped via back-ticks for Powershell.
    #
    #   
    # So we could end up with something like: 
    #    $OnFailureCommandline = "`"\`"C:\Program Files\MyApp\MyApp.exe\`" -Arg \`"a b c\`"`" 
    #
    # which will translate to a command of:
    #    ""C:\Program Files\MyApp\MyApp.exe" -Arg "a b c"".

    $OnFailureRunCommand = $OnFailureRunCommand.Trim() -replace '"', ''
    $OnFailureRunCommand = "`"$OnFailureRunCommand`""

    $OnFailureCommandline = $OnFailureRunCommand

    if ($OnFailureCommandParameters)
    {
        $OnFailureCommandParameters = $OnFailureCommandParameters -replace '\\"', '"'

        $OnFailureCommandline = "$OnFailureRunCommand $OnFailureCommandParameters"
        $OnFailureCommandline = $OnFailureCommandline -replace '"', '\"'
        $OnFailureCommandline = "`"$OnFailureCommandline`""
    }

    Write-LogMessage "Full command to run on failure: $OnFailureCommandline"

    return $OnFailureCommandline
}

<#
.SYNOPSIS
Configures the recovery options for a Windows service.

.DESCRIPTION
Configures the recovery options for a Windows service, the options that would be seen 
on the Recovery tab of the service Properties dialog in the Services console.

.NOTES
#>
function Set-WindowsServiceRecoveryOption (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,
    
    [Parameter(Mandatory=$False)]
    [string]$FirstFailureAction,
    
    [Parameter(Mandatory=$False)]
    [int]$FirstRestartDelayMilliseconds,
    
    [Parameter(Mandatory=$False)]
    [string]$SecondFailureAction,
    
    [Parameter(Mandatory=$False)]
    [int]$SecondRestartDelayMilliseconds,
    
    [Parameter(Mandatory=$False)]
    [string]$SubsequentFailuresAction,
    
    [Parameter(Mandatory=$False)]
    [int]$SubsequentRestartDelayMilliseconds,

    [Parameter(Mandatory=$False)]
    [string]$OnFailureRebootMessage,

    [Parameter(Mandatory=$False)]
    [string]$OnFailureRunCommand,

    [Parameter(Mandatory=$False)]
    [string]$OnFailureCommandParameters,
    
    [Parameter(Mandatory=$False)]
    [int]$ResetFailCountAfterSeconds
    )
{
    if (!$Name)
    {
        $errorMessage = "No service name specified.  Cannot configure recovery options."
        throw $errorMessage
        return
    }

    Write-LogMessage "Configuring recovery options for service '$Name'..."

    # If failure action is specified then reset fail count after seconds must also be 
    # specified.
    if (!$FirstFailureAction)
    {
        Write-LogMessage "No recovery options specified for service '$Name'."
        return
    }

    if ($ResetFailCountAfterSeconds -le 0)
    {
        $errorMessage = "Cannot configure recovery options for service '$Name': Reset Fail Count After cannot be 0 or less."
        throw $errorMessage
        return
    }    

    if ($FirstRestartDelayMilliseconds -le 0)
    {
        $errorMessage = "Cannot configure recovery options for service '$Name': First Restart Delay (ms) cannot be 0 or less."
        throw $errorMessage
        return
    }    

    if ($SecondRestartDelayMilliseconds -le 0)
    {
        $errorMessage = "Cannot configure recovery options for service '$Name': Second Restart Delay (ms) cannot be 0 or less."
        throw $errorMessage
        return
    }    

    if ($SubsequentRestartDelayMilliseconds -le 0)
    {
        $errorMessage = "Cannot configure recovery options for service '$Name': Subsequent Restart Delay (ms) cannot be 0 or less."
        throw $errorMessage
        return
    }   

    if ($ResetFailCountAfterSeconds -eq 0)
    {
        # 1 day.
        $ResetFailCountAfterSeconds = 24 * 60 * 60
    }

    Validate-WindowsServiceFailureAction $FirstFailureAction
    Validate-WindowsServiceFailureAction $SecondFailureAction
    Validate-WindowsServiceFailureAction $SubsequentFailuresAction

    $FirstFailureAction = Format-WindowsServiceFailureAction $FirstFailureAction $FirstRestartDelayMilliseconds
    $SecondFailureAction = Format-WindowsServiceFailureAction $SecondFailureAction $SecondRestartDelayMilliseconds
    $SubsequentFailuresAction = Format-WindowsServiceFailureAction $SubsequentFailuresAction $SubsequentRestartDelayMilliseconds

    $FailureActions = $FirstFailureAction
    if ($SecondFailureAction)
    {
        $FailureActions += "/$SecondFailureAction"
                
        if ($SubsequentFailuresAction)
        {
            $FailureActions += "/$SubsequentFailuresAction"
        }
    }

    Write-LogMessage "Service Name: '$Name'; Reset delay: $ResetFailCountAfterSeconds;"
    Write-LogMessage "Failure actions: '$FailureActions'"
    Write-LogMessage "First Failure Actions: $FirstFailureAction"
    Write-LogMessage "Second Failure Actions: $SecondFailureAction"
    Write-LogMessage "Subsequent Failures Actions: $SubsequentFailuresAction"
    Write-LogMessage "On Reboot Message: $OnFailureRebootMessage"
    Write-LogMessage "Run Command: $OnFailureRunCommand"
    Write-LogMessage "Command Parameters: $OnFailureCommandParameters"

    # Have to use sc.exe as Set-Service cmdlet does not provide any way of setting the 
    # recovery options. 
    # NOTES: 
    # 1) Must include the file extension, "sc.exe", because "sc" is an alias for Set-Content.
    # 2) Spaces are required after the "=" in "reset=", "actions=", etc, otherwise it won't 
    #    work.
    # 3) Formatting of the command is complicated, which is why it's been handed off to another 
    #    function.

    sc.exe failure $Name reset= $ResetFailCountAfterSeconds actions= $FailureActions

    if ($OnFailureRebootMessage)
    {
        sc.exe failure $Name reboot= $OnFailureRebootMessage
    }

    $OnFailureCommandline = Get-FailureCommand $OnFailureRunCommand $OnFailureCommandParameters
    if ($OnFailureCommandline)
    {
        sc.exe failure $Name command= $OnFailureCommandline
    }
    
    Write-LogMessage "Service '$Name' recovery options have been configured."
}

<#
.SYNOPSIS
Installs or re-installs a Windows service.

.DESCRIPTION
Checks whether a Windows service with the specified name exists and, if it 
does, stops and uninstalls it.  A new version will be installed.

.NOTES
#>
function Set-WindowsService (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,
    
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$ExecutableName,
    
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$TargetDirectoryPath,
    
    [Parameter(Mandatory=$False)]
    [string]$SourceDirectoryPath,
    
    [Parameter(Mandatory=$False)]
    [string]$DisplayName,
    
    [Parameter(Mandatory=$False)]
    [string]$Description,
    
    [Parameter(Mandatory=$False)]
    [string]$StartupType,
    
    [Parameter(Mandatory=$False)]
    [string]$LogOn,
    
    [Parameter(Mandatory=$False)]
    [string]$Password,
    
    [Parameter(Mandatory=$False)]
    [string]$FirstFailureAction,
    
    [Parameter(Mandatory=$False)]
    [int]$FirstRestartDelayMilliseconds,
    
    [Parameter(Mandatory=$False)]
    [string]$SecondFailureAction,
    
    [Parameter(Mandatory=$False)]
    [int]$SecondRestartDelayMilliseconds,
    
    [Parameter(Mandatory=$False)]
    [string]$SubsequentFailuresAction,
    
    [Parameter(Mandatory=$False)]
    [int]$SubsequentRestartDelayMilliseconds,

    [Parameter(Mandatory=$False)]
    [string]$OnFailureRebootMessage,

    [Parameter(Mandatory=$False)]
    [string]$OnFailureRunCommand,

    [Parameter(Mandatory=$False)]
    [string]$OnFailureCommandParameters,
    
    [Parameter(Mandatory=$False)]
    [int]$ResetFailCountAfterSeconds
    )
{
    Clear-Host 

    Write-LogMessage "Installing service '$Name'..."
    
    if ((!$SourceDirectoryPath -or !(Test-Path $SourceDirectoryPath)) `
    -and (!$TargetDirectoryPath -or !(Test-Path $TargetDirectoryPath)))
    {
        $errorMessage = "No directory specified for the service."
        throw $errorMessage
        return
    }
    
    if ($SourceDirectoryPath -and (Test-Path $SourceDirectoryPath))
    {
        $ExecutablePath = [io.path]::Combine($SourceDirectoryPath, $ExecutableName)
        if (!(Test-Path $ExecutablePath))
        {
            $errorMessage = "Could not find executable '$ExecutablePath'."
            throw $errorMessage
            return
        }
    }
    else 
    {
        $ExecutablePath = [io.path]::Combine($TargetDirectoryPath, $ExecutableName)
        if (!(Test-Path $ExecutablePath))
        {
            $errorMessage = "Could not find executable '$ExecutablePath'."
            throw $errorMessage
            return
        }
    }

    if (("Automatic", "Manual", "Disabled", "", $null) -notcontains $StartupType)
    {
        $errorMessage = "Invalid service start-up type '$StartupType': Startup type must be one of 'Automatic', 'Manual' or 'Disabled'."
        throw $errorMessage
        return
    }

    Uninstall-WindowsService $Name

    if ($SourceDirectoryPath -and (Test-Path $SourceDirectoryPath))
    {
        if (Test-Path $TargetDirectoryPath)
        {
            Write-LogMessage "Removing existing service directory '$TargetDirectoryPath'..."

            Remove-Item $TargetDirectoryPath -Force -Recurse

            Write-LogMessage "Existing service directory '$TargetDirectoryPath' removed."
        }

        Copy-Directory $SourceDirectoryPath $TargetDirectoryPath
    }

    $ExecutablePath = [io.path]::Combine($TargetDirectoryPath, $ExecutableName)

    if (!(Test-Path $ExecutablePath))
    {
        $errorMessage = "Could not find executable '$ExecutablePath'."
        throw $errorMessage
        return
    }

    $Credential = Get-WindowsServiceCredentials $LogOn $Password

    if (!$DisplayName)
    {
        $DisplayName = $Name
    }

    if (!$StartupType)
    {
        $StartupType = "Automatic"
    }

    Write-LogMessage "Creating service '$Name'..."

    # Need to cope with $Description, which may be empty or null.  
    #
    # If $Description is empty or null and is passed into the -Decription parameter 
    # New-Service will throw an error: 
    #    Cannot validate argument on parameter 'Description'. The argument is null or empty. 
    #    Provide an argument that is not null or empty, and then try the command again.
    #
    # This error can be avoided by leaving out -Description.  We could use an if-else as a 
    # work-around:
    #
    # if ($Description)
    # {
    #     New-Service -Name $Name -BinaryPathName $ExecutablePath `
    #         -Credential $Credential -DisplayName $DisplayName `
    #         -Description $Description -StartupType $StartupType
    # }
    # else
    # {
    #     New-Service -Name $Name -BinaryPathName $ExecutablePath `
    #         -Credential $Credential -DisplayName $DisplayName `
    #         -StartupType $StartupType
    # }

    # That soon gets unwieldy if there is more than one parameter that needs the same treatment.
    # Instead, use parameter splatting: 
    # https://msdn.microsoft.com/en-us/powershell/reference/5.0/microsoft.powershell.core/about/about_splatting

    $newServiceParams = @{
        Name = $Name
        BinaryPathName = $ExecutablePath
        Credential = $Credential
        DisplayName = $DisplayName
        StartupType = $StartupType
        }

    if ($Description) 
    {
        $newServiceParams.Description = $Description
    }

    # Note the use of the splatting operator, "@", rather than "$".
    New-Service @newServiceParams

    Write-LogMessage "Service '$Name' has been created."

    Set-WindowsServiceRecoveryOption $Name `
        $FirstFailureAction $FirstRestartDelayMilliseconds `
        $SecondFailureAction $SecondRestartDelayMilliseconds `
        $SubsequentFailuresAction $SubsequentRestartDelayMilliseconds `
        $OnFailureRebootMessage $OnFailureRunCommand $OnFailureCommandParameters `
        $ResetFailCountAfterSeconds

    Write-LogMessage "Starting service '$Name'..."

    Set-Service $Name -Status Running

    Write-LogMessage "Waiting 10 seconds to check service '$Name' status..."

    Start-Sleep -Seconds 10

    $serviceStatus = Get-Service -Name $Name

    if ($serviceStatus.Status -eq "Running")
    {
        Write-LogMessage "Service '$Name' is running."
        return
    }

    $errorMessage = "Service '$Name' is NOT running; service failed to start."
    throw $errorMessage
}

Set-WindowsService -Name $serviceName -ExecutableName $serviceExecutableName `
    -TargetDirectoryPath $serviceTargetDirectoryPath `
    -SourceDirectoryPath $serviceSourceDirectoryPath `
    -DisplayName $serviceDisplayName -Description $serviceDescription `
    -StartupType $serviceStartupType -LogOn $serviceLogOn -Password $servicePassword `
    -FirstFailureAction $serviceFirstFailureAction `
    -FirstRestartDelayMilliseconds $serviceFirstRestartDelayMilliseconds `
    -SecondFailureAction $serviceSecondFailureAction `
    -SecondRestartDelayMilliseconds $serviceSecondRestartDelayMilliseconds `
    -SubsequentFailuresAction $serviceSubsequentFailuresAction `
    -SubsequentRestartDelayMilliseconds $serviceSubsequentRestartDelayMilliseconds `
    -OnFailureRebootMessage $serviceOnFailureRebootMessage `
    -OnFailureRunCommand $serviceOnFailureRunCommand `
    -OnFailureCommandParameters $serviceOnFailureCommandParameters `
    -ResetFailCountAfterSeconds $serviceResetFailCountAfterSeconds