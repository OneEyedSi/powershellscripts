<#
.SYNOPSIS
Demonstrates how to set a default value on a function parameter.

.NOTES
Author:			Simon Elms
Requires:		* Windows PowerShell 5.1 or cross-platform PowerShell 6+
Version:		1.0.0 
Date:			19 Mar 2025
#>

function Write-Text(    
    # For the default value to work either explicitly state [Parameter(Mandatory=$False)] or don't specify Mandatory at all.
    # ie either leave out the [Parameter] attribute entirely or include it but don't specify Mandatory: [Parameter()]
    
    # If set Mandatory=$True, execution will pause and prompt the user to enter a value for Text when -Text is not set 
    # explicitly when calling the function.
    [Parameter(Mandatory=$False)]
    [string]$Text = 'Default text'
)
{
    Write-Host "    $Text"
}

# Result:
<#
Setting parameter value:
    Set explicitly
Defaulting parameter value:
    Default text
#>

Clear-Host

Write-Host 'Setting parameter value:'
Write-Text -Text 'Set explicitly'

Write-Host 'Defaulting parameter value:'
Write-Text