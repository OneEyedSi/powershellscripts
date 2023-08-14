param([string[]]$Drives='K')
# Check if each drive is locked with Bitlocker and, if it is, prompt user for password to unlock.

$_validUsers = @('Me', 'MyAdmin')

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

    try
    {
        $displayDrive = $Drive -replace ':',''
        $message = "Enter password to unlock drive $displayDrive"
        $securePassword = Read-Host $message -AsSecureString

        Unlock-BitLocker -MountPoint $Drive -Password $securePassword
    }
    catch
    {
        $result.ErrorMessage = $_.Exception.Message
    }

    return $result
}

if (-not ($script:_validUsers -contains $env:USERNAME))
{
    Write-Error ERROR: "Username $env:USERNAME not in list of users authorised to unlock drive $Drive"
    return
} 

foreach($drive in $Drives)
{
    $drive = $drive.Trim()
	if (-not $drive.EndsWith(':'))
	{
		$drive = "${drive}:"
	}

    $statusResults = Get-DriveStatus $drive
    if ($statusResults.IsLocked)
    {
        Unlock-Drive $drive
    }
}