<#
.SYNOPSIS
Merges an XML-Document-Transform (XDT) config file into a .NET config file.

.DESCRIPTION
If the two files exist, the transforms in the XDT config file are applied
to the .NET config file, and the modified .NET config file is over-written.

.PARAMETER transform
A full path to a XML-Document-Transform (XDT) config file.

.PARAMETER target
A full path to a .NET config file, such as "web.config".

.NOTES
Requires a local copy of "Microsoft.Web.XmlTransform.dll."

Paths must be fully qualified.

Must be run with elevated permissions.

Windows services and desktop applications will need to be restarted to pick up changes to their 
config files.  IIS will automatically restart web services and web sites when their config files 
are updated.

XDT := XML Document Transform. (http://schemas.microsoft.com/XML-Document-Transform)

Sourced from an online topic "Web.Config transforms outside of Microsoft MSBuild".

Ultimately, this should be replaced with a standard package:
Install-Package Microsoft.Web.Xdt -Version 2.1.2

.EXAMPLE
Add a new app setting to a web.config file.

Merge-Transform

---- Example xdt.config ----
<?xml version="1.0" encoding="utf-8"?>
<configuration xmlns:xdt="http://schemas.microsoft.com/XML-Document-Transform">
	<appSettings>
		<!-- Only insert the key if missing so we can run this repeatedly. -->
		<add key="NewAppSettingKey" xdt:Transform="InsertIfMissing" xdt:Locator="Match(key)" />
		<add key="NewAppSettingKey" value="NewAppSettingValue" xdt:Transform="Replace" xdt:Locator="Match(key)"/>
	</appSettings>
</configuration>

---- Example web.config ----
<?xml version="1.0" encoding="utf-8"?>
<configuration>
	<appSettings>
	</appSettings>
</configuration>

---- Example transformed web.config ----
<?xml version="1.0" encoding="utf-8"?>
<configuration>
	<appSettings>
		<add key="NewAppSettingKey" value="NewAppSettingValue"/>
	</appSettings>
</configuration>
#>
function Merge-Transform([string]$transform, [string]$target) {

    Add-Type -LiteralPath "./Microsoft.Web.XmlTransform.dll"

    $xmlTransform = New-Object Microsoft.Web.XmlTransform.XmlTransformation($transform);

    $xmlDocument = New-Object Microsoft.Web.XmlTransform.XmlTransformableDocument;
    $xmlDocument.PreserveWhitespace = $true;
    $xmlDocument.Load($target);

    $appliedSuccessfully = $xmlTransform.Apply($xmlDocument);

    if (-Not($appliedSuccessfully)) {
        Write-Error "Failed to apply transform.";
    } else {
        $xmlDocument.Save($target);
    }
}