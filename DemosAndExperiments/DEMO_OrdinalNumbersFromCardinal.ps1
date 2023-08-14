function Get-OrdinalNumber ([ValidateRange(0,[int]::MaxValue)][int]$cardinalNumber)
{
    $cardinalMod100 = $cardinalNumber % 100
    # Floor only works for positive numbers but ValidateRange prevents negatives being passed.
    $isCardinalTeen = if ([math]::floor($cardinalMod100 / 10) -eq 1) { $True } else { $False }

    if ($isCardinalTeen)
    {
        return "${cardinalNumber}th"
    }

    $cardinalMod10 = $cardinalMod100 % 10

    switch ($cardinalMod10)
    {
        1       { return "${cardinalNumber}st" }
        2       { return "${cardinalNumber}nd" }
        3       { return "${cardinalNumber}rd" }
        default { return "${cardinalNumber}th" }       
    }
}

Get-OrdinalNumber 0
Get-OrdinalNumber 1
Get-OrdinalNumber 2
Get-OrdinalNumber 3
Get-OrdinalNumber 4
Get-OrdinalNumber 5
Get-OrdinalNumber 6
Get-OrdinalNumber 7
Get-OrdinalNumber 8
Get-OrdinalNumber 9
Get-OrdinalNumber 10
Get-OrdinalNumber 11
Get-OrdinalNumber 12
Get-OrdinalNumber 13
Get-OrdinalNumber 14
Get-OrdinalNumber 15
Get-OrdinalNumber 16
Get-OrdinalNumber 17
Get-OrdinalNumber 18
Get-OrdinalNumber 19
Get-OrdinalNumber 20
Get-OrdinalNumber 21
Get-OrdinalNumber 22
Get-OrdinalNumber 23
Get-OrdinalNumber 24
Get-OrdinalNumber 25
Get-OrdinalNumber 99
Get-OrdinalNumber 100
Get-OrdinalNumber 101
Get-OrdinalNumber 102
Get-OrdinalNumber 103
Get-OrdinalNumber 104
Get-OrdinalNumber 105
Get-OrdinalNumber 109
Get-OrdinalNumber 110
Get-OrdinalNumber 111
Get-OrdinalNumber 112
Get-OrdinalNumber 113
Get-OrdinalNumber 114
Get-OrdinalNumber 119
Get-OrdinalNumber 120
Get-OrdinalNumber 121
Get-OrdinalNumber 122
Get-OrdinalNumber 123
Get-OrdinalNumber 124
Get-OrdinalNumber 125
Get-OrdinalNumber 126
Get-OrdinalNumber 129
Get-OrdinalNumber 130
Get-OrdinalNumber 131
# Will throw an error because negative numbers are outside acceptable range for function parameter.
Get-OrdinalNumber -11