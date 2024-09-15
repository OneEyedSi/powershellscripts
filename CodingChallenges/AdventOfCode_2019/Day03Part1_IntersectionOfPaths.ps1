function PerformCommand($CurrentPosition, $Command, $Array)
{
    $x = $CurrentPosition[0]
    $y = $CurrentPosition[1]

    $direction = $Command[0]
    $distance = [Convert]::ToInt32($command.Substring(1))
    for($i = 1; $i -le $distance; $i++)
    {
        $newX = $x
        $newY = $y
        switch ($direction)
        {
            'U' { $newY = $y + $i }
            'D' { $newY = $y - $i }
            'R' { $newX = $x + $i }
            'L' { $newX = $x - $i }
        }

        $newPosition = @($newX, $newY)
        $Array += ,$newPosition
    }

    return @{Array=$Array; NewPosition=$newPosition}
}

function PerformAllCommand($CommandText)
{
    $commands = $CommandText.Split(',')
    $array = @()
    $currentPosition = @(0,0)

    foreach($command in $commands)
    {        
        $result = PerformCommand $currentPosition $command $array
        $array = $result.Array
        $currentPosition = $result.NewPosition

        $command
    }
}

function GetIntersections($Array1, $Array2)
{
    $intersectingPoints = @()
    foreach($point1 in $Array1)
    {
        foreach($point2 in $Array2)
        {
            if ($point1[0] -eq $point2[0] -and $point1[1] -eq $point2[1])
            {
                $intersectingPoints += ,$point1
            }
        }
    }

    return $intersectingPoints
}

Clear-Host
# $array = @()
# $currentPosition = @(0,0)
# $command = 'U7'
# $result = PerformCommand $currentPosition $command $array
# $array = $result.Array
# $newPosition = $result.NewPosition
# $array[0]

$commandText1 = 'R75,D30,R83,U83,L12,D49,R71,U7,L72'
$commandText2 = 'U62,R66,U55,R34,D71,R55,D58,R83'
$array1 = PerformAllCommand $commandText1
$array2 = PerformAllCommand $commandText2

$intersectingPoints = GetIntersections $array1 $array2

$array1
