<#
.SYNOPSIS
Gets most recent unlock screen and login events from the Security event log.

.DESCRIPTION
The event IDs captured are:
- 4624 (Security event log): Account logon session created (user logged in)
- 4801 (Security event log): The workstation was unlocked

We only want user-initiated events, not automated system events, for the specified user.  For both 
event IDs captured, the user appears in the "EventData.TargetUserName" property.  The format is 
different for the two event IDs:
- 4624: "<user name>@<domain name>"
- 4801: "<user name>" (no domain)

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
Version:		4.0.0 
Date:       4 Aug 2026

#>

$numberOfEventsToReturn = 25
$userNameWithoutDomain = 'joe.bloggs'
$userEmail = 'joe.bloggs@random.com'

$filterXml = @"
<QueryList>
  <Query Id="0" Path="Security">
    <Select Path="Security">
	    *[System[(EventID=4624)]]
      and 
      *[EventData[Data[@Name='TargetUserName'] and (Data='$userEmail')]]
    </Select>
  </Query>
  <Query Id="1" Path="Security">
    <Select Path="Security">
	    *[System[(EventID=4801)]]
      and 
      *[EventData[Data[@Name='TargetUserName'] and (Data='$userNameWithoutDomain')]]
    </Select>
  </Query>
</QueryList>
"@

function Write-Message ([string]$Message, $Argument, [int]$IndentLevel)
{
    $hasArgument = ($null -ne $Argument)

    $NUMBER_INDENT_SPACES = 4
    $indentSpacer = ' ' * $NUMBER_INDENT_SPACES * $IndentLevel

    Write-Host -ForegroundColor Yellow "$indentSpacer$Message" -NoNewline:$hasArgument

    if ($hasArgument)
    {
        $spacer = if ($Message.EndsWith(' ')) { '' } else { ' '}
        
        Write-Host -ForegroundColor White "$spacer$Argument"
    }
}

function Write-Result($Results)
{
  if (-not $Results)
  {
    Write-Host -ForegroundColor Yellow 'No events found.'
    return
  }

  $mostRecentResult = $Results | Select-Object -First 1
  $latestDate = $mostRecentResult.TimeCreated.Date

  $formatString = '{0,-19}  {1,-4}  {2}'
  $dateFormat = 'yyyy-MM-dd HH:mm:ss'
  $maxMessageLength = 40

  Write-Host ($formatString -f 'TimeCreated', 'ID', 'Message')
  Write-Host ($formatString -f '-----------', '--', '-------')

  foreach ($result in $Results)
  {
    $resultDate = $result.TimeCreated.Date
    $colourIndex = ($latestDate - $resultDate).Days % 2
    $colour = if ($colourIndex -eq 0) { 'White' } else { 'Cyan' }

    $formattedTime = $result.TimeCreated.ToString($dateFormat)

    $messageLines = $result.Message -split '\r?\n'
    $firstLine = $messageLines[0]
    $messageToDisplay = $firstLine
    if ($firstLine.Length -gt $maxMessageLength) 
    { 
      $messageToDisplay = $firstLine.Substring(0, $maxMessageLength) + '...' 
    }

    Write-Host ($formatString -f $formattedTime, $result.Id, $messageToDisplay) -ForegroundColor $colour
  }
}

Clear-Host

Write-Message 'Configuration:'
Write-Message 'Number of events to return:' $numberOfEventsToReturn -IndentLevel 1
Write-Message 'For username: ' "$userNameWithoutDomain, $userEmail" -IndentLevel 1
Write-Host
Write-Message 'Reading event logs...'
Write-Host

$results = Get-WinEvent -FilterXml $filterXml -MaxEvents $numberOfEventsToReturn | 
  Select-Object TimeCreated, Id, Message

Write-Result $results