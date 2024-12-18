<#
.SYNOPSIS
Demonstrates passing a value to a pipeline function explicitly, rather than via the pipeline.

.DESCRIPTION

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
Version:		1.0.0 
Date:			15 Dec 2024

RESULTS:

From pipeline:
    Value: one
    Value: two
    Value: three
Explicitly specify the value:
    Value: Explicit value

#>

function Write-Value (
    [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
    [string]$Value
)
{
    process
    {
        Write-Host "    Value: $Value"
    }
}

Clear-Host

Write-Host 'From pipeline:'
@('one', 'two', 'three') | Write-Value

Write-Host 'Explicitly specify the value:'
Write-Value -Value 'Explicit value'