<#
.SYNOPSIS
Replaces all instances of $textToReplace with $replacementText in all files in a 
given folder, where the file names match the filter criterion.
#>
$rootFolderPath = 'C:\Test\FitNesseTests\FitNesseRoot\FrontPage'
$fileNameFilter = '*.*'
$recurse = $True
$textToReplace = 'NumberOfConsigments'
$replacementText = 'NumberOfConsignments'

Get-ChildItem -Path $rootFolderPath -Filter $fileNameFilter -File -Recurse:$recurse | 
    Select-Object FullName | 
    ForEach-Object {
            (Get-Content $_.FullName) -replace $textToReplace, $replacementText | 
                Set-Content $_.FullName 
        }