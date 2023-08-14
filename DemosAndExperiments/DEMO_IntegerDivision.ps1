function Get-IntegerDivision([int]$numerator, [int]$denominator)
{
    # Truncates towards zero.  So -2.8 will be returned as -2, and 2.8 will be returned as 2.
    return [math]::truncate($numerator/$denominator)
}

Get-IntegerDivision -14 5
Get-IntegerDivision -11 5
Get-IntegerDivision 14 5
Get-IntegerDivision 11 5