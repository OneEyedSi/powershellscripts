<#
.SYNOPSIS
Demonstrates how to get details of the caller of a function.

.DESCRIPTION
Demonstrates how to get details of the caller of a function.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1 or later 
				DEMO_CallerScriptAndFunction.ps1
Version:		1.0.0 
Date:			22 Oct 2023

Call from either the PowerShell console or from DEMO_CallerScriptAndFunction.ps1.

#>

$_constCallerConsole = '[CONSOLE]'
$_constCallerUnknown = '[UNKNOWN CALLER]'
$_constCallerFunctionUnknown = '----'
$_constCallerLineNumberUnknown = '[NONE]'

<#
.SYNOPSIS
Gets the details of the function or script calling into this module.

.DESCRIPTION
Gets the details of the function or script calling into this module.  It returns both the name 
of the calling function or script and the calling line number within that script.

When determining the caller, this function will skip any functions in this script, returning the 
details of the first function it encounters outside this script.  This allows other functions in 
this script to perform their own actions while being able to call down to this function to 
determine which external function or script called them.

This function walks up the call stack until it finds a stack frame where the ScriptName is not the 
filename of this module. 

.OUTPUTS
Hashtable.

The function outputs a hashtable with two keys:

	Name: The name of the first calling function encountered outside this script.  If this 
			function is called from the root of a script, outside of a function, the name will be 
			"Script <script file name>".  The script file name will be just the short file name, 
			without a path.  If this function is called from the PowerShell console the name will 
			be "[CONSOLE]".  If no caller is found outside this script the name will be "----".  
			If, for some reason, it's not possible to read the call stack the name will be 
			"[UNKNOWN CALLER]".
	LineNumber: The caller line number, if this function is called from a function or script.  If 
			this function is called from the PowerShell console, or if no caller is found outside 
			this script, or if it's not possible to read the call stack, the LineNumber will be 
			"[NONE]".

.NOTES
This function is NOT intended to be exported from this module.

#>
function Private_GetCallerInfo()
{
	$callStack = Get-PSCallStack
	if ($null -eq $callStack -or $callStack.Count -eq 0)
	{
		return $script:_constCallerUnknown
	}
	
    # Stack frame 0 is this function.  Increasing the index takes us further up the call stack, 
    # further away from this function.
	$thisFunctionStackFrame = $callStack[0]
	$thisModuleFileName = $thisFunctionStackFrame.ScriptName
	$stackFrameFileName = $thisModuleFileName
    $stackFrameLineNumber = $script:_constCallerLineNumberUnknown
    # Skip this function in the call stack as we've already read it.  There must be at least two 
    # stack frames in the call stack as something must call this function, so it's safe to skip 
    # the first stack frame.
	$i = 1
	$stackFrameFunctionName = $script:_constCallerFunctionUnknown
	while ($stackFrameFileName -eq $thisModuleFileName -and $i -lt $callStack.Count)
	{
		$stackFrame = $callStack[$i]
		$stackFrameFileName = $stackFrame.ScriptName
		$stackFrameFunctionName = $stackFrame.FunctionName
        $lineNumber = $stackFrame.ScriptLineNumber
        if (-not $lineNumber)
        {
            $stackFrameLineNumber = $script:_constCallerLineNumberUnknown
        }
        else 
        {
            $stackFrameLineNumber = "$lineNumber"
        }
		$i++
	}

    $callerInfo = @{}
	
	if ($null -eq $stackFrameFileName)
	{
        $callerInfo.Name = $script:_constCallerConsole
        $callerInfo.LineNumber = $script:_constCallerLineNumberUnknown
		return  $callerInfo
	}

    $callerInfo.Name = $stackFrameFunctionName
    $callerInfo.LineNumber = $stackFrameLineNumber

	if ($stackFrameFunctionName -eq '<ScriptBlock>')
	{
		$scriptFileNameWithoutPath = (Split-Path -Path $stackFrameFileName -Leaf)
        $callerInfo.Name = "Script $scriptFileNameWithoutPath"
	}
	
	return $callerInfo
}

function Write-CallerInfo ($CallerInfo)
{
    Write-Host "Caller Name: $($CallerInfo.Name)"
    Write-Host "Caller Line Number: $($CallerInfo.LineNumber)"
    Write-Host '---------------------'
}

function Write-CallerInfoIntermediate()
{
    $callerInfo = Private_GetCallerInfo
	Write-CallerInfo $callerInfo
}

