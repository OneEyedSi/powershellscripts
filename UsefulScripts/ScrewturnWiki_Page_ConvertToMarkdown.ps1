<#
.SYNOPSIS
Converts Screwturn wiki pages into Markdown pages.

.DESCRIPTION
Converts Screwturn wiki pages into Markdown pages so they can be imported into Confluence.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5 or greater
Version:		1.0.0
Date:			16 Aug 2023
#>

$_screwturnPagesFolderPath = 'C:\Temp\ScrewturnWikiConversion\SourcePages'
$_outputFolderPath = 'C:\Temp\ScrewturnWikiConversion\ConvertedPages'
# Array of Screwturn page file names to convert.  Wildcards permitted.  
# To convert all pages, set to @('*.cs')
$_screwturnPageFileNamesToConvert = @('*.cs')

# -------------------------------------------------------------------------------------------------
# NO NEED TO CHANGE ANYTHING BELOW THIS POINT, THE REMAINDER OF THE CODE IS GENERIC.
# -------------------------------------------------------------------------------------------------

function Add-WildcardToFolderPath ($FolderPath)
{
    try 
    {
        # Will throw if $FolderPath is null.
        $FolderPath = $FolderPath.Trim()
    }
    catch 
    {
        return $null
    }

    if (-not $FolderPath)
    {
        return $null
    }

    $lastCharacter = $FolderPath[-1]
    if ($lastCharacter -ne '*')
    {
        $FolderPath = Join-Path $FolderPath '*'
    }    

    return $FolderPath
}
function Get-ScrewturnPageFilePath ($ScrewturnPagesFolderPath, $ScrewturnPageFileNamesToConvert)
{
    # All Screwturn page files have a *.cs file extension.
    # Exclude the previous versions of the page files; we're only interested in the current pages.
    # Previous versions have a zero-based version number as part of the file name, 
    # eg "MyWikiPage.00002.cs".  
    # The current version of the page has no version number, eg "MyWikiPage.cs".
    # Need -ExpandProperty parameter for Select-Object otherwise it returns a PCCustomObject, not 
    # a string.
    Get-ChildItem -Path $ScrewturnPagesFolderPath -File -Filter *.cs `
        -Include $ScrewturnPageFileNamesToConvert -Exclude '*.0*.cs' | 
        Select-Object -ExpandProperty FullName
}

function Convert-PageLine 
{    
    param 
    (
        # Array of replacement tuples, of the form: 
        # (
        #   (<regex1 to replace>,<replacement text 1>), 
        #   (<regex2 to replace>,<replacement text 2>), 
        #   ...
        # )
        [Parameter(Position=0, Mandatory=$true)]
        $ReplacementArray, 
        
        # Parameter that takes input from pipeline must come last in parameter list.
        [Parameter(Position=1, Mandatory=$true, ValueFromPipeline=$true)]
        $ScrewturnPageLine
    )  
    
    Process
    {
        if ($ScrewturnPageLine)
        {
            $ReplacementArray | 
                ForEach-Object { $outputLine = $ScrewturnPageLine }{ $outputLine = $outputLine -replace $_ } { $outputLine }
            
            return $outputLine
        }
        else 
        {
            return $ScrewturnPageLine
        }
    }
}

function Get-ReplacementArray
{
    # Array of replacement tuples, of the form: 
    # @(
    #       @(<regex1 to replace>,<replacement text 1>), 
    #       @(<regex2 to replace>,<replacement text 2>), 
    #       ...
    #  )
    # where the regex pattern to replace represents Screwturn markup and the replacement text 
    # represents the equivalent Markdown syntax.

    $replacementArray = @(
        # Need to include commas otherwise the sub-arrays get unrolled into a 
        # single large array.

        # Where there are multiple similar markups which differ only in the number 
        # of markup characters, eg headings, then the markups with more 
        # characters must come first in the list, to avoid partial conversions.

        # Lists:
        # Convert lists before headings as the Markdown for headings matches the Screwturn markup 
        # for ordered lists, so if headings were converted before lists the headings would be 
        # converted into ordered lists.

        # Ordered list.
        @('# ', '1. '),
        # Some ordered lists have been created manually using parentheses.  Replace them with 
        # ordered list Markdown.
        @('\d\) ', '1. '),
        # Screwturn's unordered list markup seems the same as Markdown.

        # Headings: 
        # The highest level headings in the old Toll wiki are level 2.  
        # So map level 2 Screwturn headings to level 1 Markdown and adjust all other headings 
        # similarly.
        @('======(.+)======', '##### $1'),
        @('=====(.+)=====', '#### $1'),
        @('====(.+)====', '### $1'),
        @('===(.+)===', '## $1'),
        @('==(.+)==', '# $1'),
        @('=(.+)=', '# $1'), 

        # Bold and italic
        @("'''''", "***"),
        @("'''", "**"),
        @("''", "*"),

        # Markdown has no underline so leave underline markup unchanged.  We can fix it manually.
        # Don't try to convert horizontal rules.  In some cases the same markup is being used to 
        # underline headings in monospaced text.

        # Manual line breaks: Replace with 2 spaces (assumes they are at the end of the line).
        @('{BR}', '  '),

        # Code and monospace.
        # Don't try to convert {code}...{/code}.  These are often multi-line but have the tags on 
        # first and last lines of code, rather than on the line before and the line after the code.
        # Confluence will lose the first line of code if the opening Markdown is on that same line.
        # We'll have to do them manually.
        # Don't try to convert multiline monospace.  In Screwturn this is delimited by @@ on the 
        # line above and @@ on the line below.  We would need to indent all the lines in between 
        # by 4 spaces to achieve the same effect in Markdown. Too difficult.
        # Single line monospace we can do, however.
        @('{{(.+)}}', '`$1`'), 
        @('{{{{', '```'), 
        @('}}}}', '```'),
        @('<\/?nowiki>', ''),
        @('@@([^@]+)@@', '``$1``'),

        # Links:
            # Links can be surrounded by single square brackets or double square brackets.

        # External links with a title.
        @('\[{1,2}(http[^\]]+)\|(.*?)\]{1,2}', '[$2]($1)'),

        # External links without a title: Don't enclose the URL in parentheses.  This is supposed 
        # to work in Markdown but in Confluence the parentheses are displayed.
        @('\[{1,2}(http[^\]\|]+)\]{1,2}', '$1'), 
        
        # The internal link regexes below assume the external links, starting with "http", have 
        # already been converted.

        # Internal links with a title.
        @('\[{1,2}([^\]]+)\|(.*?)\]{1,2}', '[$1]'),

        # Internal links without a title.
        @('\[{1,2}([^\]\|]+)\]{1,2}', '[$1]')

        # Images: Do not convert, since they will have to be uploaded to Confluence pages.
    )

    return $replacementArray
}

