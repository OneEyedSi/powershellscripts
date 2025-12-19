<#
.SYNOPSIS
Unflattens the keys in a JSON object, resulting in nested JSON objects.

.DESCRIPTION
Background: The AspireAppHost project in the API solution flattens the JSON keys in the user secrets file.  As the file 
can potentially contain the configuration for every microservice in the solution, and for every environment, this can 
lead to a very large number of flattened keys in a single JSON object.  This is hard to read and maintain.  

This script takes such a flattened JSON object and unflattens the keys, resulting in nested JSON objects.  The 
unflattened JSON text output by this script is easier to read and maintain.  It can be pasted back into the user secrets 
file, although it will be flattened again as soon as the AspireAppHost project is run.

To use this script, set the $flattenedJson variable to the flattened JSON text you want to unflatten, then run the
script.  The unflattened JSON text will be output to the console.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1 or above
Version:		1.0.0 
Date:			  19 Dec 2025

#>

# .NET seems to flatten the keys in descending order.  To preserve this order in the unflattened output, set 
# $orderByDescending = $true.
$orderByDescending = $true

# Not actually needed if you're going to paste the results into the user secrets file, as Visual Studio will reformat 
# the indents automatically.  But useful if you want to view the output in a text editor.
$spacesPerIndent = 3

$flattenedJson = @"
{
  "targetEnvironment": "DEV",
  "startupProjects:0": "notification-api",
  "startupProjects:1": "report-api",
  "projects:report-api:config:ReportHttpClientTimeout": "1200",
  "ports:report-api": "12345",
  "ports:notification-api": "12347",
  "environments:local:envVars:DOTNET_ENVIRONMENT": "Development",
  "environments:local:envVars:ASPNETCORE_ENVIRONMENT": "Development",
  "environments:DEV:projects:report-api:config:Repository:Report:CustomReportName": "Custom",
  "environments:DEV:projects:report-api:config:Repository:Category:CustomCategoryName": "Custom",
  "environments:DEV:envVars:DOTNET_ENVIRONMENT": "Development",
  "environments:DEV:envVars:ASPNETCORE_ENVIRONMENT": "Development",
  "environments:DEV:config:ReportApiBaseUrl": "https://dev-api.com/report",
  "environments:DEV:config:NotificationApiBaseUrl": "https://dev-api.com/notification",
  "environments:DEV:config:Environment": "DEV",
  "environments:DEV:config:Array:0": "First value",
  "environments:DEV:config:Array:1": "Second value",
  "environments:DEV:config:ConnectionStrings:ReportConnectionString": "Data Source=[REDACTED];User ID=[REDACTED];Password=[REDACTED];Initial Catalog=Report;TrustServerCertificate=True",
  "environments:DEV:config:ConnectionStrings:NotificationConnectionString": "Data Source=[REDACTED];User ID=[REDACTED];Password=[REDACTED];Initial Catalog=Notification;TrustServerCertificate=True",
  "Aspire:VersionCheck:LastCheckDate": "2025-12-15T21:53:11.6735844\u002B00:00",
  "Aspire:VersionCheck:KnownLatestVersion": "13.0.2"
}
"@

# -------------------------------------------------------------------------------------------------
# No changes needed below this point; the remaining code is generic.
# -------------------------------------------------------------------------------------------------

function ConvertTo-NestedObject (
  [Parameter(Mandatory)]
  [PSCustomObject]$FlatObject, 

  [switch]$Descending
  ) {
    $unFlattenedObject = @{}
    
    foreach ($property in $FlatObject.PSObject.Properties) {
        $flattenedKey = $property.Name
        $value = $property.Value
        $flattenedKeyParts = $flattenedKey -split ':'
        
        $currentObject = $unFlattenedObject
        $parentObject = $null
        $parentKey = $null

        for ($i = 0; $i -lt $flattenedKeyParts.Count; $i++) 
        {
            $k = $flattenedKeyParts[$i]
            $isLast = $i -eq ($flattenedKeyParts.Count - 1)

            if ($isLast) 
            {
              if ([int]::TryParse($k, [ref]$null)) 
              {
                # += operator creates a new array and adds the value to it.  The new array must be assigned back to the
                # parent key.
                $currentObject += $value
                if ($null -ne $parentObject -and $null -ne $parentKey) 
                {
                  $parentObject[$parentKey] = $currentObject
                }
              }
              else 
              {
                $currentObject.Add($k, $value)
              }
            }
            else 
            {
                $nextKey = $flattenedKeyParts[$i + 1]
                $nextIsArrayIndex = $nextKey -match '^\d+$'
                
                if ($nextIsArrayIndex) 
                {
                  $parentObject = $currentObject
                  $parentKey = $k                   
                }

                if (-not $currentObject.ContainsKey($k)) 
                {
                    if ($nextIsArrayIndex) 
                    {
                      $childObject = @()               
                    }
                    else 
                    {
                      $childObject = @{}  
                    }
                    $currentObject.Add($k, $childObject)
                }
                
                $currentObject = $currentObject[$k]
            }
        }
    }
    
    $orderedDictionary = ConvertTo-OrderedDictionary -InputObject $unFlattenedObject -Descending:$Descending

    return $orderedDictionary
}

function ConvertTo-OrderedDictionary (
  [Parameter(Mandatory)]
  [HashTable]$InputObject, 
  
  [switch]$Descending
  ) {
      $sortedKeys = $InputObject.Keys | Sort-Object -Descending:$Descending
      $orderedDictionary = [System.Collections.Specialized.OrderedDictionary]::new()
      foreach ($key in $sortedKeys) {
          $value = $InputObject[$key]
          if ($value -is [System.Collections.Hashtable]) 
          {
              $value = ConvertTo-OrderedDictionary -InputObject $value -Descending:$Descending
          }
          $orderedDictionary.Add($key, $value)
      }
      return $orderedDictionary
  }

<#
.SYNOPSIS
Formats JSON string with specified indentation for better readability.

.DESCRIPTION
This function takes a JSON string and reformats it with the specified indentation level.

.NOTES
Needed for PowerShell versions prior to 6.0, where ConvertTo-Json produces weird indent formatting (eg 8 spaces per 
indent when I ran it in VS Code, although it seems to be consistent within a single execution).
#>
function Format-Json (
  [Parameter(Mandatory, ValueFromPipeline)]
  [String] $json, 
  
  [int]$Indentation = 2
  ) {

    $indent = 0
    # -split defaults to RegexMatch, as opposed to SimpleMatch.  Hence we can use "\" as escape character, instead of "`".
    $jsonLines = $json -split '\r?\n'
    $reformattedLines = @()
    foreach ($line in $jsonLines) 
    {
        if ($line -match '[}\]]\s*,?\s*$') { $indent-- } # Decrement indent for closing braces/brackets
        $indentedLine = (' ' * $indent * $Indentation) + $line.TrimStart()
        if ($line -match '[\{\[]\s*$') { $indent++ } # Increment indent for opening braces/brackets
        $reformattedLines += $indentedLine
    }
    return $reformattedLines -join [Environment]::NewLine
}

Clear-Host

$flattenedObject = ConvertFrom-Json -InputObject $flattenedJson 

$unflattenedObject = ConvertTo-NestedObject -FlatObject $flattenedObject -Descending:$orderByDescending
ConvertTo-Json -InputObject $unflattenedObject -Depth 20 | Format-Json -Indentation $spacesPerIndent