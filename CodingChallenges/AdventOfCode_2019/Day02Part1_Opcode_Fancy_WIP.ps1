function Add ($Array, $OpCode, $InputPosition1, $InputPosition2, $OutputPosition)
{
    $number1 = $Array[$InputPosition1]
    $number2 = $Array[$InputPosition2]
    $result = $number1 + $number2
    $Array[$SaveResultToPosition] = $result

    return $Array
}

function Multiply ($Array, $OpCode, $InputPosition1, $InputPosition2, $OutputPosition)
{
    $number1 = $Array[$InputPosition1]
    $number2 = $Array[$InputPosition2]
    $result = $number1 * $number2
    $Array[$SaveResultToPosition] = $result

    return $Array
}

function Stop ($Array)
{
    return $Array
}

function Invalid ($Array, $OpCode)
{
    throw "Invalid Opcode: $OpCode"
}

function GetAllCommandDetails
{
    $commands =
    @(
        @{OpCode=1; Text='ADD'; NumberParameters=4},
        @{OpCode=2; Text='MULTIPLY'; NumberParameters=4},
        @{OpCode=99; Text='STOP'; NumberParameters=0},
        @{OpCode='Invalid'; Text='INVALID'; NumberParameters=1}
    )
    return $commands
}

function GetCommandDetailsByText($CommandText)
{
    $commands = GetAllCommandDetails
    $commandDetails = $commands | Where-Object { $_.Text -eq $CommandText }
    if (-not $commandDetails)
    {
        $commandDetails = $commands | Where-Object { $_.Text -eq 'INVALID' }
    }
    return $commandDetails
}

function GetCommandDetailsByOpCode($OpCode)
{
    $commands = GetAllCommandDetails
    $commandDetails = $commands | Where-Object { $_.OpCode -eq $OpCode }
    if (-not $commandDetails)
    {
        $commandDetails = GetCommandDetailsByText 'INVALID'
    }
    return $commandDetails
}

function OperateOnArray($Array, $OpCodePosition)
{
    $opCode = $Array[$OpCodePosition]
    $commandDetails = GetCommandDetails $opCode

    if ($commandDetails.NumberParameters -eq 0)
    {
        return [ScriptBlock]$commandDetails.Function.Invoke($Array)
    }

    # ... - 1 because OpCode is first argument.
    $lastArgumentPosition = $OpCodePosition + $commandDetails.NumberParameters - 1
    $arguments = $Array[$OpCodePosition+1..$lastArgumentPosition]
    return [ScriptBlock]$commandDetails.Function.Invoke($Array, $arguments)
}

function Operate ($Position1, $Position2, $SaveResultToPosition, 
    $Array, $Operation)
{
    # Zero-based positions.
    $number1 = $Array[$Position1]
    $number2 = $Array[$Position2]

    $result = switch ($Operation) 
    { 
        'ADD' { $number1 + $number2 }
        'MULTIPLY' { $number1 * $number2 }
        Default { throw "Invalid operation: $Operation" }
    } 
    
    $Array[$SaveResultToPosition] = $result

    return $Array
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
            0 { 'Opcode: ' + (GetCommandDetailsByOpCode $value).Text }
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
    $stopCommand = GetCommandDetailsByText 'STOP'
    $stopCode = $stopCommand.OpCode

    WriteArray $array 'Original array'

    $position = 0
    $opCode = -1
    while ($position -lt $Array.Length -and $opCode -ne $stopCode)
    {
        $opCode = $Array[$position]
        if ($opCode -eq $stopCode)
        {
            break
        }

        $Array = OperateOnArray $Array $position

        $position += 4
    }

    WriteArray $array 'After processing'
}

Clear-Host
$array = @(1,12,2,3,1,1,2,3,1,3,4,3,1,5,0,3,2,13,1,19,1,19,9,23,1,5,23,27,1,27,9,31,1,6,31,35,2,35,9,39,1,39,6,43,2,9,43,47,1,47,6,51,2,51,9,55,1,5,55,59,2,59,6,63,1,9,63,67,1,67,10,71,1,71,13,75,2,13,75,79,1,6,79,83,2,9,83,87,1,87,6,91,2,10,91,95,2,13,95,99,1,9,99,103,1,5,103,107,2,9,107,111,1,111,5,115,1,115,5,119,1,10,119,123,1,13,123,127,1,2,127,131,1,131,13,0,99,2,14,0,0)

PerformAllOperations $array
