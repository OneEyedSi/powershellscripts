<#
.SYNOPSIS
Updates one or more .NET config files.

.DESCRIPTION
For each config file the script checks the specified path to determine if the config file exists 
and, if it does, the script sets the values of the specified XML nodes.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5 (may work on earlier versions but untested)
                Prog module 0.9.7
Version:		1.1.0 
Date:			21 Mar 2018

Must be run with elevated permissions.

Windows services and desktop applications will need to be restarted to pick up changes to their 
config files.  IIS will automatically restart web services and web sites when their config files 
are updated.
#>

# No need to explicitly import this module but do it anyway to make it obvious there is a 
# dependency.
Import-Module Prog

# Format: A list of hash tables, one for each config file to update.  Each hash table has three 
# elements: 
#    1) Name: A string that uniquely identifies the config file.  It can be any text at all;
#    2) Path: The full file name, including path, of the config file to update;
#    3) Updates: A list of hash tables, one for each update to the config file.  Each hash table 
#        has two elements:
#            1) NodeXPath: the XPath expression that identifies the XML node to be updated;
#            2) NewValue: The new value the XML node will be set to.
$_configDetails = @( `
                    @{Name="CommonApi"
                      Path="C:\Temp\ConfigFileUpdates\Test\CommonApi\Web.config"
                      Updates=@(
                                @{NodeXPath="./configuration/connectionStrings/add[@name='ApiConnectionString']/@connectionString"
                                  NewValue="Data Source=(localdb)\mssqllocaldb;Initial Catalog=Test;Trusted_Connection=True;Application Name=Common.API.Local;"}
                                @{NodeXPath="./configuration/connectionStrings/add[@name='ErrorConnectionString']/@connectionString"
                                  NewValue="Data Source=(localdb)\mssqllocaldb;Initial Catalog=ErrorLog;Trusted_Connection=True;Application Name=Common.API.Local;"}
                                @{NodeXPath="./configuration/connectionStrings/add[@name='AuthConnectionString']/@connectionString"
                                  NewValue="Data Source=(localdb)\mssqllocaldb;Initial Catalog=Test;Trusted_Connection=True;Application Name=Common.API.Local;"}
                               )
                     }
                     @{Name="DimensionScanParser"
                      Path="C:\Temp\ConfigFileUpdates\Test\DimensionScanParser\App.config"
                      Updates=@(
                                @{NodeXPath="./configuration/appSettings/add[@key='SourceFilePath']/@value"
                                  NewValue="C:\Temp\Scans\Scans.txt"}
                                @{NodeXPath="./configuration/appSettings/add[@key='ArchiveSourceFilePath']/@value"
                                  NewValue="C:\Temp\Scans\Archive\"}
                               )
                     }
                   )

# If no path is specified for the log file it will be created in the directory this script 
# is running in.  Similarly, relative paths will be relative to the directory this script 
# is running in.
[string]$_logFileName = "configUpdate.log"

# If set overwrites any existing log file.  If cleared appends to an existing log file.  If 
# no log file exists a new one will be created, regardless of the setting of this variable.
[bool]$_overwriteLogFile = $True 

<#
.SYNOPSIS
Writes a heading to the host and, optionally, to a log file.

.DESCRIPTION
Writes a heading that makes it obvious the script has just started.

.NOTES
Useful for scripts that may be run repeatedly.
#>
function Write-LogHeader (
    [Parameter(Mandatory=$True)]
    $Title
    )
{
    $MinLineLength = 50
    $LineLength = $Title.Length
    if ($LineLength -lt $MinLineLength)
    {
        $LineLength = $MinLineLength
    }
    $HorizontalLine = "=" * $LineLength

    Write-LogMessage $HorizontalLine -MessageFormat '{Message}' -IsDebug
    Write-LogMessage $Title -MessageFormat '{Message}' -IsDebug
    
    $DateText = (Get-Date).ToString("yyyy-MM-dd")
    $Message = "Run date: {0}" -f $DateText
    Write-LogMessage $Message -MessageFormat '{Message}' -IsDebug

    Write-LogMessage $HorizontalLine -MessageFormat '{Message}' -IsDebug
}

<#
.SYNOPSIS
Writes a footer to the host and, optionally, to a log file.

.DESCRIPTION
Writes a footer that makes it obvious the script has completed.

.PARAMETER ScriptResult
An integer indicating the overall result of the script.  Its value must be one of the following:
    0: Failure: One or more errors were encountered, preventing the update of any config file;
    1: Partial Failure: Some but not all config files were updated;
    2: Success: All config files were updated. 

.NOTES
Useful for scripts that may be run repeatedly.
#>
function Write-LogFooter (
    [Parameter(Mandatory=$False)]
    [string]$ResultText, 
    
    [Parameter(Mandatory=$False)]
    [string]$ResultCategory
    )
{
    $NL = [Environment]::NewLine
    
    $headerTerminator = ''
    if ($ResultText -and $ResultCategory)
    {
        $headerTerminator = '; '
    }
    
    switch ($ResultCategory)
    {
        SUCCESS         { $ResultHeader = 'RESULT: SUCCESS' }
        FAILURE         { $ResultHeader = 'RESULT: FAILURE' }
        PARTIALFAILURE  { $ResultHeader = 'RESULT: PARTIAL FAILURE' }
        default         { $ResultHeader = '' }
    }

    $message = "$($ResultHeader)$($headerTerminator)$ResultText"

    # Write basic result as normal log message to make it easier for automated parsing.
    Write-LogMessage $ResultHeader -Category $ResultCategory -IsDebug

    $minLineLength = 50
    $maxLineLength = 100
    $lineLength = $Message.Length
    if ($lineLength -lt $minLineLength)
    {
        $lineLength = $minLineLength
    }
    elseif ($lineLength -gt $maxLineLength)
    {
        $lineLength = $maxLineLength
    }
    $horizontalLine = "-" * $lineLength

    Write-LogMessage $horizontalLine -MessageFormat '{message}' -IsDebug

    Write-LogMessage $message -MessageFormat '{message}' -Category $ResultCategory -IsDebug
        
    Write-LogMessage $horizontalLine -MessageFormat '{message}' -IsDebug
}

<#
.SYNOPSIS
Builds an error message that includes the details of an exception.

.DESCRIPTION
Builds an error message made up of an error header which describes the action that failed, the 
details of the exception that occurred, and an optional additional message.

.NOTES

#>
function Get-ExceptionErrorMessage (
    [Parameter(Mandatory=$True)]
    [ValidateNotNull()]
    [System.Exception]$Exception,

    [string]$ErrorHeader, 

    [string]$AdditionalMessage
    )
{
    $errorMessage = ''
    if (-not [string]::IsNullOrBlank($ErrorHeader))
    {
        $errorMessage += "$($ErrorHeader.Trim()): "
    }

    if (-not [string]::IsNullOrBlank($AdditionalMessage))
    {
        $AdditionalMessage = $AdditionalMessage.Trim()
        if (-not $AdditionalMessage.EndsWith("."))
        {
            $AdditionalMessage += "."
        }
        $errorMessage += "$($AdditionalMessage.Trim())  "
    }

    $innerExceptionDetails = ""
    if ($Exception.InnerException)
    {
        $innerExceptionDetails = " (inner exception - $(Get-ExceptionErrorMessage -Exception $Exception.InnerException))"
    }

    $exceptionMessage = $Exception.Message
    if (-not $exceptionMessage.EndsWith("."))
    {
        $exceptionMessage += "."
    }
    $exceptionDetails = "$($Exception.GetType().FullName): $($exceptionMessage)$innerExceptionDetails"
    $errorMessage += $exceptionDetails
    return $errorMessage
}

<#
.SYNOPSIS
Writes the keys and values of a hash table to the host.

.DESCRIPTION
Writes the keys and values of a hash table to the host.

.NOTES
#>
function Write-HashTable (
        [Parameter(Mandatory=$True)]
        $HashTable, 

        [Parameter(Mandatory=$True)]
        [string]$Title
    )
{
    Write-Host $Title
    foreach($key in $HashTable.Keys)
    {
        $value = $HashTable[$key] 

        try
        {
            $type = " (type $($value.GetType().FullName))"
        }
        catch
        {
            $type = ''
        }
               
        if ($value -eq $Null)
        {
            $value = '[NULL]'
        }
        elseif ($value -is [string] -and $value -eq '')
        {
            $value = '[EMPTY STRING]'
        }
        elseif ($value -is [string] -and $value.Trim() -eq '')
        {
            $value = '[BLANK STRING]'
        }

        Write-Host "[$key] $type : '$value'"
    }
}

<#
.SYNOPSIS
Checks that the specified hash table key exists and has a value.

.DESCRIPTION
Checks that the specified hash table key exists and has a value.

.OUTPUTS
String that represents an error message.  If the string is null or empty then the specified 
hash table key exists and has a value.

.NOTES
#>
function Test-HashTableElement (
    [Parameter(Mandatory=$True)]
    [System.Collections.Hashtable]$HashTable,
    
    [Parameter(Mandatory=$True)]
    [string]$KeyName
    )
{
    if (-not $HashTable)
    {
        return "Hash table has not been defined."
    }

    if (-not $HashTable.ContainsKey($KeyName))
    {
        return "Hash table does not contain key '$KeyName'."
    }

    if (-not $HashTable[$KeyName])
    {
        return "Value of hash table element '$KeyName' is not set."
    }

    return $Null
}

<#
.SYNOPSIS
Checks the format of a single config update is correct.

.DESCRIPTION
Checks the format of a single config update is correct.

.PARAMETER ConfigDetail
Details of the updates to apply to a specific config file.
Format: A hash table that has three elements: 
    1) Name: A string that uniquely identifies the config file.  It can be any text at all;
    2) Path: The full file name, including path, of the config file to update;
    3) Updates: A list of hash tables, one for each update to the config file.  Each hash table 
        has two elements:
            1) NodeXPath: the XPath expression that identifies the XML node to be updated;
            2) NewValue: The new value the XML node will be set to.

.OUTPUTS
Boolean.  Test-SingleConfigDetail returns $True if the config update details are valid, or $False 
if they are not.

.NOTES
#>
function Test-SingleConfigDetail (
        [Parameter(Mandatory=$True)]
        $ConfigDetail
    )
{
    $errorMessageHeader = "Incorrect format for config details" 

    if ($ConfigDetail -isnot [System.Collections.Hashtable])
    {
        $errorMessage = "$($errorMessageHeader): Expected config details to be a " `
            + "hash table, was actually a $($ConfigDetail.GetType().Fullname)"
        Write-LogMessage $errorMessage -IsError
        return $False
    }

    $success = $True
    $configName = $Null

    $errorMessage = (Test-HashTableElement -HashTable $ConfigDetail -KeyName "Name")
    if ($errorMessage)
    {
        Write-LogMessage "$($errorMessageHeader): $errorMessage" -IsError
        $success = $False
    }
    else
    {
        $configName = $ConfigDetail.Name
        $errorMessageHeader = "Incorrect format for config details '$configName'" 
    }    

    $errorMessage = (Test-HashTableElement -HashTable $ConfigDetail -KeyName "Path")
    if ($errorMessage)
    {
        Write-LogMessage "$($errorMessageHeader): $errorMessage" -IsError
        $success = $False
    }

    $errorMessage = (Test-HashTableElement -HashTable $ConfigDetail -KeyName "Updates")
    if ($errorMessage)
    {
        Write-LogMessage "$($errorMessageHeader): $errorMessage" -IsError
        $success = $False
    }

    if (-not $success)
    {
        return $False
    }

    $updates = $ConfigDetail.Updates
    if ($updates -isnot [System.Object[]] -and $updates -isnot [System.Collections.Hashtable])
    {
        $errorMessage = "$($errorMessageHeader): Expected Updates to be an array or a single " `
            + "hash table, was actually a $($updates.GetType().Fullname)"
        Write-LogMessage $errorMessage -IsError
        return $False
    }

    $errorMessageHeader = "Incorrect Update format for config details '$configName'"

    foreach($update in $updates)
    {
        if ($update -isnot [System.Collections.Hashtable])
        {
            $errorMessage = "$($errorMessageHeader): Expected Update to be a hash table, was " `
                + "actually a $($update.GetType().Fullname)"
            # Don't return with failure just yet, want to log any subsequent errors first.
            $success = $False
            continue
        }

        $errorMessage = (Test-HashTableElement -HashTable $update -KeyName "NodeXPath")
        if ($errorMessage)
        {
            Write-LogMessage "$($errorMessageHeader): $errorMessage" -IsError
            $success = $False
        }

        $errorMessage = (Test-HashTableElement -HashTable $update -KeyName "NewValue")
        if ($errorMessage)
        {
            Write-LogMessage "$($errorMessageHeader): $ErrorMessage" -IsError
            $success = $False
        }
    }

    return $success
}

