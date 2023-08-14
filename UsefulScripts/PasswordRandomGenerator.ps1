<#
.SYNOPSIS
Generates a random password of the specified length.

.DESCRIPTION
Generates a password made up of upper and lower case letters and digits, with the specified length.

.NOTES

#>

$numberOfCharacters = 20

$password = ""
foreach($charCount in 1..$numberOfCharacters)
{   
    $asciiRangeMinimum = 0
    $asciiRangeMaximum = 0

    $characterSets = @( 'Digits', 'Upper Case', 'Lower Case')

     # Random number is less than -Maximum.  so -Maximum value will never be chosen.
    $characterSetIndex = Get-Random -Minimum 0 -Maximum 3

    $characterSet = $characterSets[$characterSetIndex]

    switch ($characterSet)
    {
        'Digits'        { 
                            $asciiRangeMinimum = 48
                            # remember that maximum can never be reached in Get-Random
                            # So go 1 larger than the highest ASCII code for the range.
                            $asciiRangeMaximum = 58
                        }   
        'Upper Case'    { 
                            $asciiRangeMinimum = 65
                            $asciiRangeMaximum = 91
                        }     
        'Lower Case'    { 
                            $asciiRangeMinimum = 97
                            $asciiRangeMaximum = 123
                        }   
    }

    $asciiCode = Get-Random -Minimum $asciiRangeMinimum -Maximum $asciiRangeMaximum
    $character = [char]$asciiCode
    $password += $character
}

Write-Host $password