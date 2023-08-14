<#
.SYNOPSIS
Splits a camel-case string into words with separators between.

.DESCRIPTION
Splits a camel-case string into words with separators between.  The separator character(s) can be 
specified.  If the separator is not specified it defaults to a space.  If the 
UpperCaseFirstCharacter switch is set then the first character is forced to upper case.
#>
function Split-CamelCase (
    [string]$CamelCaseString,
    [string]$Separator = ' ',
    [switch]$UpperCaseFirstCharacter
    )
{
    $newString  = ''
    $characters = $CamelCaseString.ToCharArray()
    
    for($i = 0; $i -le $characters.Count; $i++)
    {
        if ($i -eq 0)
        {
            $thisChar = $characters[$i]
            if ($UpperCaseFirstCharacter.IsPresent)
            {
                $thisChar = [char]::ToUpper($thisChar)
            }
            $newString += $thisChar
            continue
        }

        $prevChar = $characters[$i - 1]
        $thisChar = $characters[$i]
        if ($i -eq $characters.Count - 1)
        {
            # Dummy upper case character.
            $nextChar = 'X'
        }
        else
        {
            $nextChar = $characters[$i + 1]
        }
        
        # First clause splits 'HelloIPECWorld' into 'Hello IPECWorld'.
        # Second clause splits 'HelloIPECWorld' into 'HelloIPEC World'.
        if ((-not [char]::IsUpper($prevChar) -and [char]::IsUpper($thisChar)) `
            -or ([char]::IsUpper($thisChar) -and -not [char]::IsUpper($nextChar)))
        { 
            $newString += $Separator
        }

        $newString += $characters[$i]
    }

    return $newString
}

Clear-Host

$sampleText = @(
                'HelloWorld'
                'Helloworld'
                'HelloXWorld'
                'HelloXYWorld'
                'HelloXYZWorld'
                'HelloWorldX'
                'HelloWorldXY'
                'HelloWorldXYZ'
                'Hello123World'
                'Hello1X2World'
                'HelloWorldOy'
                'HELloWorld'
                'helloWorld'
                'hElloWorld'
                'hELloWorld'
                )

foreach($phrase in $sampleText)
{
    $phrase
    Split-CamelCase $phrase
    Split-CamelCase $phrase -Separator '-'
    Split-CamelCase $phrase -UpperCaseFirstCharacter
    Write-Host '---------------------------'
}