<#
.SYNOPSIS
Checks that config details have been supplied.

.DESCRIPTION
Checks that config details have been supplied in the correct format.

.PARAMETER ConfigDetails
Details of the updates to apply to a list of config files.
Format: A list of hash tables, one for each config file to update.  Each hash table has three 
elements: 
    1) Name: A string that uniquely identifies the config file.  It can be any text at all;
    2) Path: The full file name, including path, of the config file to update;
    3) Updates: A list of hash tables, one for each update to the config file.  Each hash table 
        has two elements:
            1) NodeXPath: the XPath expression that identifies the XML node to be updated;
            2) NewValue: The new value the XML node will be set to.

.OUTPUTS
Boolean.  Test-ConfigDetail returns $True if the config details are valid, or $False if they 
are not.

.NOTES
#>
function Test-ConfigDetail (
        [Parameter(Mandatory=$True)]
        $ConfigDetails
    )
{
    $overallResult = $True

    foreach ($configDetail in $ConfigDetails)
    {
        $result = (Test-SingleConfigDetail -ConfigDetail $configDetail)
        $overallResult = $overallResult -and $result
    }
    
    return $overallResult
}

<#
.SYNOPSIS
Backs up the config file with the specified path.

.DESCRIPTION
Backs up the config file with the specified path.  The backup file will be saved to the same 
directory as the source file.  The backup will have "_original" appended to the name.  eg 
Source: "web.config"
Backup: "web_original.config"

