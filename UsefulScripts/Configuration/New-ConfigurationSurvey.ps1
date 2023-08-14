<#
.SYNOPSIS
Sniffs for config files in the inetpub directory.

.DESCRIPTION
For each config file recursively discovered, we make a copy of it.

.NOTES
Must be run with elevated permissions.

.EXAMPLE
./New-ConfigurationSurvey.ps1

Recursively copies all .config files from a source directory, maintaining structure, to $surveyDir.
Iteratively removes all empty folders, leaving the minimum tree which contains config files only.
#>


$surveyDir = "C:\Temp\ConfigurationSurvey"
<#
.SYNOPSIS
Set up the "cloned" configuration directory.
#>
# New-Item -Type Directory $surveyDir

<#
.SYNOPSIS
Copy anything that looks like a config file, while preserving directory structure.
#>
Copy-Item -Path "C:\inetpub" -Filter *config -Recurse -Container -Destination $surveyDir

<#
.SYNOPSIS
Get rid of empty folders which were created in the previous step.
#>
$parentsBecameEmpty = $True
while ($parentsBecameEmpty) {
	$beforeObjectCount = [int](ls -Recurse $surveyDir | Measure-Object | Select-Object -expandproperty count)
	Write-Output "Before: $beforeObjectCount"
	Get-ChildItem -Directory -Recurse -Path $surveyDir | Where-Object -FilterScript {($_.GetFiles().Count -eq 0) -and $_.GetDirectories().Count -eq 0} | Remove-Item
	$afterObjectCount = [int](ls -Recurse $surveyDir | Measure-Object | Select-Object -expandproperty count)
	Write-Output "After: $afterObjectCount"
	if ($beforeObjectCount -eq $afterObjectCount) {
		$parentsBecameEmpty = $False
		break;
	}
}