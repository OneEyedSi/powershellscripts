<#
.SYNOPSIS
Demonstrates how to use parameter sets.

.DESCRIPTION
Demonstrates how to use parameter sets to group parameters.  This allows a function to have 
multiple sets of mutually exclusive parameters, as well as common parameters that appear in all 
parameter sets and parameters that appear in multiple, but not all, parameter sets.

.NOTES
PowerShell ISE intellisense obviously reads parameter sets.  For example, when typing the call to 
function Write-Value, if you type "-TurnOff" (without the quotes) then -Brightness will be removed 
from the list of possible parameters since it can never appear in the same parameter set as 
-TurnOff.  Changing "-TurnOff" to "-TurnOn" will make -Brightness appear in the list once again.
#>

function Write-Value (
    [Parameter(Mandatory=$True, 
                ParameterSetName="Solo")]
    [ValidateNotNullOrEmpty()]
    [string]$SoloValue, 

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$CommonValue, 

    # Multiple Parameter attributes needed to add parameter to multiple parameter sets but not 
    # to every parameter set (will appear in parameter sets "On" and "Off" but not "Solo").
    [Parameter(Mandatory=$True, 
                ParameterSetName="On")]
    [Parameter(Mandatory=$True, 
                ParameterSetName="Off")]
    [ValidateNotNullOrEmpty()]
    [string]$ValueForSwitch, 

    [Parameter(Mandatory=$True, 
                ParameterSetName="On")]
    [switch]$TurnOn, 

    [Parameter(Mandatory=$True, 
                ParameterSetName="Off")]
    [switch]$TurnOff, 

    [Parameter(Mandatory=$False, 
                ParameterSetName="On")]
    [ValidateRange(1, 100)]
    [int]$Brightness
    )
{
    $switchPosition = "NOT SET"
    if ($TurnOn.IsPresent)
    {
        if ($TurnOff.IsPresent)
        {
            $switchPosition = "INVALID"
        }
        else
        {
            $switchPosition = "On"
        }
    }
    elseif ($TurnOff.IsPresent)
    {
        $switchPosition = "Off"
    }

    $brightnessText = "NOT SET"
    if ($Brightness -gt 0)
    {
        $brightnessText = "$Brightness"
    }

    Write-Host "Solo Value: '${SoloValue}'; Common Value: '${CommonValue}'"
    Write-Host "Value for switches: '${ValueForSwitch}'; Switch Position: ${switchPosition}; Brightness: $brightnessText"
    Write-Host "------------------------------------------------"
}

<#
.SYNOPSIS
Demonstrates that parameter sets can work with optional parameters, as long as one or other 
optional parameter is present to determine which parameter set to use.
#>
function Write-WithOptionalParamSets (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$CommonValue, 

    [Parameter(Mandatory=$False, 
                ParameterSetName="Set1")]
    [string]$ValueSet1, 

    [Parameter(Mandatory=$False, 
                ParameterSetName="Set2")]
    [string]$ValueSet2
    )
{
    Write-Host "Common Value: '${CommonValue}'; Value from param set 1: '${ValueSet1}'; Value from param set 2: '${ValueSet2}'"
    Write-Host "------------------------------------------------"
}

Clear-Host

# Result:
<#
Solo Value: 'We meet again, Mr Solo.'; Common Value: 'So common'
Value for switches: ''; Switch Position: NOT SET; Brightness: NOT SET
#>
Write-Value -SoloValue "We meet again, Mr Solo." -CommonValue "So common"

# Result:
<#
Solo Value: ''; Common Value: 'So common'
Value for switches: 'Switchy'; Switch Position: On; Brightness: NOT SET
#>
Write-Value -CommonValue "So common" -ValueForSwitch "Switchy" -TurnOn

# Result:
<#
Solo Value: ''; Common Value: 'So common'
Value for switches: 'Switchy'; Switch Position: On; Brightness: 45
#>
Write-Value -CommonValue "So common" -ValueForSwitch "Switchy" -TurnOn -Brightness 45

# Result:
<#
Solo Value: ''; Common Value: 'So common'
Value for switches: 'Switchy'; Switch Position: Off; Brightness: NOT SET
#>
Write-Value -CommonValue "So common" -ValueForSwitch "Switchy" -TurnOff

# Throws exception because only one switch parameter may be present:
<#
Write-Value : Parameter set cannot be resolved using the specified named parameters.
At C:\Users\simone\Documents\SimonsDocuments\IT\PowerShell\DemosAndExperiments\Functions\DEMO_Function_ParameterSets.ps1:111 char:1
+ Write-Value -CommonValue "So common" -ValueForSwitch "Switchy" -TurnO ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidArgument: (:) [Write-Value], ParameterBindingException
    + FullyQualifiedErrorId : AmbiguousParameterSet,Write-Value
#>
Write-Value -CommonValue "So common" -ValueForSwitch "Switchy" -TurnOn -TurnOff

# Throws exception because one or the other switch parameter must be present:
<#
Write-Value : Parameter set cannot be resolved using the specified named parameters.
At C:\Users\simone\Documents\SimonsDocuments\IT\PowerShell\DemosAndExperiments\Functions\DEMO_Function_ParameterSets.ps1:122 char:1
+ Write-Value -CommonValue "So common" -ValueForSwitch "Switchy"
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidArgument: (:) [Write-Value], ParameterBindingException
    + FullyQualifiedErrorId : AmbiguousParameterSet,Write-Value
#>
Write-Value -CommonValue "So common" -ValueForSwitch "Switchy"

# Throws exception because switch parameter should not be present:
<#
Write-Value : Parameter set cannot be resolved using the specified named parameters.
At C:\Users\simone\Documents\SimonsDocuments\IT\PowerShell\DemosAndExperiments\Functions\DEMO_Function_ParameterSets.ps1:133 char:1
+ Write-Value -SoloValue "We meet again, Mr Solo." -CommonValue "So com ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidArgument: (:) [Write-Value], ParameterBindingException
    + FullyQualifiedErrorId : AmbiguousParameterSet,Write-Value
#>
Write-Value -SoloValue "We meet again, Mr Solo." -CommonValue "So common" -TurnOn

# Prompts user to enter CommonValue parameter as it must be present:
Write-Value -SoloValue "We meet again, Mr Solo." 

# Throws exception because one or the other optional parameter must be present to determine which parameter set to use:
<#
Write-WithOptionalParamSets : Parameter set cannot be resolved using the specified named parameters.
At C:\Users\SimonE\Documents\SimonsDocuments\IT\PowerShell\DemosAndExperiments\Functions\DEMO_Function_ParameterSets.ps1:167 char:1
+ Write-WithOptionalParamSets -CommonValue 'So common'
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidArgument: (:) [Write-WithOptionalParamSets], ParameterBindingException
    + FullyQualifiedErrorId : AmbiguousParameterSet,Write-WithOptionalParamSets
#>
Write-WithOptionalParamSets -CommonValue 'So common'

# Result:
<#
Common Value: 'So common'; Value from param set 1: 'Set 1'; Value from param set 2: ''
#>
Write-WithOptionalParamSets -CommonValue 'So common' -ValueSet1 'Set 1'

# Result:
<#
Common Value: 'So common'; Value from param set 1: ''; Value from param set 2: 'Set 2'
#>
Write-WithOptionalParamSets -CommonValue 'So common' -ValueSet2 'Set 2'