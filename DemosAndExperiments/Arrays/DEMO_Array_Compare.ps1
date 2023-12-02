<#
.SYNOPSIS
Demonstrates how to populate a hashtable from an array.

.NOTES
#>

function Write-Title ($TitleText)
{
    Write-Host
    Write-Host $TitleText
    Write-Host ("-" * $TitleText.Length)
}

function Compare-Version (
    [array]$LeftVersionNumber,
    [array]$RightVersionNumber
    )
{
    $leftIsEmpty = $False
    if ($LeftVersionNumber -eq $Null -or $LeftVersionNumber.Count -eq 0)
    {
        $leftIsEmpty = $True    
    }

    if ($RightVersionNumber -eq $Null -or $RightVersionNumber.Count -eq 0)
    {
        if ($leftIsEmpty)
        {
            return '='
        }    
        return '>'
    }

    if ($leftIsEmpty)
    {
        return '<'
    }
    
    $numberOfElements = ($LeftVersionNumber.Count,$RightVersionNumber.Count | 
                            Measure-Object -Minimum).Minimum 

    for($i=0; $i -lt $numberOfElements; $i++)
    {
        if ($LeftVersionNumber[$i] -lt $RightVersionNumber[$i])
        {
            return '<'
        }
        if ($LeftVersionNumber[$i] -gt $RightVersionNumber[$i])
        {
            return '>'
        }
    }

    if ($LeftVersionNumber.Count -gt $numberOfElements)
    {
        return '>'
    }

    if ($RightVersionNumber.Count -gt $numberOfElements)
    {
        return '<'
    }

    return '='
}

Clear-Host

Write-Title 'Both Null'
$l = $Null
$r = $Null
Compare-Version $l $r

Write-Title 'Left Null'
$l = $Null
$r = @(1, 2)
Compare-Version $l $r

Write-Title 'Right Null'
$l = @(1, 2)
$r = $Null
Compare-Version $l $r

Write-Title 'Both same'
$l = @(1, 2, 3, 4)
$r = @(1, 2, 3, 4)
Compare-Version $l $r

Write-Title 'First digit on the left less than on the right'
$l = @(0, 2, 3, 4)
$r = @(1, 2, 3, 4)
Compare-Version $l $r

Write-Title 'Second digit on the left less than on the right'
$l = @(1, 0, 3, 4)
$r = @(1, 2, 3, 4)
Compare-Version $l $r

Write-Title 'Third digit on the left less than on the right'
$l = @(1, 2, 0, 4)
$r = @(1, 2, 3, 4)
Compare-Version $l $r

Write-Title 'Fourth digit on the left less than on the right'
$l = @(1, 2, 3, 0)
$r = @(1, 2, 3, 4)
Compare-Version $l $r

Write-Title 'First digit on the left more than on the right'
$l = @(5, 2, 3, 4)
$r = @(1, 2, 3, 4)
Compare-Version $l $r

Write-Title 'Second digit on the left more than on the right'
$l = @(1, 5, 3, 4)
$r = @(1, 2, 3, 4)
Compare-Version $l $r

Write-Title 'Third digit on the left more than on the right'
$l = @(1, 2, 5, 4)
$r = @(1, 2, 3, 4)
Compare-Version $l $r

Write-Title 'Fourth digit on the left more than on the right'
$l = @(1, 2, 5, 4)
$r = @(1, 2, 3, 4)
Compare-Version $l $r

Write-Title 'Left has less digits than right'
$l = @(1, 2, 3)
$r = @(1, 2, 3, 4)
Compare-Version $l $r

Write-Title 'Left has more digits than right'
$l = @(1, 2, 3, 4)
$r = @(1, 2, 3)
Compare-Version $l $r
