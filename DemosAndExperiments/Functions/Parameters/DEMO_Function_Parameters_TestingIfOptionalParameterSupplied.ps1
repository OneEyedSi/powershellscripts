<#
.SYNOPSIS
Demonstrates different methods of checking whether a function parameter has been supplied or not.
#>

function Write-Title ($TitleText)
{
    Write-Host
    Write-Host $TitleText
    Write-Host ("-" * $TitleText.Length)
}

function Write-DisplayText ($Text)
{
    if ($Text -eq $Null)
    {
        return '[NULL]'
    }

    if ($Text -eq '')
    {
        return '[EMPTY STRING]'
    }
    
    if ([string]::IsNullOrWhiteSpace($Text))
    {
        return '[BLANK STRING]'
    }

    return $Text
}

function Write-SomethingWithNullCheck (
	[string]$FirstParam,
	[string]$SecondParam
	)
{
	Write-Host "The first argument: '$FirstParam'"

    if ($SecondParam)
    {
        $displayText = Write-DisplayText $SecondParam
        Write-Host "The second argument: '$displayText'"
        return
    }

    Write-Host 'No second argument supplied'
}

function Write-SomethingWithBoundParamCheck (
	[string]$FirstParam,
	[string]$SecondParam
	)
{
	Write-Host "The first argument: '$FirstParam'"

    if ($PSBoundParameters.ContainsKey('SecondParam'))
    {
        $displayText = Write-DisplayText $SecondParam
        Write-Host "The second argument: '$displayText'"
        return
    }

    Write-Host 'No second argument supplied'
}

Clear-Host

# Result:
<#
Check for Nulls
---------------
The first argument: 'NUMERO UNO'
The second argument: 'Loser'
The first argument: 'NUMERO UNO'
No second argument supplied
The first argument: 'NUMERO UNO'
No second argument supplied
#>
Write-Title 'Check for Nulls'
Write-SomethingWithNullCheck -FirstParam 'NUMERO UNO' -SecondParam 'Loser'
Write-SomethingWithNullCheck -FirstParam 'NUMERO UNO' -SecondParam $Null
Write-SomethingWithNullCheck -FirstParam 'NUMERO UNO' 

# Result:
<#
Check $PSBoundParameters
------------------------
The first argument: 'NUMERO UNO'
The second argument: 'Loser'
The first argument: 'NUMERO UNO'
The second argument: '[EMPTY STRING]'
The first argument: 'NUMERO UNO'
No second argument supplied
#>
# WARNING: NOTE THAT THE FUNCTION SEES A $Null PASSED AS AN ARGUMENT AS AN EMPTY STRING.
# IF YOU WANT TO REALLY PASS A NULL STRING PASS [nullstring]::Value, NOT $Null.
Write-Title 'Check $PSBoundParameters'
Write-SomethingWithBoundParamCheck -FirstParam 'NUMERO UNO' -SecondParam 'Loser'
Write-SomethingWithBoundParamCheck -FirstParam 'NUMERO UNO' -SecondParam $Null
Write-SomethingWithBoundParamCheck -FirstParam 'NUMERO UNO'
