<#
.SYNOPSIS
Demonstrates that PowerShell will consolidate the output of multiple operations into a single collection.
#>
function Write-ValueToOutput
{
    $x = Get-Random
    Write-Output $x
}

function Write-Title ($TitleText)
{
    Write-Host
    Write-Host $TitleText
    Write-Host ("-" * $TitleText.Length)
}

Clear-Host

# Call the function once to show that it outputs a single Int32 value.
Write-Title 'Call function once:'
$a = Write-ValueToOutput
$a
$a.GetType().FullName
Write-Host

# Call the function multiple times - the multiple outputs are consolidated into a collection.
Write-Title 'Call function multiple times:'
$y = (0..9).ForEach{Write-ValueToOutput}
$y
Write-Host

"Number of objects in collection: $($y.Count)"
"Resulting type: $($y.GetType().FullName)"
"Element type: $($y[0].GetType().FullName)"
if ($y -is [array]) { '$y is an array' } else { "It's not an array, though" }