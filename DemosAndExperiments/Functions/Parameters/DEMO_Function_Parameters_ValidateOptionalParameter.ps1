<#
.SYNOPSIS
Demonstrates whether validation of optional parameter makes it mandatory or not.

.NOTES
Result: No error when -OptionalText argument is not supplied.  When it is supplied an error is 
thrown if the value is an empty string or $Null.

So validation of an optional parameter does not make it mandatory.
#>

function Write-Title(
    [string]$TitleText
    )
{
    Write-Host $TitleText
    Write-Host ('-' * $TitleText.Length)
}

function Get-DisplayText(
	[string]$Text    
    )
{
    if ($Text -eq $Null)
	{
		return "[NULL]"
	}
			
	if ($Text.Length -eq 0)
	{
		return "[EMPTY STRING]"
	}
	
	if ([string]::IsNullOrWhiteSpace($Text))
	{
		return "[WHITE SPACE]"
	}
	
	return "'$Text'"
}

function Test-Parameter(
	[Parameter(Mandatory=$True)]
	[string]$MandatoryText,

	[Parameter(Mandatory=$False)]
    [ValidateNotNullOrEmpty()]    
	[string]$OptionalText
	)
{	
    $mandatoryDisplayText = Get-DisplayText $MandatoryText
    $optionalDisplayText = Get-DisplayText $OptionalText
	Write-Host "Outcome for Mandatory text: $mandatoryDisplayText; Optional text: $optionalDisplayText : Executed without error."
}

function Test-ParameterWithErrorHandling(
	[string]$Text
	)
{	
    trap 
    {
        Write-Host "Error: $_" -ForegroundColor Red
        Write-Host
        Continue
    }

    $displayText = Get-DisplayText $Text
    Write-Title "Mandatory text $displayText and no optional text"
    Test-Parameter -MandatoryText $Text
    Write-Host

    $optionalTextList = @('world', '   ', '', $Null)
    foreach ($optionalText in $optionalTextList)
    {
        $optionalDisplayText = Get-DisplayText $optionalText
        Write-Title "Mandatory text $displayText and optional text $optionalDisplayText"
        Test-Parameter -MandatoryText $Text -OptionalText $optionalText
        Write-Host
    }
}

Clear-Host

Test-ParameterWithErrorHandling -Text $Null
Test-ParameterWithErrorHandling -Text ''
Test-ParameterWithErrorHandling -Text '   '
Test-ParameterWithErrorHandling -Text 'hello'