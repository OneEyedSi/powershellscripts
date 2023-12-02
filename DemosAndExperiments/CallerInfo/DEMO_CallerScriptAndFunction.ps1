<#
.SYNOPSIS
Demonstrates getting the details of a caller of a function.

.DESCRIPTION
Demonstrates getting the details of a caller of a function.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1 or later 
				DEMO_CallStack_GetCallerInfo.ps1
Version:		1.0.0 
Date:			22 Oct 2023

When calling Private_GetCallerInfo from the PowerShell console the $stackFrame has the following 
properties:
	ScriptName = $null
	FunctionName = '<ScriptBlock>'
	ScriptLineNumber = 1 

#>

. $PSScriptRoot\DEMO_CallStack_GetCallerInfo.ps1

function CallerFunction1()
{
    $callerInfo = Private_GetCallerInfo
	Write-CallerInfo $callerInfo
}

function CallerFunction2()
{
    Write-CallerInfoIntermediate
}

Clear-Host

# Caller is a function in this script, calling directly to the caller info function.
# Result:
<#
Caller Name: CallerFunction1
Caller Line Number: 21
#>
CallerFunction1

# Caller is a function in this script, calling a second function in DEMO_CallStack_GetCallerInfo.ps1 
# which calls the caller info function.
# Result:
<#
Caller Name: CallerFunction2
Caller Line Number: 27
#>
CallerFunction2

# Caller is a line in this script outside a function, calling directly to the caller info function.
# Result:
<#
Caller Name: Script DEMO_CallerScriptAndFunction.ps1
Caller Line Number: 55
#>
$callerInfo = Private_GetCallerInfo
Write-CallerInfo $callerInfo

# Caller is a line in this script outside a function, calling function in 
# DEMO_CallStack_GetCallerInfo.ps1 which calls the caller info function.
# Result:
<#
Caller Name: Script DEMO_CallerScriptAndFunction.ps1
Caller Line Number: 65
#>
Write-CallerInfoIntermediate

# Calling from PowerShell console directly into caller info function:

# Code called from PowerShell console after changing working directory to folder containing these 
# demo scripts:
<#
. .\DEMO_CallStack_GetCallerInfo.ps1
$callerInfo = Private_GetCallerInfo
Write-CallerInfo $callerInfo
#>

# Result:
<#
Caller Name: [CONSOLE]
Caller Line Number: [NONE]
#>

# Calling from PowerShell console to function in DEMO_CallStack_GetCallerInfo.ps1 which then calls 
# the caller info function:

# Code called from PowerShell console after changing working directory to folder containing these 
# demo scripts:
<#
. .\DEMO_CallStack_GetCallerInfo.ps1
Write-CallerInfoIntermediate
#>

# Result:
<#
Caller Name: [CONSOLE]
Caller Line Number: [NONE]
#>