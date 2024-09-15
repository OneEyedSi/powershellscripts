function Operate ($Position1, $Position2, $SaveResultToPosition, 
    $Array, $Operation)
{
    # Zero-based positions.
    $number1 = $Array[$Position1]
    $number2 = $Array[$Position2]

    $result = switch ($Operation) 
    { 
        'ADD' { "($number1 + $number2)" }
        'MULTIPLY' { "($number1 * $number2)" }
        Default { throw "(Invalid operation: $Operation)" }
    } 
    
    $Array[$SaveResultToPosition] = $result

    return $Array
}

function GetCommand($OpCode)
{
    $commandText = switch ($OpCode)    
    {
        1 { 'ADD' }
        2 { 'MULTIPLY' }
        99 { 'STOP' }
        Default { 'INVALID' }
    }

    return $commandText
}

function WriteArray ($Array, $Title)
{
    Write-Host $Title

    for($position = 0; $position -lt $Array.Length; $position++)
    {
        $value = $Array[$position]
        $message = "Position $position : $($value)"
        $intCodeIndex = $position % 4
        $intCodeMeaning = switch ($intCodeIndex)
        {
            0 { 'Opcode: ' + (GetCommand $value) }
            1 { 'Position of Input 1' }
            2 { 'Position of Input 2' }
            3 { 'Position of Output' }
        }
        $message += " [$intCodeMeaning]"
        Write-Host $message
    }
}

function PerformAllOperations($Array)
{
    $stopCode = 99

    WriteArray $array 'Original array'

    $position = 0
    $opCode = -1
    while ($position -lt $Array.Length -and $opCode -ne $stopCode)
    {
        $opCode = $Array[$position]
        $inputPosition1 = $Array[$position + 1]
        $inputPosition2 = $Array[$position + 2]
        $resultPosition = $Array[$position + 3]
        if ($opCode -eq $stopCode)
        {
            break
        }

        $operation = switch ($opCode)
        {
            1 { 'ADD' }
            2 { 'MULTIPLY' }
            Default { throw "Invalid opcode: $opCode" }
        }

        $Array = Operate $inputPosition1 $inputPosition2 $resultPosition $Array $operation

        $position += 4
    }

    WriteArray $array 'After processing'

}

Clear-Host
$array = @(1,'x','y',3,1,1,2,3,1,3,4,3,1,5,0,3,2,13,1,19,1,19,9,23,1,5,23,27,1,27,9,31,1,6,31,35,2,35,9,39,1,39,6,43,2,9,43,47,1,47,6,51,2,51,9,55,1,5,55,59,2,59,6,63,1,9,63,67,1,67,10,71,1,71,13,75,2,13,75,79,1,6,79,83,2,9,83,87,1,87,6,91,2,10,91,95,2,13,95,99,1,9,99,103,1,5,103,107,2,9,107,111,1,111,5,115,1,115,5,119,1,10,119,123,1,13,123,127,1,2,127,131,1,131,13,0,99,2,14,0,0)

#PerformAllOperations $array

function ExecuteResultantOperation($ExpectedResult)
{
    for ($x = 0; $x -le 99; $x++)
    {
        for ($y = 0; $y -le 99; $y++)
        {
            $result = (($y + (5 + (4 + (((3 * (1 + (3 + (5 * (4 * ((3 * (2 + (5 * (((3 + ((1 + (((3 * (((2 + ((1 + ((5 * $x) + 3)) + 3)) * 3) + 2)) + 2) * 3)) * 2)) + 4) + 5)))) + 2)))))) + 1) + 1)))) + 5)
            if ($result -eq $ExpectedResult)
            {
                return $x,$y
            }
        }
    }
}

ExecuteResultantOperation 19690720
