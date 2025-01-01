function Get-FirstText ()
{
    return 'Some text'
}

function Get-SecondText ()
{
    return 'Other text'
}

function Get-ThirdText ()
{
    return 'Yet more text'
}

function Get-Text ()
{
    $a = Get-FirstText
    $b = Get-SecondText

    return "$a; $b"
}

function Get-TextWithInput ([string]$InputValue)
{
    $a = Get-FirstText
    return "$InputValue plus '$a'"
}

function Invoke-TextWithInput ([string]$Value)
{
    return Get-TextWithInput $Value
}

function Set-Something     
{
    [CmdletBinding()]
    Param (
        [string]$FirstParam,
        [string]$SecondParam
    )

    if ($FirstParam)
    {
        Write-Error 'First error'
    }

    if ($SecondParam)
    {
        Write-Output 'Second text'
    }
}

<#
.SYNOPSIS
Want to test a function where we need to mock something twice, with different arguments, giving 
different results.
#>
function Invoke-Something ()
{
    try
    {
        Set-Something -FirstParam 'Hello' -ErrorAction Stop
    
        return
    }
    catch {}

    $Error.Clear()
    Set-Something -SecondParam 'World'
    if ($Error.Count -gt 0)
    {
        throw $Error[0]
    }

    Get-FirstText
}

<#
.SYNOPSIS
Want to test a function where we need to mock something twice, with the same arguments, giving 
different results.
#>
function Set-File ([string]$FilePath)
{
    if (Test-Path $FilePath)
    {
        return $True
    }

    New-Item -Path $FilePath -ItemType File

    if (Test-Path $FilePath)
    {
        return $True
    }

    return $False
}

function Get-ParameterLength ([string]$Text)
{
    if ([string]::IsNullOrEmpty($Text))
    {
        return 0
    }

    return $Text.Length
}

function Invoke-GetParameterLength ([string]$Text)
{
    return Get-ParameterLength $Text
}