.PARAMETER ConfigName
A user-friendly name that uniquely identifies a config file to the user.

.PARAMETER ConfigFilePath
The path to the config file to back up.

.PARAMETER LogFileName
The path to the log file that messages are logged to.

.OUTPUTS
string.  Backup-ConfigFile returns an error message if the backup of the config file 
fails.  If the backup file is created successfully Backup-ConfigFile returns $Null.

.NOTES
#>
function Backup-ConfigFile (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$ConfigName,
    
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$ConfigFilePath
    )
{
    $errorMessage = $Null
    $errorMessageHeader = "Unable to back up config file '$ConfigName'..."

    $configDirectory = Split-Path -Path $ConfigFilePath -Parent
    $configFileName = Split-Path -Path $ConfigFilePath -Leaf

    $configFileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($configFileName)
    # Extension will include the leading "."
    $fileExtension = [System.IO.Path]::GetExtension($configFileName)

    $backupFileName = "$($configFileNameWithoutExtension)_orignal" + $fileExtension
    $backupFilePath = Join-Path $configDirectory $backupFileName

    Write-LogMessage "Backing up config file '$ConfigName' to $backupFileName..." -IsDebug

    try
    {
        Copy-Item $ConfigFilePath $backupFilePath
    }
    catch [System.Exception]
    {
        $errorMessage = (Get-ExceptionErrorMessage -Exception $_.Exception `
            -ErrorHeader $errorMessageHeader -AdditionalMessage "Error copying file")

        Write-LogMessage $errorMessage -IsError

        return $errorMessage
    }

    $backupExists = (Test-Path $backupFilePath)
    if (-not $backupExists)
    {
        $errorMessage = "Unknown error backing up config file '$ConfigName' to $backupFileName."
        Write-LogMessage  $errorMessage -IsError 

        return $errorMessage
    }

    Write-LogMessage "Config file '$ConfigName' successfully backed up to $backupFileName." `
        -IsDebug

    return $Null
}

<#
.SYNOPSIS
Updates the specified nodes of the specified config file.

.DESCRIPTION
For the specified config file, checks whether the config file exists and, if it does, sets the 
values of the specified nodes.

This function can be supplied a list of config files to update, via the pipeline.

.PARAMETER ConfigDetail
Details of the updates to apply to a list of config files.
Format: A hash table representing a config file to update.  The hash table has three 
elements: 
    1) Name: A string that uniquely identifies the config file.  It can be any text at all;
    2) Path: The full file name, including path, of the config file to update;
    3) Updates: A list of hash tables, one for each update to the config file.  Each hash table 
        has two elements:
            1) NodeXPath: the XPath expression that identifies the XML node to be updated;
            2) NewValue: The new value the XML node will be set to.

