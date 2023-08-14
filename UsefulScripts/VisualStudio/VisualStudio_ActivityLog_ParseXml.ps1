Clear-Host
$filePath = 'C:\Temp\ActivityLog_SafeMode.xml'

<#
Format of XML file (note that time value appears to be UTC):

<activity>
  <entry>
    <record>1</record>
    <time>2016/04/19 06:00:33.943</time>
    <type>Information</type>
    <source>VisualStudio</source>
    <description>Microsoft Visual Studio 2013 version: 12.0.40629.0</description>
  </entry>
  <entry>
    <record>2</record>
    <time>2016/04/19 06:00:33.943</time>
    <type>Information</type>
    <source>VisualStudio</source>
    <description>Running in User Groups: Users</description>
  </entry>
  ...
</activity>
#>
$xmlDoc = new-object xml
$xmlDoc.load($filePath)
$StartTime = Get-Date $xmlDoc.activity.entry[0].time
$xmlDoc.activity.entry `
    | select @{Name="entry"; `
        Expression={(New-TimeSpan -Start $StartTime -End (Get-Date $_.time)).ToString('hh\:mm\:ss\.f') `
                    + ' ' + $_.record.padleft(4, '0') + ' ' + $_.type.Substring(0, 1) + ' ' `
                    + $_.source + ' | ' + $_.description + ' ' + $_.path `
                    } `
                } | format-wide -Column 1