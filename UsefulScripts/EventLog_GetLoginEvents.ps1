<#
.SYNOPSIS
Gets most recent login events from the Security event log.

.DESCRIPTION
The login events are filtered so they only show login events for the specified user, not 
automated system login events.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
Version:		2.0.0 
Date:			  13 Sep 2023

#>

$numberOfEventsToReturn = 10
$userNameToCheck = 'JoeBloggs'

$computerToCheck = $env:COMPUTERNAME
$filterXml = @"
<QueryList>
  <Query Id="0" Path="Security">
    <Select Path="Security">
	*[System[(EventID=4624)]]
	and 
	*[EventData[Data[@Name='SubjectUserName'] and (Data='$computerToCheck')]]
	and 
	*[EventData[Data[@Name='TargetUserName'] and (Data='$userNameToCheck')]]
    </Select>
  </Query>
</QueryList>
"@

function Write-Message ([string]$Message, $Argument, [int]$IndentLevel)
{
    $hasArgument = ($Argument -ne $null)

    $NUMBER_INDENT_SPACES = 4
    $indentSpacer = ' ' * $NUMBER_INDENT_SPACES * $IndentLevel

    Write-Host -ForegroundColor Yellow "$indentSpacer$Message" -NoNewline:$hasArgument

    if ($hasArgument)
    {
        $spacer = if ($Message.EndsWith(' ')) { '' } else { ' '}
        
        Write-Host -ForegroundColor White "$spacer$Argument"
    }
}

Clear-Host

Write-Message 'Configuration:'
Write-Message 'Number of events to return:' $numberOfEventsToReturn -IndentLevel 1
Write-Message 'For username: ' $userNameToCheck -IndentLevel 1
Write-Message 'On computer: ' $computerToCheck -IndentLevel 1
Write-Host
Write-Message 'Reading event logs...'
Write-Host

Get-WinEvent -FilterXml $filterXml -MaxEvents $numberOfEventsToReturn