function Convert-PageContent ($ScrewturnPageContent)
{
    if (-not $ScrewturnPageContent)
    {
        return $null
    }

    $pageTitle = $ScrewturnPageContent[0]
    $titleLine = "PAGE TITLE: `"$pageTitle`""
    $underline = '-' * $titleLine.Length
    $contentNote = 'PAGE CONTENT STARTS BELOW'  
    $contentNote2 = 'Create a Confluence page with the title above, then copy the content below into it.'    
    $headerLines = @(
                        $titleLine 
                        $underline 
                        $contentNote  
                        $contentNote2 
                        $underline                                                         
                    )

    $convertedContentList = New-Object System.Collections.ArrayList
    $convertedContentList.AddRange($headerLines)

    # If '##PAGE##' text not found then $firstContentLine will be 0, the first line of 
    # the content, which would be what we want.
    $firstContentLine = [array]::IndexOf($ScrewturnPageContent, '##PAGE##') + 1
    $screwturnPageLinesToConvert = $ScrewturnPageContent[$firstContentLine..($ScrewturnPageContent.Count-1)]

    $replacementArray = Get-ReplacementArray

    ForEach($line in $screwturnPageLinesToConvert)
    {
        # The line to convert is passed through -replace multiple times, once for each replacement pair 
        # (regex to replace, replacement text) in the $replacementArray.
        $convertedLine = $replacementArray | 
            ForEach-Object { $outputLine = $line }{ $outputLine = $outputLine -replace $_ } { $outputLine }

        # ArrayList.Add() returns index of element that was added.  If this is not captured it will be 
        # output by the function, combining it with the output array.  The result would be an array 
        # where the first n elements are integers, where n is equal to the number of lines being 
        # converted, and the last element is a sub-array containing the converted lines.  To avoid 
        # this pass the return value of ArrayList.Add() to $null.
        $null = $convertedContentList.Add($convertedLine)
    } 
    
    return $convertedContentList.ToArray()
}

function Read-ContentFromScrewturnPage ($FilePath)
{
    Get-Content -Path $FilePath
}

function Write-ModifiedPageContent ($FilePath, $ConvertedContent)
{
    Set-Content -Path $FilePath -Value $ConvertedContent
}

function Convert-MatchingFile ($ScrewturnPagesFolderPath, 
                                $OutputFolderPath, 
                                $ScrewturnPageFileNamesToConvert)
{
    # Ensure Screwturn folder path ends in wildcard so Get-ChildItem -Include works.
    $ScrewturnPagesFolderPath = Add-WildcardToFolderPath $ScrewturnPagesFolderPath

    $pageFilePaths = Get-ScrewturnPageFilePath `
                        -ScrewturnPagesFolderPath $ScrewturnPagesFolderPath `
                        -ScrewturnPageFileNamesToConvert $ScrewturnPageFileNamesToConvert

    if (-not $pageFilePaths)
    {
        return
    }

    foreach($screwturnPageFilePath in $pageFilePaths)
    {
        $contentToConvert = Read-ContentFromScrewturnPage $screwturnPageFilePath

        if (-not $contentToConvert)
        {
            continue
        }

        $convertedContent = Convert-PageContent $contentToConvert

        if (-not $convertedContent)
        {
            continue
        }

        $fileName = Split-Path $screwturnPageFilePath -Leaf
        $outputFilePath = Join-Path $OutputFolderPath $fileName

        Write-ModifiedPageContent $outputFilePath $convertedContent
    }
}

Convert-MatchingFile -ScrewturnPagesFolderPath $_screwturnPagesFolderPath `
                    -OutputFolderPath $_outputFolderPath `
                    -ScrewturnPageFileNamesToConvert $_screwturnPageFileNamesToConvert