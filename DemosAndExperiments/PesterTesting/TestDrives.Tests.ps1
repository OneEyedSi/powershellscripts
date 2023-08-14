<#
.SYNOPSIS
Demonstrates how Pester creates a fake drive for writing files to in tests.

.NOTES
Tests from "More Pester Features and Resources" from the "Hey, Scripting Guy!" blog:
https://blogs.technet.microsoft.com/heyscriptingguy/2015/12/18/more-pester-features-and-resources/
#>

$hashTable = @{ $Path = $Null }

Describe 'TestDrive' {
    It 'Uses the test drive' {
        # Alternative ways of accessing the test drive.
        $filePath = "$TestDrive\test.txt"
        $filePath2 = "TestDrive:\test.txt"

        $textToWrite = 'Temporary stuff'
        Set-Content -Path $filePath -Value $textToWrite
        $filePath | Should Exist
        $fileContents = Get-Content -Path $filePath2
        $fileContents | Should Be $textToWrite
        $hashTable["Path"] = $TestDrive
    }
}

Describe 'Next Describe' {
    It 'Removed the old TestDrive and started up a new one for the second describe' {
        "testDrive:\text.txt" | Should Not Exist
        $hashTable["Path"] | Should Not Exist
        $hashTable["Path"] | Should Not Be $TestDrive
    }
}