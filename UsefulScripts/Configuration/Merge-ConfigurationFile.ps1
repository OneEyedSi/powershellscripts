<#
.SYNOPSIS
Merges an XML-Document-Transform (XDT) config file into a .NET config file.

.DESCRIPTION
If the two files exist, the transforms in the XDT config file are applied
to the .NET config file.

.PARAMETER Source
A XML-Document-Transform (XDT) config file.

.PARAMETER Destination
A .NET config file, such as "web.config".

.PARAMETER MSBuildExe
The location of msbuild.exe, the "task runner" for this script.

Defaults to the Visual Studio 2017 instance of msbuild.exe.

.PARAMETER TransformProject
The location of Transform.proj, the "task definition" for this script.

.NOTES
Requires a local copy of msbuild.exe and Transform.proj.

Must be run with elevated permissions.

Windows services and desktop applications will need to be restarted to pick up changes to their 
config files.  IIS will automatically restart web services and web sites when their config files 
are updated.

XDT := XML Document Transform. (http://schemas.microsoft.com/XML-Document-Transform)
Must be run on a computer with Visual Studio installed.
The path to msbuild.exe is hard-coded.

A task inside Transform.proj is required to apply the transform.

.EXAMPLE
Add a new app setting to a web.config file.

Merge-ConfigFile

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

[CmdletBinding()]
Param(
  [Parameter(Mandatory=$False,Position=1)]
   [string]$Source = "C:\Temp\PowershellScripts\transform_asx618_add.config",
	
   [Parameter(Mandatory=$False,Position=2)]
   [string]$Destination = "C:\Temp\Publish\Online\web.config",
   
   [Parameter(Mandatory=$False,Position=3)]
   [string]$MSBuildExe = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\MSBuild\15.0\Bin\msbuild.exe",
   
   [Parameter(Mandatory=$False,Position=4)]
   [string]$TransformProject = ".\TransformProject\Transform.proj"
)

if (-Not(Test-Path $MSBuildExe)) {
	throw [System.IO.FileNotFoundException] "Could not find MSBuild at location '$MSBuildExe'"
}

if (-Not(Test-Path $TransformProject)) {
	throw [System.IO.FileNotFoundException] "Could not find transform project at location '$TransformProject'"
}

function Merge-Config ($source, $destination) {
	& $MSBuildExe /t:TransformConfigFile /p:sourceConfiguration="$source" /p:destConfiguration="$destination" $TransformProject
}

Merge-Config $source $destination