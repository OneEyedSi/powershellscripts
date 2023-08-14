function Write-Title ($TitleText)
{
    Write-Host
    Write-Host $TitleText
    Write-Host ("-" * $TitleText.Length)
}

function Write-HorizontalLine()
{
	Write-Host ("-" * 40)
}

function Write-RegexReplacement (
	[regex]$regex, 
	[string]$textToModify, 
	[string]$replacementText
	)
{
	Write-Host "Original text: '${textToModify}'"	
	
	$result = $regex.Replace($textToModify, $replacementText)
	Write-Host "Modified text: '${result}'"
}

function Write-RegexReplacement2 (
	[string]$regexPattern, 
	[string]$textToModify, 
	[string]$replacementText
	)
{
	Write-Host "Original text: '${textToModify}'"	
	
	$result = $textToModify -replace $regexPattern, $replacementText
	Write-Host "Modified text: '${result}'"
}

function Write-DateTimeFormat (
	[string]$regexPattern, 
	[string]$textToModify
	)
{
	$isMatch = $textToModify -match $regexPattern
	if ($isMatch -and $Matches.Count -ge 3)
	{
		Write-Host "Format string: $($Matches[2])"
	}
}

function Write-RegexMatch (
	[string]$regexPattern, 
	[string]$textToMatch
	)
{
	Write-Host "Text to match: '$textToMatch'"
    
    $isMatch = $textToMatch -match $regexPattern

    if (-not $isMatch)
    {
        Write-Host 'No match found.'
        return 
    }

    # Matches can be read from $Matches automatic variable.
    if ($Matches.Count -eq 0)
    {
        Write-Host 'No match objects returned.'
        return
    }

    for($i = 0; $i -lt $Matches.Count; $i++)
    {     
        Write-Host "Match $($i): $($Matches[$i])"
    }
}

function New-Regex (
	[string]$regexPattern
)
{
	Write-Title "Regex ${regexPattern}:"
	
	# Create compiled regex object so it doesn't have to be compiled each time it is used.
		
	# If didn't need RegexOptions could create regex via:
	# 	return [regex] $regexPattern
	
	# Need to enclose arguments in @(...), just including the comma is not sufficient.
	return New-Object System.Text.RegularExpressions.Regex `
		-ArgumentList @($regexPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

Clear-Host

$regex = New-Regex "{\s*Message\s*}"

Write-RegexReplacement $regex "This includes a {Message} and some other text." "REPLACEMENT"
Write-Host 

Write-RegexReplacement $regex "Case-insensitive {message} and some other text." "REPLACEMENT"
Write-Host 

Write-RegexReplacement $regex "This includes leading and trailing spaces {  Message }." "REPLACEMENT"
Write-Host 

Write-RegexReplacement $regex "This includes leading and trailing tabs {	Message		}." "REPLACEMENT"
Write-Host 

Write-HorizontalLine

# No need to compile regex if it won't be used often.

$regexPattern = "{\s*Message\s*}"

Write-Title "Regex pattern ${regexPattern}:"

Write-RegexReplacement2 $regexPattern "This includes a {Message} and some other text." "REPLACEMENT"
Write-Host 

Write-RegexReplacement2 $regexPattern "Case-insensitive {message} and some other text." "REPLACEMENT"
Write-Host 

Write-RegexReplacement2 $regexPattern "This includes leading and trailing spaces {  Message }." "REPLACEMENT"
Write-Host 

Write-RegexReplacement2 $regexPattern "This includes leading and trailing tabs {	Message		}." "REPLACEMENT"
Write-Host 

Write-HorizontalLine

# Bit sloppy, don't need the outer capture group.  But as a non-capturing group is defined by 
# (?: ) I thought it would be a bit confusing to have (?::\s...
$regexPattern = "{\s*Timestamp\s*(:\s*(.+)\s*)?\s*}"

Write-Title "Regex pattern ${regexPattern}:"

Write-RegexReplacement2 $regexPattern "This includes a {Timestamp} and some other text." "REPLACEMENT"
Write-Host  

Write-RegexReplacement2 $regexPattern "Case-insensitive {timestamp} and some other text." "REPLACEMENT"
Write-Host  

$textToModify = "Case-insensitive {	timestamp : yyyy-MM-dd hh:mm:ss.fff	} and some other text."
Write-RegexReplacement2 $regexPattern $textToModify "REPLACEMENT"
Write-DateTimeFormat $regexPattern $textToModify
Write-Host 

Write-HorizontalLine

# Regex Pattern:
    
# <                        - match a "<" character
# \s*                      - match 0 or more whitespaces
# (                        - start of capture group 1
#     (\S+)                - nested capture group 2: match 1 or more non-whitespace characters - captures tag name only
#     \b                   - word boundary (boundary between a word character and a following non-word character)
#     (?:                  - start of non-capturing group
#         (?!\s*\/?\s*>)   - nested negative lookahead - DO NOT match the following sequence:
#                                0 or more whitespaces 
#                                    followed by 
#                                optional "/" 
#                                    followed by 
#                                0 or more whitespaces 
#                                    followed by 
#                                ">" 
#         .                - match any character
#     )*                   - end of non-capturing group, group can appear 0 or more times
# )                        - end of capture group 1 - captures tag name and attributes but excludes any "/" and/or ">" at the end of the tag

# Capture group 1 will capture the tag name and attributes
# Capture group 2 will capture the tag name only
$regexPattern = '<\s*((\S+)\b(?:(?!\s*\/?\s*>).)*)'

Write-Title "Regex pattern ${regexPattern}:"

$textToMatch = '<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">'
Write-RegexMatch $regexPattern $textToMatch
Write-Host 

$textToMatch = '<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" >'
Write-RegexMatch $regexPattern $textToMatch
Write-Host 

$textToMatch = '<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"/>'
Write-RegexMatch $regexPattern $textToMatch
Write-Host 

$textToMatch = '<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" />'
Write-RegexMatch $regexPattern $textToMatch
Write-Host 

$textToMatch = '<soap:Envelope />'
Write-RegexMatch $regexPattern $textToMatch
Write-Host 

$textToMatch = '<soap:Envelope/>'
Write-RegexMatch $regexPattern $textToMatch
Write-Host 

$textToMatch = '<soap:Envelope >'
Write-RegexMatch $regexPattern $textToMatch
Write-Host 

$textToMatch = '<soap:Envelope>'
Write-RegexMatch $regexPattern $textToMatch
Write-Host 

$textToMatch = '<soap:Envelope1 />'
Write-RegexMatch $regexPattern $textToMatch
Write-Host 

$textToMatch = '<soap:Envelope1/>'
Write-RegexMatch $regexPattern $textToMatch
Write-Host 

$textToMatch = '<soap:Envelope1 >'
Write-RegexMatch $regexPattern $textToMatch
Write-Host 

$textToMatch = '<soap:Envelope1>'
Write-RegexMatch $regexPattern $textToMatch
Write-Host 

Write-HorizontalLine