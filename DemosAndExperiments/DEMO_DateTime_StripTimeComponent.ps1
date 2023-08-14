<#
.SYNOPSIS
Demo of two methods of stripping the time components from a DateTime.

.NOTES
Add methods took 28.6 seconds
Get-Date - Date took 42.7 seconds
#>
function Test-TimeStripper ([scriptblock]$ScriptBlock, [string]$Description)
{
    Write-Host
    Write-Host "Starting $Description..."

    $startTime = Get-Date
    for ($i = 0; $i -lt 1e5; $i++)
    {
        $dateTime = Get-Date
        $ScriptBlock.Invoke($dateTime)
    }

    $endTime = Get-Date
    $timeTaken = ($endTime - $startTime)
    $timeTaken
}

Clear-Host

$scriptBlock = {
    param($dateTime)
    $dateTime.AddSeconds(-$dateTime.Second).AddMinutes(-$dateTime.Minute).AddHours(-$dateTime.Hour)
}
Test-TimeStripper -ScriptBlock $scriptBlock -Description "Add methods"

$scriptBlock = {
    param($dateTime)
    Get-Date -Date ($dateTime.ToString("d"))
}
Test-TimeStripper -ScriptBlock $scriptBlock -Description "Get-Date -Date"