$filePath = 'C:\Temp\DatabaseBackups\DigitalCropEstimation_20200128 - Copy.bak'
$fileDateTextToReplace = '20200128 - Copy'

$ageDays = 57

$fileName = [System.IO.Path]::GetFileName($filePath)
$folderPath = [System.IO.Path]::GetDirectoryName($filePath)
$currentDate = get-date
$newCreationDate = $currentDate.AddDays(-1 * $ageDays)
$newDateText = $newCreationDate.ToString('yyyyMMdd')
$newFileName = $fileName -replace $fileDateTextToReplace,$newDateText
$newFilePath = Join-Path -Path $folderPath -ChildPath $newFileName

Rename-Item -Path $filePath -NewName $newFileName
(Get-ChildItem -Path $newFilePath -File).CreationTime = $newCreationDate


