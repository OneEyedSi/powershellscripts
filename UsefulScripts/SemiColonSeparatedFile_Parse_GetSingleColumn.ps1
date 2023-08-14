$filePath = "C:\Temp\RVCHCHRework.txt"

Clear-Host

Get-Content $filePath | ForEach { $result = $_ -split ';'; $result[2] } 