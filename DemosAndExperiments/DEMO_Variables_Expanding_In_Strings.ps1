Clear-Host

$variable = 10.5
$doubleQuotedString = "Double-quoted variable value: $variable"

# Result: Double-quoted variable value: 10.5
Write-Host $doubleQuotedString

$singleQuotedString = 'Single-quoted variable value: $variable'

# Result: Single-quoted variable value: $variable
Write-Host $singleQuotedString

# Result: Single-quoted variable value: 10.5
Write-Host $ExecutionContext.InvokeCommand.ExpandString($singleQuotedString)