$filePath = 'C:\Temp\logs\2020-10-01.log'
$newTimeText = '2020-10-01'

Clear-Host
$newTime = [datetime]::ParseExact($newTimeText, 'yyyy-MM-dd', $null)

$file = Get-Item $filePath
$file.CreationTime = $newTime
$file.LastWriteTime = $newTime
Write-Host "File Creation time: $($file.CreationTime);       Last Modified Time: $($file.LastWriteTime)"