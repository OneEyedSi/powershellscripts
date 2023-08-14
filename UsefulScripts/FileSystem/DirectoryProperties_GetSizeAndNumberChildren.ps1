$folderPath = 'C:\Temp\FileCompareTest\Source1\Left'

Clear-Host

$folderPath = Join-Path -Path $folderPath -ChildPath 'Images'
$result = get-childitem -Path $folderPath | 
            Measure-Object -Property Length -Sum -ErrorAction Stop | 
            Select-Object @{Name='NumberOfFiles'; Expression={$_.Count}}, @{Name='FolderSize'; Expression={$_.Sum}}

Write-Host "Number Files: $($result.NumberOfFiles); Folder Size (bytes): $($result.FolderSize)"