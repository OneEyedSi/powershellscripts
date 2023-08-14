<#
.SYNOPSIS
Tests how to collect individual results from process blocks and display summary of results.

.DESCRIPTION
Tests how to collect individual results from process blocks and display summary of results.

.NOTES
#>

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
    [switch]$IsWarningMessage,

    [Parameter(Mandatory=$False)]
    [switch]$IsErrorMessage,

    [Parameter(Mandatory=$False)]
    [switch]$OverwriteLogFile
    )
{
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
    Write-LogMessage $ResultHeader -logFileName $LogFileName 

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

    Write-LogMessage $HorizontalLine -logFileName $LogFileName -writeRawMessageOnly

    Write-LogMessage $Message -consoleTextColor $MessageColor -logFileName $LogFileName `
        -writeRawMessageOnly

    Write-LogMessage $HorizontalLine -logFileName $LogFileName -writeRawMessageOnly
}

<#
.SYNOPSIS
Writes the keys and values of a hash table to the host.

.DESCRIPTION
Writes the keys and values of a hash table to the host.

.NOTES
#>
function Write-HashTable (
        [Parameter(Mandatory=$True)]
        $HashTable, 

        [Parameter(Mandatory=$True)]
        [string]$Title
    )
{
    Write-Host $Title
    foreach($Key in $HashTable.Keys)
    {
        $Value = $HashTable[$Key] 

        try
        {
            $Type = " (type $($Value.GetType().FullName))"
        }
        catch
        {
            $Type = ""
        }
               
        if ($Value -eq $Null)
        {
            $Value = "[NULL]"
        }
        elseif ($Value -is [string] -and $Value -eq "")
        {
            $Value = "[EMPTY STRING]"
        }
        elseif ($Value -is [string] -and $Value.Trim() -eq "")
        {
            $Value = "[BLANK STRING]"
        }

        Write-Host "[$Key] $Type : '$Value'"
    }
}

<#
.SYNOPSIS
Tests how to collect individual results from process blocks and display summary of results.

.DESCRIPTION
Tests how to collect individual results from process blocks and display summary of results.

.NOTES
#>
function Test-ConsolidatedResults
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
        $ListItem,

        [Parameter(Position=1)]
        [switch]$TotalFailure,

        [Parameter(Position=2)]
        [switch]$PartialFailure
    )

    begin
    {
        $ConsolidatedResults = @()
        Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"        
        Write-Host "BEGIN BLOCK:"
        Write-Host "Result summary: $ConsolidatedResults"
        # The following doesn't work.  It returns 0.
        Write-Host "Number of items: $($ListItem.Count)"
        Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    }

    process
    {
        $Result = @{Id=$ListItem; Success=$True; ErrorMessages=@()}
        if ($TotalFailure -or ($PartialFailure -and $ListItem % 2 -eq 1))
        {
            $Result.Success = $False
            for($i = 1; $i -le $ListItem; $i++)
            {
                $Result.ErrorMessages += "Error $i for item $ListItem"
            }
        }

        $ConsolidatedResults += $Result

        Write-Host "-------------------------------------"
        Write-Host "PROCESS BLOCK for input $($ListItem):"
        Write-HashTable $Result "Process result:"
        Write-Host "-------------------------------------"

        return $Result
    }

    end
    {
        Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"        
        Write-Host "END BLOCK:"
        # The following doesn't work.  It returns 1.
        Write-Host "Number of items: $($ListItem.Count)"
        Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

        $NL = [Environment]::NewLine
        $StatusValue = @{Failure=0; PartialFailure=1; Success=2}

        $NumberOfResults = $ConsolidatedResults.Count
        $NumberOfSuccessfulResults = $ConsolidatedResults.Where{$_.Success}.Count

        $ResultText = $Null
        $OverallResult = $StatusValue.Failure

        switch ($NumberOfSuccessfulResults)
        {
            0                   {
                                    $OverallResult = $StatusValue.Failure
                                }
            $NumberOfResults    {
                                    $OverallResult = $StatusValue.Success
                                }
            default             {
                                    $OverallResult = $StatusValue.PartialFailure
                                    $ItemsText = "items were"
                                    if ($NumberOfSuccessfulResults -eq 1)
                                    {
                                        $ItemsText = "item was"
                                    }
                                    $FailedIds = $ConsolidatedResults.Where{-not $_.Success}.ForEach("Id") -join ", "
                                    $ResultText = "Only $NumberOfSuccessfulResults " `
                                        + "$ItemsText operated on successfully out of " `
                                        + "$NumberOfResults.$NL" `
                                        + "Items that FAILED: $FailedIds." 
                                    break
                                }
        }

        Write-LogFooter -ScriptResult $OverallResult -ResultText $ResultText
    }
}

Clear-Host
$List = @(1, 2, 3, 4)

Write-Host
Write-Host "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
Write-Host "No errors:"

# Adding Format-Table ensures the three recordsets are displayed separately, instead of in one large 
# table.
$List | Test-ConsolidatedResults | Select-Object @{Name="Id"; Expression={$_.Id}}, `
                                    @{Name="Success"; Expression={$_.Success}}, `                                    
                                    @{Name="ErrorMessages"; Expression={$_.ErrorMessages}} `
                                 | Format-Table

Write-Host
Write-Host "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
Write-Host "Total failure:"

$List | Test-ConsolidatedResults -TotalFailure | Select-Object @{Name="Id"; Expression={$_.Id}}, `
                                                @{Name="Success"; Expression={$_.Success}}, `                                    
                                                @{Name="ErrorMessages"; Expression={$_.ErrorMessages}} `
                                 | Format-Table

Write-Host
Write-Host "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
Write-Host "Partial failure:"

$List | Test-ConsolidatedResults -PartialFailure | Select-Object @{Name="Id"; Expression={$_.Id}}, `
                                                    @{Name="Success"; Expression={$_.Success}}, `                                    
                                                    @{Name="ErrorMessages"; Expression={$_.ErrorMessages}} `
                                 | Format-Table