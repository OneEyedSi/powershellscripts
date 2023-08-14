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

function Private_GetColorDisplayText(
	[Parameter(Mandatory=$True)]
	[AllowNull()]
	[AllowEmptyString()]
	[string]$Color
	)
{	
	if ($Color -eq $Null)
	{
		return "[NULL]"
	}
			
	if ($Color.Length -eq 0)
	{
		return "[EMPTY STRING]"
	}
	
	if ([string]::IsNullOrWhiteSpace($Color))
	{
		return "[WHITE SPACE]"
	}
	
	return $Color
}

<#
.SYNOPSIS
Function called by ValidateScript to check if the specified colour name parameter is valid.

.DESCRIPTION
As per the documentation for ValidateScript the function returns $True if the colour name is 
valid, and $False if it is not.

.NOTES        
Allows multiple parameters to be validated in a single place, so the validation code does not 
have to be repeated for each parameter.    
#>
function Private_ValidateHostColor(
	[Parameter(Mandatory=$True)]
	[AllowNull()]
	[string]$ColorToTest
	)
{	
	$validColors = @("Black", "DarkBlue", "DarkGreen", "DarkCyan", "DarkRed", "DarkMagenta", 
            "DarkYellow", "Gray", "DarkGray", "Blue", "Green", "Cyan", "Red", "Magenta", 
            "Yellow", "White")
	
	if ($validColors -contains $ColorToTest)
	{
		return $True
	}
			
	return $False
}

<#
.SYNOPSIS
Function that uses ValidateScript to call another function to validate a parameter value.

.DESCRIPTION
If the specified parameter is not valid the validation function returns $False.  PowerShell will 
then throw a standard validation exception which does not describe why the validation failed.

.NOTES 
#>
function Write-Something (
	[Parameter(Mandatory=$True)]
	[string]$Message, 
	
	[Parameter(Mandatory=$False)]
	[ValidateScript({Private_ValidateHostColor $_})]
	[string]$FirstColor, 
	
	[Parameter(Mandatory=$False)]
	[ValidateScript({Private_ValidateHostColor $_})]
	[string]$SecondColor
	)
{	
	$FirstColorDisplayText = Private_GetColorDisplayText $FirstColor
	$SecondColorDisplayText = Private_GetColorDisplayText $SecondColor
	Write-Host "Message: '$Message'; FirstColor: $FirstColorDisplayText; SecondColor: $SecondColorDisplayText"
}

<#
.SYNOPSIS
Function called by ValidateScript to check if the specified host colour name is valid when 
passed as a parameter.

.DESCRIPTION
If the specified colour name is not valid this function throws an exception rather than returns 
$False.

.NOTES        
Allows multiple parameters to be validated in a single place, so the validation code does not 
have to be repeated for each parameter.  

Throwing an exception when the colour name is invalid allows us to specify a custom error message. 
If we simply returned $False it would generate a standard error message that does not indicate 
why the validation failed.
#>
function Private_ValidateHostColor2 (
	[Parameter(Mandatory=$True)]
	[AllowNull()]
	[string]$ColorToTest
	)
{	
	$validColors = @("Black", "DarkBlue", "DarkGreen", "DarkCyan", "DarkRed", "DarkMagenta", 
            "DarkYellow", "Gray", "DarkGray", "Blue", "Green", "Cyan", "Red", "Magenta", 
            "Yellow", "White")
	
	if ($validColors -notcontains $ColorToTest)
	{
		throw [System.ArgumentException] "INVALID TEXT COLOR ERROR: '$ColorToTest' is not a valid text color for the PowerShell host."
	}
			
	return $True
}

<#
.SYNOPSIS
Function that uses ValidateScript to call another function to validate a parameter value.

.DESCRIPTION
If the specified parameter is not valid the validation function throws an exception which will 
display a custom error message.

.NOTES        
If the validation function simply returned $False it would generate a standard error message that 
does not indicate why the validation failed.
#>
function Write-Something2 (
	[Parameter(Mandatory=$True)]
	[string]$Message, 
	
	[Parameter(Mandatory=$False)]
	[ValidateScript({Private_ValidateHostColor2 $_})]
	[string]$FirstColor, 
	
	[Parameter(Mandatory=$False)]
	[ValidateScript({Private_ValidateHostColor2 $_})]
	[string]$SecondColor
	)
{	
	$FirstColorDisplayText = Private_GetColorDisplayText $FirstColor
	$SecondColorDisplayText = Private_GetColorDisplayText $SecondColor
	Write-Host "Message: '$Message'; FirstColor: $FirstColorDisplayText; SecondColor: $SecondColorDisplayText"
}

Clear-Host

# Result: Message: 'No colours.'; FirstColor: [EMPTY STRING]; SecondColor: [EMPTY STRING]
Write-Something "No colours."

# Result: Message: 'Valid first colour, no second colour.'; FirstColor: Red; SecondColor: [EMPTY STRING]
Write-Something "Valid first colour, no second colour." -FirstColor "Red"

# Result: Error: 
<#
Write-Something : Cannot validate argument on parameter 'FirstColor'. The "Private_ValidateHostColor $_" validation script
for the argument with value "Wot" did not return a result of True. Determine why the validation script failed, and then try
the command again.
At C:\Users\simone\Documents\SimonsDocuments\IT\PowerShell\DemosAndExperiments\Functions\DEMO_Function_Parameters_ValidateScri
pt_ViaFunction.ps1:88 char:71
+ ... Something "Invalid first colour, no second colour." -FirstColor "Wot"
+                                                                     ~~~~~
    + CategoryInfo          : InvalidData: (:) [Write-Something], ParameterBindingValidationException
    + FullyQualifiedErrorId : ParameterArgumentValidationError,Write-Something
