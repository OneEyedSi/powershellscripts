<#
.SYNOPSIS
Reads a value from each XML string in a list of XML strings, where the XML uses a specific namespace.

.DESCRIPTION

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
Version:		1.0.0 
Date:       29 Jul 2026

The trick is in the Get-XmlNamespaceManager function.  By default PowerShell returns the namespace manager 
as an array of its component parts, rather than as a single object.  Using the unary operator (leading comma) 
returns the namespace manager as a single object.

#>

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

$list = @(
  "<Event xmlns='http://schemas.microsoft.com/win/2004/08/events/event'><System><Provider Name='Microsoft-Windows-Security-Auditing' Guid='{54849625-5478-4994-a5ba-3e3b03
                 28c30d}'/><EventID>4634</EventID><Version>0</Version><Level>0</Level><Task>12545</Task><Opcode>0</Opcode><Keywords>0x8020000000000000</Keywords><TimeCreated 
                 SystemTime='2026-07-28T11:12:59.9968120Z'/><EventRecordID>20915097</EventRecordID><Correlation/><Execution ProcessID='1828' 
                 ThreadID='31812'/><Channel>Security</Channel><Computer>DC5CG3242VP3</Computer><Security/></System><EventData><Data 
                 Name='TargetUserSid'>S-1-12-1-1770105438-1105477862-3815276721-1928319504</Data><Data Name='TargetUserName'>simon.elms</Data><Data 
                 Name='TargetDomainName'>DATACOM-NZ</Data><Data Name='TargetLogonId'>0x7d90cc6</Data><Data Name='LogonType'>2</Data></EventData></Event>",

  "<Event xmlns='http://schemas.microsoft.com/win/2004/08/events/event'><System><Provider Name='Microsoft-Windows-Security-Auditing' Guid='{54849625-5478-4994-a5ba-3e3b03
                 28c30d}'/><EventID>4634</EventID><Version>0</Version><Level>0</Level><Task>12545</Task><Opcode>0</Opcode><Keywords>0x8020000000000000</Keywords><TimeCreated 
                 SystemTime='2026-07-28T11:12:59.9967327Z'/><EventRecordID>20915096</EventRecordID><Correlation/><Execution ProcessID='1828' 
                 ThreadID='432'/><Channel>Security</Channel><Computer>DC5CG3242VP3</Computer><Security/></System><EventData><Data 
                 Name='TargetUserSid'>S-1-12-1-1770105438-1105477862-3815276721-1928319504</Data><Data Name='TargetUserName'>simon.elms</Data><Data 
                 Name='TargetDomainName'>DATACOM-NZ</Data><Data Name='TargetLogonId'>0x7d90cf0</Data><Data Name='LogonType'>2</Data></EventData></Event>",

  "<Event xmlns='http://schemas.microsoft.com/win/2004/08/events/event'><System><Provider Name='Microsoft-Windows-Security-Auditing' Guid='{54849625-5478-4994-a5ba-3e3b03
                 28c30d}'/><EventID>4800</EventID><Version>0</Version><Level>0</Level><Task>12551</Task><Opcode>0</Opcode><Keywords>0x8020000000000000</Keywords><TimeCreated 
                 SystemTime='2026-07-28T11:12:52.2225430Z'/><EventRecordID>20915025</EventRecordID><Correlation ActivityID='{2aea6403-7de4-405a-9693-578768a60f31}'/><Execution 
                 ProcessID='1828' ThreadID='35696'/><Channel>Security</Channel><Computer>DC5CG3242VP3</Computer><Security/></System><EventData><Data 
                 Name='TargetUserSid'>S-1-12-1-1770105438-1105477862-3815276721-1928319504</Data><Data Name='TargetUserName'>simon.elms</Data><Data 
                 Name='TargetDomainName'>DATACOM-NZ</Data><Data Name='TargetLogonId'>0x179a06</Data><Data Name='SessionId'>1</Data></EventData></Event>"
)

Clear-Host

$firstXmlText = $list[0]
$xmlDoc = Get-XmlDoc $firstXmlText
$xmlNSMgr = Get-XmlNamespaceManager $xmlDoc

$targetUserName = $xmlDoc.SelectSingleNode('/ns:Event/ns:EventData/ns:Data[@Name="TargetUserName"]', $xmlNSMgr).InnerText
Write-Host "TargetUserName from first XML string: $targetUserName"

$list | 
Select-Object @{Name = 'XmlDoc'; Expression = { Get-XmlDoc $_ } } |
Select-Object XmlDoc, @{Name = 'XmlNSMgr'; Expression = { Get-XmlNamespaceManager $_.XmlDoc } } |
Select-Object `
  @{Name = 'TargetUserName'; Expression = { $_.XmlDoc.SelectSingleNode('/ns:Event/ns:EventData/ns:Data[@Name="TargetUserName"]', $_.XmlNSMgr).InnerText } }