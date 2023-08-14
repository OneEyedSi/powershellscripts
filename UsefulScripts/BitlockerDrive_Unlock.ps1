# Check if drive is locked with Bitlocker and, if it is, prompt user for password to unlock.

function Get-DriveStatus($Drive)
{
    $result = @{IsLocked=$False; ErrorMessage=$Null}

    $scriptBlock = { manage-bde -status $Drive }
    try
    {
        $statusResults = Invoke-Command -ScriptBlock $scriptBlock
        $relevantResultString = ($statusResults | 
                                Where-Object { $_.Trim().Startswith('ERROR:') -or $_.Trim().Startswith('Lock Status:')})
        $statusStringParts = ($relevantResultString -split ':',2)
        
        if ($statusStringParts.Count -ne 2)
        {
            $result.ErrorMessage = 'Unable to read status'
            return $result
        }

        $status = $statusStringParts[1].Trim()
        
        if ($statusStringParts[0] -eq 'ERROR')
        {
            $result.ErrorMessage = $status
            return $result
        }

        $result.IsLocked =  ($status -eq 'Locked')
    }
    catch
    {
        $result.ErrorMessage = $_.Exception.Message
    }

    return $result
}

function Unlock-Drive($Drive)
{
    $result = @{Result=$False; ErrorMessage=$Null}

    $scriptBlock = { manage-bde -unlock $Drive -password }

    try
    {
        $statusResults = Invoke-Command -ScriptBlock $scriptBlock

        $statusResults
    }
    catch
    {
        $result.ErrorMessage = $_.Exception.Message
    }

    return $result
}

$statusResults = Get-DriveStatus K:
if ($statusResults.IsLocked)
{
    Unlock-Drive K:
}