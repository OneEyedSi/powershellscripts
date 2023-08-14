$scriptBlock = {
    param($TextToWrite)
    Write-Host $TextToWrite
}

function FunctionWithParameter ($TextToWrite)
{ 
    Write-Host $TextToWrite 
}

function FunctionWithTwoParameters ($Text1, $Text2)
{ 
    Write-Host "${Text1}: $Text2"
}

Function Apply([scriptblock] $s)    
{ 
    $s.Invoke("Hello")
}

function ApplyWithParameters([scriptblock] $s, $arguments)
{
    Invoke-Command -ScriptBlock $s -ArgumentList $arguments
}

function Divide ($numerator, $denominator)
{
    Write-Host "$($numerator/$denominator)"
}

function Sum ($first, $second, $third)
{
    Write-Host "$($first + $second + $third)"
}

function NoArgs 
{
    Write-Host "No arguments"
}

function WrapInTryCatch([scriptblock] $function, $arguments)
{
    try
    {
        Invoke-Command -ScriptBlock $function -ArgumentList $arguments
    }
    catch
    {
        Write-Host "$($_.Exception.GetType().Name): $($_.Exception.Message)"
    }
}

Clear-Host

#Apply { FunctionWithParameter }
#Apply FunctionWithParameter

# Works.
Apply $scriptBlock

# The following would throw an error: 
#   "Cannot process argument transformation on parameter 's'. Cannot convert the "FunctionWithParameter" value of type "System.String" to type 
#   "System.Management.Automation.ScriptBlock"."
# This is because it executes the FunctionWithParameter function first then tries to pass the result to the Apply function.
# Apply FunctionWithParameter

# Doesn't throw an error but no argument is passed into FunctionWithParameter.
Apply { FunctionWithParameter }

# Works: Argument is passed into FunctionWithParameter.
# TRAP FOR YOUNG PLAYERS: There cannot be any leading or trailing spaces between the braces and the function, eg 
# Apply ${ function:FunctionWithParameter }
#         ^                              ^
#         ^                              ^
#   If there are leading and/or trailing spaces the following error is thrown:
#       "You cannot call a method on a null-valued expression."
Apply ${function:FunctionWithParameter}

# Also works.
[scriptblock]$f = ${function:FunctionWithParameter}
$f.Invoke("Hi ya")

# Works (of course).
FunctionWithTwoParameters -Text1 "Heading" -Text2 "Text"

# Works.
[scriptblock]$f = ${function:FunctionWithTwoParameters}
$f.Invoke("Key", "Value")

# Works.
ApplyWithParameters -s ${function:FunctionWithTwoParameters} -arguments "ApplyKey","Value2"

Divide -numerator 10 -denominator 2

# Works with and without an exception.
WrapInTryCatch -function ${function:Divide} -arguments 10, 2
WrapInTryCatch -function ${function:Divide} -arguments 10, 0

# Works with and without an exception.
WrapInTryCatch -function ${function:Sum} -arguments 1, 2, 3
WrapInTryCatch -function ${function:Sum} -arguments 1, xxx, 3

NoArgs
WrapInTryCatch -function ${function:NoArgs} 