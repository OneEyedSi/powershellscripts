<#
.SYNOPSIS
Gets most recent logout events from the event logs.

.DESCRIPTION
There doesn't appear to be an event that can reliably represent a logout. Event IDs 1074, 6006 
4800 and 7002 only seem to work for some logouts. 4634 seems the best bet. 

Taking a scatter-gun approach we'll try all of the above event IDs and format the results in 
a single table.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
Version:		2.0.0 
Date:			20 Aug 2021

#>

$numberOfEventsToReturn = 20
$userNameToCheck = 'JoeBloggs'

$filterXml = @"
<QueryList>
  <Query Id="0" Path="System">
    <Select Path="System">
    *[System[(EventID=1074)]]
    or
    *[System[(EventID=6006)]]
    or
    *[System[(EventID=7002)]]
    </Select>
  </Query>
  <Query Id="0" Path="Security">
    <Select Path="Security">
    *[System[(EventID=4634)]]
	and 
	*[EventData[Data[@Name='TargetUserName'] and (Data='$userNameToCheck')]]
    or    
    *[System[(EventID=4800)]]
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
Write-Host
Write-Message 'Reading event logs...'
Write-Host

Get-WinEvent -FilterXml $filterXml -MaxEvents $numberOfEventsToReturn | 
    Select-Object TimeCreated, Id, LogName, Message | 
    Format-Table 