.OUTPUTS
Hash table that has four elements:
    1) Id: A string that uniquely identifies the result in the output pipeline.  In this case the 
        Id will be the Name from the ConfigDetail input parameter;
    2) Success: A boolean that indicates whether the nodes of the specified config files are 
        updated or not;
    3) ErrorMessages: An array of strings.  Each string is an error message.  If all config file 
        nodes are updated succcessfully ErrorMessages should be an empty array;
    4) Value: Not used, set to $Null.

.NOTES
#>
function Update-Config
{
    # CmdletBinding attribute must be on first non-comment line of the function
    # and requires that the parameters be defined via the Param keyword rather 
    # than in parentheses outside the function body.
    [CmdletBinding()]
    Param
    (
        [Parameter(Position=1,
                    Mandatory=$True,
                    ValueFromPipeline=$True)]
        $ConfigDetail
    )

    process
    {
        $configName = $ConfigDetail.Name
        $configFilePath = $ConfigDetail.Path
        $result = @{Id=$configName; Success=$False; ErrorMessages=@(); Value=$Null}
        $errorMessageHeader = "Unable to update config file '$configName'"
        
        Write-LogMessage "Updating config file $configName..." -IsDebug
        
        if (-not (Test-Path $configFilePath))
        {
            $errorMessage = "$($errorMessageHeader): Not found at path '$configFilePath'"

            Write-LogMessage $errorMessage -IsError

            $result.ErrorMessages +=  $errorMessage
            return $result
        }

        Write-LogMessage "Loading XML document..." -IsDebug
        
        $configXmlDocument = New-Object xml
        try
        {
            $configXmlDocument.Load($configFilePath)
            Write-LogMessage "XML document loaded." -IsDebug
        }
        catch [System.Exception]
        {
            $errorMessage = (Get-ExceptionErrorMessage -Exception $_.Exception `
                -ErrorHeader $errorMessageHeader -AdditionalMessage "Error loading XML document")

            Write-LogMessage $errorMessage -IsError

            $result.ErrorMessages +=  $errorMessage
            return $result
        }

        $errorMessageHeader = "Error updating config file '$configName' node"
        foreach($update in $ConfigDetail.Updates)
        {
            $nodeXPath = $update.NodeXPath
            $newValue = $update.NewValue
            Write-LogMessage "Updating node '$nodeXPath'..." -IsDebug

            $node = $Null
            try
            {
                $node = $configXmlDocument.SelectSingleNode($nodeXPath)
            }
            catch [System.Exception]
            {
                $errorMessage = (Get-ExceptionErrorMessage -Exception $_.Exception `
                    -ErrorHeader $errorMessageHeader -AdditionalMessage "Error selecting node '$nodeXPath'")

                Write-LogMessage $errorMessage -IsError

                $result.ErrorMessages +=  $errorMessage
                # Continue on node error, rather than returning, to give us a chance to pick up all the node 
                # errors 
                continue
            }

            if (-not $node)
            {
                $errorMessage = "Node '$nodeXPath' not found in config file."

                Write-LogMessage $errorMessage -IsError

                $result.ErrorMessages +=  $errorMessage
                continue
            }

            $nodeType = $node.NodeType
            if ($nodeType -notin [System.Xml.XmlNodeType]::Attribute, [System.Xml.XmlNodeType]::Element)
            {
                $errorMessage = "Node '$nodeXPath' is of type $nodeType.  " `
                    + "Only node types Attribute and Element are supported."

                Write-LogMessage $errorMessage -IsError

                $result.ErrorMessages +=  $errorMessage
                continue
            }

            if ($nodeType -eq [System.Xml.XmlNodeType]::Attribute)
            {
                $attribute = $node -as [System.Xml.XmlAttribute]
                $attribute.Value = $newValue
            }
            elseif ($nodeType -eq [System.Xml.XmlNodeType]::Element)
            {
                $element = $node -as [System.Xml.XmlElement]
                $element.InnerText = $newValue
            }

            Write-LogMessage "Node value set to '$newValue'." -IsDebug
        }

        if ($result.ErrorMessages)
        {
            $errorMessage = "One or more errors occurred while attempting to update config " `
                + "file '$configName'.  Changes will NOT be saved." 
            Write-LogMessage $errorMessage -IsError

            return $result
        }

        $backupErrorMessage = (Backup-ConfigFile -ConfigName $configName `
            -ConfigFilePath $configFilePath)

        if ($backupErrorMessage)
        {
            $errorMessage = "Backup of config file '$configName' failed.  Changes will NOT  be saved." 
            Write-LogMessage $errorMessage -IsError

            $result.ErrorMessages +=  $backupErrorMessage
            return $result
        }

        Write-LogMessage "Saving updated config file '$configName'..." -IsDebug

        try
        {
            $configXmlDocument.Save($configFilePath)
        }
        catch [System.Exception]
        {
            $errorMessage = (Get-ExceptionErrorMessage -Exception $_.Exception `
                -ErrorHeader $errorMessageHeader -AdditionalMessage "Error saving updated XML document")

            Write-LogMessage $errorMessage -IsError

            $result.ErrorMessages +=  $errorMessage
            return $result
        }

        Write-LogMessage "Updated config file '$configName' saved successfully." -Category Success

        $result.Success = $True

        return $result
    }
}

