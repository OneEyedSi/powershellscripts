<#
.SYNOPSIS
Demonstrates how to read an object property in a double-quoted string.

.DESCRIPTION
Including a double-quoted string 

.NOTES

#>
$file = Get-ChildItem "C:\Temp\*.txt" | Select-Object -First 1

$value = $file.Exists

Clear-Host

# Writes: "Property of object: C:\Temp\BooksServicePost_HttpClient.txt.Exists"
Write-Host "Property of object: $file.Exists"

# Writes: "Property of object: "
Write-Host "Property of object: ${$file.Exists}"

# Writes: "Property of object: "
Write-Host "Property of object: ${file.Exists}"

# Writes: "Property of object: True"
# This is how you do it!
Write-Host "Property of object: $($file.Exists)"

# Writes: "Value: true"
Write-Host "Value: $value"

# Writes: "Property of object: True"
# -f is the Format operator.  The whole expression needs to be enclosed in parentheses otherwise 
# Powershell thinks -f is supposed to be a parameter of Write-Host.
Write-Host ("Property of object: {0}" -f $file.Exists)
# Format operator with multiple arguments.
Write-Host ("File '{0}' is in folder '{1}'" -f $file.Name, $file.DirectoryName)