<#
.SYNOPSIS
Demonstrates how to deal with $Null and empty strings.

.NOTES
By default PowerShell coerces $Nulls to be empty strings when assigning them to variables.

Apparently the [nullstring]::Value static property represents a null string.

From the below tests we can see that passing a [nullstring]::Value to a string parameter will 
still coerce it into an empty string.

The only way to distinguish between $Nulls and empty strings is to not specify a data type 
for a parameter.  Then the parameter variable within the function will have different values when 
$Null and empty string are passed to it.
#>

function Get-DisplayText (
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

function Write-Title (
    [string]$title
    )
{
    Write-Host $title
    Write-Host ('-' * $title.Length)
}

function Test-StringWithDataType (
    [string]$String,
    [string]$title
    )
{
    Write-Title $title

    if ($String -eq $Null)
    {
        Write-Host 'String equals $Null'
    }
    elseif ($String -eq '')
    {
        Write-Host 'String equals [EMPTY STRING]'
    }
    else
    {
        Write-Host 'String does not equal either $Null or [EMPTY STIRNG]'
    }

    Write-Host
}

function Test-StringWithoutDataType (
    $String,  # Note we're not setting a data type
    [string]$title
    )
{
    Write-Title $title

    if ($String -eq $Null)
    {
        Write-Host 'String equals $Null'
    }
    elseif ($String -eq '')
    {
        Write-Host 'String equals [EMPTY STRING]'
    }
    else
    {
        Write-Host 'String does not equal either $Null or [EMPTY STIRNG]'
    }

    Write-Host
}

Clear-Host

$nullString = [nullstring]::Value

Write-Host
Write-Host 'Parameter with data type'
Write-Host '========================'
Write-Host

Test-StringWithDataType $Null 'NULL string'                   # String equals [EMPTY STRING]
Test-StringWithDataType '' 'EMPTY string'                     # String equals [EMPTY STRING]
Test-StringWithDataType '    ' 'BLANK string'                 # String does not equal either $Null or [EMPTY STIRNG]
Test-StringWithDataType 'Hello world' 'Non-blank string'      # String does not equal either $Null or [EMPTY STIRNG]
Test-StringWithDataType $nullString 'NullString'              # String equals [EMPTY STRING]

Write-Host
Write-Host ('-' * 80)

Write-Host
Write-Host 'Parameter without data type'
Write-Host '==========================='
Write-Host

Test-StringWithoutDataType $Null 'NULL string'                  # String equals $Null
Test-StringWithoutDataType '' 'EMPTY string'                    # String equals [EMPTY STRING]
Test-StringWithoutDataType '    ' 'BLANK string'                # String does not equal either $Null or [EMPTY STIRNG]
Test-StringWithoutDataType 'Hello world' 'Non-blank string'     # String does not equal either $Null or [EMPTY STIRNG]
Test-StringWithoutDataType $nullString 'NullString'             # String does not equal either $Null or [EMPTY STIRNG]
