<#
.SYNOPSIS
Adds a personal modules folder to PSModulePath.

.NOTES
Can be called from users' profiles to allow them to run scripts in a personal modules folder.
#>

$datacomModulePath = 'C:\Users\MyName\PowerShell\Scripts\Modules'

function Get-PowerShellPath ()
{
    # Try to get the module path for the current user.  Often this will be empty.  In that case 
    # get the module path for all users.
    $powerShellModulePath = [Environment]::GetEnvironmentVariable('PSModulePath', 'User')
    if (-not $powerShellModulePath)
    {
        $powerShellModulePath = [Environment]::GetEnvironmentVariable('PSModulePath', 'Machine')
    }

    return $powerShellModulePath
}

function Update-PowerShellPath (
        [string]$ExistingPath,
        [string]$NewPath
    )
{
    $NewPath = $NewPath.Trim()
    $NewPath = $NewPath.TrimEnd('\')

    if ([string]::IsNullOrWhiteSpace($ExistingPath))
    {
        [Environment]::SetEnvironmentVariable('PSModulePath', $NewPath, 'User')
        return [Environment]::GetEnvironmentVariable('PSModulePath', 'User')
    }

    $workingPath = $ExistingPath
    $workingPath = $workingPath.Replace($NewPath, '')
    # Handle the case where the new path exists in PSModulePath with a trailing "\".
    $workingPath = $workingPath.Replace(';\;', ';')
    $workingPath = $workingPath.Replace(';;', ';')
    $workingPath = $workingPath.TrimEnd()
    $workingPath = $workingPath.TrimEnd(';')

    $workingPath += ';' + $NewPath

    [Environment]::SetEnvironmentVariable('PSModulePath', $workingPath, 'User')
    return [Environment]::GetEnvironmentVariable('PSModulePath', 'User')
}

$unmodifiedPath = Get-PowerShellPath
$newPath = Update-PowerShellPath -ExistingPath $unmodifiedPath -NewPath $datacomModulePath