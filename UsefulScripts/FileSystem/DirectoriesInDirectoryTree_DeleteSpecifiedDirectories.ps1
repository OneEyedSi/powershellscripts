$RootFolderPath = "C:\Temp"

Clear-Host

# Remove -WhatIf flag once you're happy with the folders to be deleted.
Get-ChildItem $RootFolderPath -Recurse -Directory | 
where { $_.Name -in ('bin', 'obj') } | 
Remove-Item -Recurse -WhatIf