#>
Write-Something "Invalid first colour, no second colour." -FirstColor "Wot"

# Result: Message: 'Valid both colours.'; FirstColor: Red; SecondColor: Blue
Write-Something "Valid both colours." -FirstColor "Red" -SecondColor "Blue"

# Result: Error (but only one): 
<#
Write-Something : Cannot validate argument on parameter 'FirstColor'. The "Private_ValidateHostColor $_" validation script
for the argument with value "Wot" did not return a result of True. Determine why the validation script failed, and then try
the command again.
At C:\Users\simone\Documents\SimonsDocuments\IT\PowerShell\DemosAndExperiments\Functions\DEMO_Function_Parameters_ValidateScri
pt_ViaFunction.ps1:146 char:53
+ Write-Something "Invalid both colours." -FirstColor "Wot" -SecondColo ...
+                                                     ~~~~~
    + CategoryInfo          : InvalidData: (:) [Write-Something], ParameterBindingValidationException
    + FullyQualifiedErrorId : ParameterArgumentValidationError,Write-Something
#>
Write-Something "Invalid both colours." -FirstColor "Wot" -SecondColor "eva"

# Result: Error: 
<#
Write-Something : Cannot validate argument on parameter 'SecondColor'. The "Private_ValidateHostColor $_" validation script
for the argument with value "Wot" did not return a result of True. Determine why the validation script failed, and then try
the command again.
At C:\Users\simone\Documents\SimonsDocuments\IT\PowerShell\DemosAndExperiments\Functions\DEMO_Function_Parameters_ValidateScri
pt_ViaFunction.ps1:161 char:86
+ ... d first colour, invalid second." -FirstColor "Red" -SecondColor "Wot"
+                                                                     ~~~~~
    + CategoryInfo          : InvalidData: (:) [Write-Something], ParameterBindingValidationException
    + FullyQualifiedErrorId : ParameterArgumentValidationError,Write-Something
#>
Write-Something "Valid first colour, invalid second." -FirstColor "Red" -SecondColor "Wot"

# Result: Message: 'No colours.'; FirstColor: [EMPTY STRING]; SecondColor: [EMPTY STRING]
Write-Something2 "No colours."

# Result: Message: 'Valid first colour, no second colour.'; FirstColor: Red; SecondColor: [EMPTY STRING]
Write-Something2 "Valid first colour, no second colour." -FirstColor "Red"

# Result: Error: 
<#
Write-Something2 : Cannot validate argument on parameter 'FirstColor'. INVALID TEXT COLOR ERROR: 'Wot' is not a valid text
color for the PowerShell host.
At C:\Users\simone\Documents\SimonsDocuments\IT\PowerShell\DemosAndExperiments\Functions\DEMO_Function_Parameters_ValidateScri
pt_ViaFunction.ps1:147 char:72
+ ... omething2 "Invalid first colour, no second colour." -FirstColor "Wot"
+                                                                     ~~~~~
    + CategoryInfo          : InvalidData: (:) [Write-Something2], ParameterBindingValidationException
    + FullyQualifiedErrorId : ParameterArgumentValidationError,Write-Something2
#>
Write-Something2 "Invalid first colour, no second colour." -FirstColor "Wot"

# Result: Message: 'Valid both colours.'; FirstColor: Red; SecondColor: Blue
Write-Something2 "Valid both colours." -FirstColor "Red" -SecondColor "Blue"

# Result: Error (but only one): 
<#
Write-Something2 : Cannot validate argument on parameter 'FirstColor'. INVALID TEXT COLOR ERROR: 'Wot' is not a valid text
color for the PowerShell host.
At C:\Users\simone\Documents\SimonsDocuments\IT\PowerShell\DemosAndExperiments\Functions\DEMO_Function_Parameters_ValidateScri
pt_ViaFunction.ps1:181 char:54
+ Write-Something2 "Invalid both colours." -FirstColor "Wot" -SecondCol ...
+                                                      ~~~~~
    + CategoryInfo          : InvalidData: (:) [Write-Something2], ParameterBindingValidationException
    + FullyQualifiedErrorId : ParameterArgumentValidationError,Write-Something2
#>
Write-Something2 "Invalid both colours." -FirstColor "Wot" -SecondColor "eva"

# Result: Error: 
<#
Write-Something : Cannot validate argument on parameter 'SecondColor'. The "Private_ValidateHostColor $_" validation script
for the argument with value "Wot" did not return a result of True. Determine why the validation script failed, and then try
the command again.
At C:\Users\simone\Documents\SimonsDocuments\IT\PowerShell\DemosAndExperiments\Functions\DEMO_Function_Parameters_ValidateScri
pt_ViaFunction.ps1:210 char:86
+ ... d first colour, invalid second." -FirstColor "Red" -SecondColor "Wot"
+                                                                     ~~~~~
    + CategoryInfo          : InvalidData: (:) [Write-Something], ParameterBindingValidationException
    + FullyQualifiedErrorId : ParameterArgumentValidationError,Write-Something
#>
Write-Something "Valid first colour, invalid second." -FirstColor "Red" -SecondColor "Wot"