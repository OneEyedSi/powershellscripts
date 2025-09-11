<#
.SYNOPSIS
Removes all permissions for the specified user to the specified target directory, and all sub-directories and files in 
the tree below the target directory.

.DESCRIPTION

.NOTES
Author:			Simon Elms
Requires:		* Windows PowerShell 5.1 or cross-platform PowerShell 6+, running as Administrator
Version:		1.0.0 
Date:			17 Aug 2025

#>

$folderPath = 'C:\SourceControl\Web'
$userName = 'IIS APPPOOL\AppPoolName'

# --------------------------------------------------------------------------------------------------------------------------
# No changes needed below this point; the remaining code is generic.
# --------------------------------------------------------------------------------------------------------------------------

#region Requirements *******************************************************************************************************

# "#Requires" is not a comment, it's a Requires directive.  It will throw an error if the conditions are not met.

#Requires -RunAsAdministrator 

# Minimum PowerShell version, not exact version.
#Requires -Version 5.1

#endregion Requirements ****************************************************************************************************

$acl = Get-Acl -Path $folderPath
$accessRules = $acl.Access |
	Where-Object { $_.IdentityReference.Value.EndsWith($userName, 'CurrentCultureIgnoreCase') }
# Need the Out-Null to hide the output of the RemoveAccessRule method.
$accessRules | Foreach-Object { $acl.RemoveAccessRule($_) } | Out-Null
Set-Acl -AclObject $acl -Path $folderPath