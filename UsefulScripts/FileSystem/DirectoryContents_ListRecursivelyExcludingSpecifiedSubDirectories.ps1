<# 
Lists directory contents recursively (contents of specified directory and the tree of 
sub-directories, sub-sub-directories, etc under it), while excluding the specified 
sub-directories and all their contents.

The reason for this is that the Get-ChildItem -Exclude parameter only operates on 
$_.Name, not $_.FullName.  So it will only work on the leaf-level of a path (filename 
with path stripped out or directory name with path stripped out).  If used with the 
-Recurse parameter it will exclude directories but not their contents (files or 
sub-directories).
#>
$rootFolderPath = 'C:\ManuallyInstalledApplications\FitNesse'
$excludeDirectories = ("HsacFixturesBuild", "RestFixtureBuild");

function Exclude-Directories ($directoriesToExclude)
{
    process
    {
        $allowThrough = $true
        foreach ($directoryToExclude in $directoriesToExclude)
        {
            $directoryText = "*\" + $directoryToExclude
            $childText = "*\" + $directoryToExclude + "\*"
            # Have to use $_ rather than $input since $input can only be 
            # referenced once; if it is referenced again it returns 
            # nothing.
            if (($_.FullName -Like $directoryText -And $_.PsIsContainer) `
                -Or $_.FullName -Like $childText)
            {
                $allowThrough = $false
                break
            }
        }
        if ($allowThrough)
        {
            return $_
        }
    }
}

Clear-Host

Get-ChildItem $rootFolderPath -Recurse `
    | Exclude-Directories $excludeDirectories #`
#    | Where-Object {$_.FullName.Length -gt 210}