<#
.SYNOPSIS
Checks a SSMS Solution Explorer project for missing script files.

.DESCRIPTION
Checks a SSMS Solution Explorer project for missing script files.  Lists any files that appear in the file system but 
are not included in the project file, and vice versa.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
Version:		1.0.0 
Date:			10 Dec 2025

#>

$ssmsProjectFilePath = 'C:\Working\UsefulSqlScripts\Users\Users.ssmssqlproj'

# -------------------------------------------------------------------------------------------------
# No changes needed below this point; the remaining code is generic.
# -------------------------------------------------------------------------------------------------

$xmlDoc = new-object xml
$xmlDoc.Load($ssmsProjectFilePath)
# Array of strings.
$filesInProject = $xmlDoc.SqlWorkbenchSqlProject.Items.LogicalFolder.Items.FileNode.Name

$folderPath = Split-Path -Path $ssmsProjectFilePath -Parent
# Array of strings.  If just use Select-Object Name then get PSCustomObject rather than string.
$filesInFolder = Get-ChildItem -Path $folderPath -Filter '*.sql' | Select-Object -ExpandProperty Name

$missingFiles = Compare-Object -ReferenceObject $filesInFolder -DifferenceObject $filesInProject
$missingFromProject = $missingFiles | 
Where-Object { $_.SideIndicator -eq '<=' } | 
Select-Object -ExpandProperty InputObject
$missingFromFolder = $missingFiles | 
Where-Object { $_.SideIndicator -eq '=>' } | 
Select-Object -ExpandProperty InputObject

if ($missingFromProject.Count -eq 0 -and $missingFromFolder.Count -eq 0)
{
    Write-Host "No missing files found.  All files in folder are included in project, and all files in project exist in folder." -ForegroundColor Green
}
else
{
    if ($missingFromProject.Count -gt 0)
    {
        Write-Host "Files in folder but missing from project:" -ForegroundColor Yellow
        $missingFromProject | ForEach-Object { Write-Host " - $_" }
    }
    if ($missingFromFolder.Count -gt 0)
    {
        Write-Host "Files in project but missing from folder:" -ForegroundColor Yellow
        $missingFromFolder | ForEach-Object { Write-Host " - $_" }
    }
}