<#
.SYNOPSIS
Updates the specified nodes of the specified config files.

.DESCRIPTION
Takes a list of config files and the nodes on each to update.  For each config file it checks 
whether the config file exists and, if it does, sets the values of the specified nodes.

.PARAMETER ConfigDetails
Details of the updates to apply to a list of config files.
Format: A list of hash tables, one for each config file to update.  Each hash table has three 
elements: 
    1) Name: A string that uniquely identifies the config file.  It can be any text at all;
    2) Path: The full file name, including path, of the config file to update;
    3) Updates: A list of hash tables, one for each update to the config file.  Each hash table 
        has two elements:
            1) NodeXPath: the XPath expression that identifies the XML node to be updated;
            2) NewValue: The new value the XML node will be set to.

.NOTES
#>
function Update-ConfigFile (
        [Parameter(Mandatory=$True)]
        $ConfigDetails
    )
{
    Clear-Host    
    
    $NL = [Environment]::NewLine

    $numberOfConfigFilesToUpdate = $ConfigDetails.Count

    Write-LogHeader -Title "Updating $numberOfConfigFilesToUpdate config files"

    $success = (Test-ConfigDetail -ConfigDetails $ConfigDetails)
    if (-not $success)
    {
        $resultText = "No config files updated - config details supplied are invalid.$NL" `
            + "For details of the problems search log messages above for the text `"ERROR`"."
        Write-LogFooter -ResultText $resultText -ResultCategory FAILURE           
        return
    }

    $results = ($ConfigDetails | Update-Config)

    #$StatusValue = @{Failure=0; PartialFailure=1; Success=2}

    $resultText = $Null
    $numberOfSuccessfulResults = ($results.Where{$_.Success}).Count
    $resultCategory = 'FAILURE'

    switch ($numberOfSuccessfulResults)
    {
        0                               {
                                            $resultCategory = 'FAILURE'
                                            $resultText = "No config files updated.$NL" `
                                                + "For details of the problems search log messages " `
                                                + "above for the text `"ERROR`"."
                                            break
                                        }
        $numberOfConfigFilesToUpdate    {
                                            $resultCategory = 'SUCCESS'
                                            break
                                        }
        default                         {
                                            $resultCategory = 'PARTIALFAILURE'
                                            $filesText = "config files were"
                                            if ($numberOfSuccessfulResults -eq 1)
                                            {
                                                $filesText = "config file was"
                                            }
                                            $failedIds = $results.Where{-not $_.Success}.ForEach("Id") -join ", "
                                            $resultText = "Only $numberOfSuccessfulResults " `
                                                + "$filesText updated successfully out of " `
                                                + "$numberOfConfigFilesToUpdate.$NL" `
                                                + "Config files that FAILED: $failedIds.$NL" `
                                                + "For details of the problems search log messages " `
                                                + "above for the text `"ERROR`" or `"WARNING`"."
                                            break
                                        }
    }

    Write-LogFooter -ResultText $resultText -ResultCategory $resultCategory
}

Set-LogConfiguration -WriteToHost -LogLevel VERBOSE -LogFileName $_logFileName `
    -OverwriteLogFile:$_overwriteLogFile

Update-ConfigFile -ConfigDetails $_configDetails