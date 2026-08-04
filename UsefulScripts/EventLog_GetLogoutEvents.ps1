<#
.SYNOPSIS
Gets most recent lock screen, logout or shutdown events from the event logs.

.DESCRIPTION
Various Event IDs can represent "user has finished using the computer":
- 1074 (System event log): Planned shutdown (restart or power off)
- 4634 (Security event log): Account logon session terminated (session destroyed, closed or timed out)
- 4647 (Security event log): User initiated logoff
- 4800 (Security event log): The workstation was locked (manually or automatically due to inactivity)

We only want user-initiated events, not automated system events, for the specified user.  The user 
appears in different properties for different event IDs:
 - 1074: User appears in the "EventData.param7" property, in the form "<domain name>\<user name>"
 - Other event IDs: User appears in the "EventData.TargetUserName" property, in the form 
      "<user name>" (no domain).

In addition to a message, the shutdown event (ID 1074) also has a "Shutdown Type" property, which is in 
the "EventData.param5" property.  This is prepended to the Message property in the output, if found.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
Version:		4.0.0 
Date:       4 Aug 2026

#>

$numberOfEventsToReturn = 25
$userNameWithoutDomain = 'joe.bloggs'
$domainUserName = 'RANDOM\joe.bloggs'

$filterXml = @"
<QueryList>
  <Query Id="0" Path="System">
    <Select Path="System">
      *[System[(EventID=1074)]]
      and 
      *[EventData[Data[@Name='param7'] and (Data='$domainUserName')]]
    </Select>
  </Query>
  <Query Id="1" Path="Security">
    <Select Path="Security">
      *[System[(EventID=4634 or EventID=4647 or EventID=4800)]]
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
    $spacer = if ($Message.EndsWith(' ')) { '' } else { ' ' }
        
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
  $maxMessageLength = 50

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

function Get-XmlDoc([string]$XmlString)
{
  $xmlDoc = New-Object System.Xml.XmlDocument
  $xmlDoc.LoadXml($XmlString)
  return $xmlDoc
}

function Get-XmlNamespaceManager([System.Xml.XmlDocument]$XmlDoc)
{
  $xmlNamespaceManager = [System.Xml.XmlNamespaceManager]::new($XmlDoc.NameTable)
  $xmlNamespaceManager.AddNamespace('ns', 'http://schemas.microsoft.com/win/2004/08/events/event')
  # Use unary operator (leading comma) to return namespace manager as a single object instead of as 
  # an array of its component parts.
  return ,$xmlNamespaceManager
}

Clear-Host

Write-Message 'Configuration:'
Write-Message 'Number of events to return:' $numberOfEventsToReturn -IndentLevel 1
Write-Message 'For username: ' "$userNameWithoutDomain, $domainUserName" -IndentLevel 1
Write-Host
Write-Message 'Reading event logs...'
Write-Host

$results = Get-WinEvent -FilterXml $filterXml -MaxEvents $numberOfEventsToReturn | 
  Select-Object TimeCreated, Id, Message, @{Name = 'XmlDoc'; Expression = { Get-XmlDoc $_.ToXml() } } | 
  Select-Object TimeCreated, Id, Message, XmlDoc, @{Name = 'XmlNSMgr'; Expression = { Get-XmlNamespaceManager $_.XmlDoc } } | 
  Select-Object TimeCreated, Id, Message, `
    @{Name = 'ShutdownType'; Expression = { $_.XmlDoc.SelectSingleNode('/ns:Event/ns:EventData/ns:Data[@Name="param5"]', $_.XmlNSMgr).InnerText } } |
  Select-Object TimeCreated, Id, 
    @{Name = 'Message'; Expression = { if ($_.ShutdownType) { "Planned shutdown. Shutdown Type: $($_.ShutdownType)." } else { $_.Message } } } 
  
Write-Result $results