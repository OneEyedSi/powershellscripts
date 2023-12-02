<#
.SYNOPSIS
Demonstrates how to join a single directory and multiple file names using Join-Path.

.NOTES
Join-Path makes it easy to join multiple directory names and a single file name because the -Path 
parameter, which accepts the directory path, accepts input from the pipeline by value.  

It's a bit trickier to do it the other way around, single directory with multiple file names.

See also DEMO_PSCustomObject_Create_DifferentMethods.ps1 which determined the quickest method of 
doing this.
#>

$directoryPaths = @(
                    'C:\Temp'
                    'C:\Windows'
                    'C:\Users'
                )
$fileNames = @(
                'Test1.txt'
                'Test2.txt'
                'SubDir\Sub1.txt'
                'SubDir\Sub2.txt'
            )

function Write-Title ($TitleText)
{
    Write-Host
    Write-Host $TitleText
    Write-Host ("-" * $TitleText.Length)
}

Clear-Host

Write-Title 'Multiple directories, single file name'
$fileName = $fileNames[0]
$directoryPaths | Join-Path -ChildPath $fileName

Write-Title 'Single directory, multiple file names'
$directoryPath = $directoryPaths[0]
$objectArray = @()
$fileNames.ForEach{ $objectArray += [pscustomobject]@{ ChildPath=$_ } }
$objectArray | Join-Path -Path $directoryPath

# This is about 14% faster than the version that populates the object array.
# See DEMO_PSCustomObject_Create_DifferentMethods.ps1.
Write-Title 'Single directory, multiple file names, take 2'
$directoryPath = $directoryPaths[0]
$fileNames.ForEach{ [pscustomobject]@{ ChildPath=$_ } } | Join-Path -Path $directoryPath