<#
.SYNOPSIS
Demonstrates how to use a function to validate multiple parameters simultaneously.

.NOTES
In this simple case it would be easier to use Parameter attributes with ParameterSetName property 
set to force the $TurnOn and $TurnOff parameters to be in mutually exclusive parameter sets.  
$Message should not have a ParameterSetName so that it will appear in both parameter sets.
A CmdletBinding attribute should be used to set a default parameter set name for the case where 
only the $Message parameter is supplied.
#>

function Test-SwitchParameterGroup()
{
	# Can't use "if ($Args.Count -gt 1)..." because it will always be true, even if $TurnOn and 
	# $TurnOff are not set when calling Write-Something.  If one of the switch parameters is not 
	# set it will still be passed to this function but with value $False.	
	# Could use ".Where{$_}" but ".Where{$_ -eq $True}" is easier to understand.
	if ($Args.Where{$_ -eq $True}.Count -gt 1)
	{
		throw [System.ArgumentException] "Only one switch parameter may be set when calling the function."
	}
}

function Write-Something (
	[Parameter(Mandatory=$True)]
	[string]$Message, 
	
	[switch]$TurnOn, 
	[switch]$TurnOff
	)
{
	Test-SwitchParameterGroup $TurnOn $TurnOff
	
	Write-Host "Zero or one switch parameter set.  This is the message: '$Message'"
}

function Test-SwitchParameterGroup2 
	(
	[switch[]]$SwitchList,
	[string]$ErrorMessage
	)
{
	# Similar to Test-SwitchParameterGroup but allows the calling function to specify the 
	# error message.
	
	# Can't use "if ($SwitchList.Count -gt 1)..." because it will always be true, even if no 
	# switches are set when calling Write-Something2.  If one of the switch parameters is not 
	# set it will still be passed to this function but with value $False.	
	# Could use ".Where{$_}" but ".Where{$_ -eq $True}" is easier to understand.
	if ($SwitchList.Where{$_ -eq $True}.Count -gt 1)
	{
		throw [System.ArgumentException] $ErrorMessage
	}
}

function Write-Something2 (
	[Parameter(Mandatory=$True)]
	[string]$Message, 
	
	[switch]$TurnOn, 
	[switch]$TurnOff
	)
{
	Test-SwitchParameterGroup2 -SwitchList $TurnOn,$TurnOff `
		-ErrorMessage "Only one switch parameter may be set when calling the function."		
	
	Write-Host "Zero or one switch parameter set.  This is the message: '$Message'"
}

Clear-Host
# Result: Zero or one switch parameter set.  This is the message: 'No switch parameters set.'
Write-Something "No switch parameters set."

# Result: Zero or one switch parameter set.  This is the message: '-TurnOn parameter set.'
Write-Something "-TurnOn parameter set." -TurnOn

# Result: Zero or one switch parameter set.  This is the message: '-TurnOff parameter set.'
Write-Something "-TurnOff parameter set." -TurnOff

# Result: Error:
#	Only one switch parameter may be set when calling the function.
#	At C:\Users\simone\Documents\SimonsDocuments\IT\PowerShell\DemosAndExperiments\Functions\DEMO_Function_Parameters_ValidateMultipleParametersTogether.ps1:line:15 char:3
#	+ 		throw New-Object -TypeName System.ArgumentException -ArgumentList "Only one switch parameter may be set when calling the function."
#Write-Something "Both switch parameters set." -TurnOn -TurnOff

Write-Host "-----------------------------------------"

# Result: Zero or one switch parameter set.  This is the message: 'No switch parameters set.'
Write-Something2 "No switch parameters set."

# Result: Zero or one switch parameter set.  This is the message: '-TurnOn parameter set.'
Write-Something2 "-TurnOn parameter set." -TurnOn

# Result: Zero or one switch parameter set.  This is the message: '-TurnOff parameter set.'
Write-Something2 "-TurnOff parameter set." -TurnOff

# Result: Error:
#	Only one switch parameter may be set when calling the function.
#	At
#	C:\Users\simone\Documents\SimonsDocuments\IT\PowerShell\DemosAndExperiments\Functions\DEMO_Function_Parameters_ValidateMultipleParametersTogether.ps1:50
#	char:3
#	+         throw [System.ArgumentException] $ErrorMessage
#	+         ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#		+ CategoryInfo          : OperationStopped: (:) [], ArgumentException
#   + FullyQualifiedErrorId : Only one switch parameter may be set when calling the function.
Write-Something2 "Both switch parameters set." -TurnOn -TurnOff