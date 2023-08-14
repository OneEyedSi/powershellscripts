<#
.SYNOPSIS
Clones an IIS website.

.DESCRIPTION
Checks if an IIS website with the specified target name exists and, if it doesn't, 
creates it as a copy of the specified source website.  The web applications under 
the source website will be cloned as well.

.NOTES
Must be run with elevated permissions.

Regardless of whether the physical paths of the source web applications are under 
the source website root or not, the cloned web applications will all physically be 
under the cloned website's root folder.  For example, if the root for the cloned 
website is C:\inetpub\uat2 then a source web application which has a physical path 
of C:\Production\MyWebApp will be copied to C:\inetpub\uat2\MyWebApp.  The leaf 
level folder from the source physical path (in this case "MyWebApp") will be 
copied and re-created under the cloned website root folder, along with its 
contents.

If multiple source web applications have different physical paths but the same 
leaf level folder name then the second and subsequent folders will have an index 
number appended to the name to avoid a collision.  For example, if there are 
two source web applications with the following folders:
1) C:\inetpub\test\CustomerA\AccountServices
2) C:\inetpub\test\CustomerB\AccountServices
then they will be cloned as:
1) C:\inetpub\uat2\AccountServices
2) C:\inetpub\uat2\AccountServices2

If there were four source web applications with the same leaf level folder 
names then the third would have "3" appended to the cloned folder name and the 
fourth would have "4" appended to the cloned folder name.  And so on.

A simple index number is used because it's too difficult to parse the source 
folder path and use components of the path to ensure the cloned paths will be 
different, particularly if the two source paths are not under the same root.  
For example:
1) C:\working\test\CustomerA\AccountServices
2) C:\inetpub\wwwroot\AccountServices
#>

Import-Module WebAdministration

$sourceWebsiteName = "Default Web Site"
$targetWebsiteName = "uat2"
$targetRootPath = "C:\inetpub\uat2root"
$targetWebsiteBindingPort = 82

<#
.SYNOPSIS
Writes a message to the host.

.DESCRIPTION
Writes a string to the host in the form of a log message: 
{datetime} | {calling function name} | {message}

.NOTES
{calling function name} will be "----" if the function is 
called from outside another function, at the top level of 
the script.
#>
function Write-LogMessage (
    [Parameter(Mandatory=$True)]
    [AllowEmptyString()]
    [string]$message
    )
{
    $timeText = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
    $callingFunctionName = (Get-Variable MyInvocation -Scope 1).Value.MyCommand.Name

    if (!$callingFunctionName)
    {
        $callingFunctionName = "----"
    }
    
    if ($message)
    {
        $outputMessage = "{0} | {1} | {2}" -f $timeText, $callingFunctionName, $message
    }
    else
    {
         $outputMessage = "{0} |" -f $timeText
    }

    Write-Host $outputMessage
}

<#
.SYNOPSIS
Creates the specified folder, if required.

.DESCRIPTION
Checks if the specified folder exists and, if it doesn't, creates it.
#>
function Set-PhysicalFolder (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$folderPath
    )
{
    Write-LogMessage "Checking if folder $folderPath exists..."
     
    if (Test-Path $folderPath)
    {
        Write-LogMessage "Folder $folderPath found."
        Return
    }

    Write-LogMessage "Folder $folderPath not found.  Creating..."

    New-Item -Path "$folderPath\" -ItemType Directory

    Write-LogMessage "Folder $folderPath has been created."
}

<#
.SYNOPSIS
Creates the specified folder, if required, by copying from a 
specified source folder.

.DESCRIPTION
Checks if the specified target folder exists and, if it doesn't, 
copies the source folder and its contents to the target location.
#>
function Copy-PhysicalFolder (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$sourceFolderPath, 

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$targetFolderPath
    )
{
    Write-LogMessage "Checking if target folder $targetFolderPath exists..."
     
    if (Test-Path $targetFolderPath)
    {
        Write-LogMessage "Target folder $targetFolderPath found."
        Return
    }

    Write-LogMessage "Target folder $targetFolderPath not found."

    Write-LogMessage "Copying from source folder '$sourceFolderPath'..."

    if (!(Test-Path $sourceFolderPath))
    {
        $errorMessage = "Source folder '$sourceFolderPath' not found.  Cannot copy to target folder.  Aborting."
        throw $errorMessage
    }

    Copy-Item $sourceFolderPath $targetFolderPath -recurse

    Write-LogMessage "Target folder $targetFolderPath has been created."
}

<#
.SYNOPSIS
Creates the specified website, if required.

.DESCRIPTION
Checks if an IIS website with the specified name exists and, if it doesn't, 
creates it.  Also creates the physical path, if it doesn't already exist.
#>
function Set-Website (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$websiteName, 

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$targetRootPath, 

    [string]$appPoolName, 
    [string]$ipAddress, 
    [int]$port
    )
{
    Write-LogMessage "Checking if website $websiteName exists..."
     
    if (Test-Path "IIS:\Sites\$websiteName")
    {
        Write-LogMessage "Website $websiteName found."
        Return
    }

    Write-LogMessage "Website $websiteName not found.  Creating..."
    Write-LogMessage ""

    Write-LogMessage "Website name: '$websiteName'; App pool name: '$appPoolName'; IP Address: '$ipAddress'; Port: '$port'"
    Write-LogMessage "Physical path: '$targetRootPath'"
    Write-LogMessage ""

    Write-LogMessage "Setting up physical path '$targetRootPath'..."
    Set-PhysicalFolder $targetRootPath
    Write-LogMessage ""

    Write-LogMessage "Creating website $websiteName..."
    New-Website -Name $websiteName -PhysicalPath $targetRootPath
    Write-LogMessage "Website $websiteName has been created."
    Write-LogMessage ""

    if (!([string]::IsNullOrWhiteSpace($appPoolName)))
    {
        Write-LogMessage "Setting website app pool..."
        $appPoolName = $appPoolName.Trim()
        Set-ItemProperty "IIS:\Sites\$websiteName" ApplicationPool $appPoolName
        Write-LogMessage "Website $websiteName app pool set to $appPoolName."
        Write-LogMessage ""
    }

    if (!([string]::IsNullOrWhiteSpace($ipAddress)))
    {
        Write-LogMessage "Setting website IP address..."
        $ipAddress = $ipAddress.Trim()
        Set-WebBinding -Name $websiteName -BindingInformation "*:80:" -PropertyName IPAddress -Value $ipAddress
        Write-LogMessage "Website $websiteName IP address set to $ipAddress."
        Write-LogMessage ""
    }

    if ($port -gt 0)
    {
        Write-LogMessage "Setting website port..."
        Set-WebBinding -Name $websiteName -BindingInformation "*:80:" -PropertyName Port -Value $port
        Write-LogMessage "Website $websiteName port set to $port."
        Write-LogMessage ""
    }

    Write-LogMessage "Website $websiteName has been created and configured."
}

#<#
#.SYNOPSIS
#Strips the root part from a folder path and replaces it with a different 
#specified root.
##>
#function Get-TargetFolderPath (
#    [Parameter(Mandatory=$True)]
#    [ValidateNotNullOrEmpty()]
#    [string]$sourceFolderPath,
#
#    [Parameter(Mandatory=$True)]
#    [ValidateNotNullOrEmpty()]
#    [string]$targetRootPath
#    )
#{
#    $dirObject = New-Object -TypeName System.IO.DirectoryInfo -ArgumentList $sourceFolderPath
#    # DirectoryInfo.Name will return the last segment of a path, whether it is a file or a 
#    # directory.  Assume that only a path will be supplied.
#    $leafFolderName = $dirObject.Name
#    $targetFolderPath = [io.path]::Combine($targetRootPath, $leafFolderName)
#    return $targetFolderPath
#}

<#
.SYNOPSIS
Gets information about the web application to be copied.

.DESCRIPTION
Gets information about the web application to be copied, and the target folder 
to copy it to.

.NOTES
This function accepts input from the pipeline.  The pipeline parameters are 
bound via name.  This means that any function or cmdlet passing data into 
this function via the pipeline needs output properties whose names match 
those of the pipeline parameters of this function. 

Parameters that don't accept input from the pipeline must come first.
#>
function Get-ApplicationInformation
{
    # CmdletBinding attribute must be on first non-comment line of the function
    # and requires that the parameters be defined via the Param keyword rather 
    # than in parentheses outside the function body.
    [CmdletBinding()]
    Param
    (
        [Parameter(Position=0,
                    Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string]$targetRootPath, 

        [Parameter(Position=1,
                    Mandatory=$True,
                    ValueFromPipelineByPropertyName=$True)]
        [ValidateNotNullOrEmpty()]
        [string]$ApplicationName, 

        [Parameter(Position=2,
                    Mandatory=$True,
                    ValueFromPipelineByPropertyName=$True)]
        [ValidateNotNullOrEmpty()]
        [string]$PhysicalPath,  

        [Parameter(Position=3,
                    Mandatory=$True,
                    ValueFromPipelineByPropertyName=$True)]
        [string]$ApplicationPool
    )

    begin
    {
        $leafFolderNames = @{}
    }

    process
    {
        # Deal with the situation where multiple source web applications have the same 
        # leaf-level folder name.  eg C:\inetpub\test\CustomerA\AccountServices
        # and C:\inetpub\test\CustomerB\AccountServices.  In that case we want to have 
        # different target leaf-level folder names, eg AccountServices and 
        # AccountServices2, since they will be under the same cloned website root folder.

        $sourceFolderPath = $PhysicalPath
        $dirObject = New-Object -TypeName System.IO.DirectoryInfo -ArgumentList $sourceFolderPath
        # DirectoryInfo.Name will return the last segment of a path, whether it is a file or a 
        # directory.  Assume that only a path will be supplied.
        $leafFolderName = $dirObject.Name
        $leafFolderNameCount = 0
        if ($leafFolderNames.ContainsKey($leafFolderName))
        {
            $leafFolderNameCount = $leafFolderNames[$leafFolderName]
        }
        $leafFolderNameCount++
        $leafFolderNames[$leafFolderName] = $leafFolderNameCount

        if ($leafFolderNameCount -gt 1)
        {
            $leafFolderName += $leafFolderNameCount
        }

        $targetFolderPath = [io.path]::Combine($targetRootPath, $leafFolderName)

        $applicationDetails = @{ApplicationName=$ApplicationName; 
                                SourcePath=$sourceFolderPath; 
                                TargetPath=$targetFolderPath
                                ApplicationPool=$ApplicationPool}

        $applicationObject = New-Object -TypeName PSObject
        $applicationObject | Add-Member -NotePropertyMembers $applicationDetails

        Write-Output $applicationObject
    }
}

<#
.SYNOPSIS
Creates the specified web application under the specified website, if required.

.DESCRIPTION
Checks if the specified web application exists under the specified IIS website 
and, if it doesn't, creates it.

.NOTES
The output of Get-ApplicationInformation is piped into this function.  To bind 
the parameters to the properties output by Get-ApplicationInformation the 
parameters must have the same names as the Get-ApplicationInformation output 
properties.

Parameters that don't accept input from the pipeline must come first.
#>
function Set-WebApplication
{    
    # CmdletBinding attribute must be on first non-comment line of the function
    # and requires that the parameters be defined via the Param keyword rather 
    # than in parentheses outside the function body.
    [CmdletBinding()]
    Param
    (
        [Parameter(Position=0,
                    Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string]$websiteName, 

        [Parameter(Position=1,
                    Mandatory=$True,
                    ValueFromPipelineByPropertyName=$True)]
        [ValidateNotNullOrEmpty()]
        [string]$ApplicationName, 

        [Parameter(Position=2,
                    Mandatory=$True,
                    ValueFromPipelineByPropertyName=$True)]
        [ValidateNotNullOrEmpty()]
        [string]$SourcePath, 

        [Parameter(Position=3,
                    Mandatory=$True,
                    ValueFromPipelineByPropertyName=$True)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetPath,  

        [Parameter(Position=4,
                    Mandatory=$True,
                    ValueFromPipelineByPropertyName=$True)]
        [string]$ApplicationPool
    )

    process
    {
        Write-LogMessage "${ApplicationName}: Checking if web application exists under website $websiteName..."
     
        if (Test-Path "IIS:\Sites\$websiteName\$ApplicationName")
        {
            Write-LogMessage "${ApplicationName}: Web application found."
            Write-LogMessage ""
            Return
        }

        Write-LogMessage "${ApplicationName}: Web application not found under website $websiteName.  Creating..."    
        
        Write-LogMessage "${ApplicationName}: Website name: '$websiteName'; Web application name: '$ApplicationName'"
        Write-LogMessage "${ApplicationName}: Source path: '$SourcePath'; Target path: '$TargetPath'; App pool name: '$ApplicationPool'"

        Write-LogMessage "${ApplicationName}: Creating $TargetPath and copying contents from $SourcePath if required..."
        Copy-PhysicalFolder $SourcePath $TargetPath

        Write-LogMessage "${ApplicationName}: Creating web application..."
        New-WebApplication -Site $websiteName -Name $ApplicationName -PhysicalPath $TargetPath -ApplicationPool $ApplicationPool
        Write-LogMessage "${ApplicationName}: Web application has been created."
        Write-LogMessage ""
    }
}

<#
.SYNOPSIS
Copies the web applications from the source website to the target website, if required.

.DESCRIPTION
Gets the web applications under the specified source IIS website, then recreates them 
under the target website, if they don't exist.
#>
function Copy-WebApplication (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$sourceWebsiteName, 

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$targetWebsiteName,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$targetRootPath
    )
{
    Write-LogMessage "Checking if source website $sourceWebsiteName exists..."
     
    if (!(Test-Path "IIS:\Sites\$sourceWebsiteName"))
    {
        throw "Source website $sourceWebsiteName not found."
    }
    
    Write-LogMessage "Source website $sourceWebsiteName found."

    Write-LogMessage "Checking if target website $targetWebsiteName exists..."
     
    if (!(Test-Path "IIS:\Sites\$targetWebsiteName"))
    {
        throw "Target website $targetWebsiteName not found."
    }
    
    Write-LogMessage "Target website $targetWebsiteName found."

    Write-LogMessage "Checking if target root folder $targetRootPath exists..."
     
    if (!(Test-Path $targetRootPath))
    {
        throw "Target root folder $targetRootPath not found."
    }
    
    Write-LogMessage "Target root folder $targetRootPath found."

    Write-LogMessage "Setting web applications of target website..."

    # Get-WebApplication just reads from ApplicationHost.config and is limited to the 
    # properties that appear under the application element in the config.
    #Get-WebApplication -Site $sourceWebsiteName | Set-WebApplication -websiteName $targetWebsiteName -targetRootPath $targetRootPath

    Get-ChildItem -Path "IIS:\Sites\$sourceWebsiteName" `
    | Where-Object  NodeType -eq "application" `
    | Select-Object @{Name="ApplicationName"; Expression={$_.Name}}, PhysicalPath, ApplicationPool `
    | Get-ApplicationInformation -targetRootPath $targetRootPath `
    | Set-WebApplication -websiteName $targetWebsiteName

    Write-LogMessage "Web applications have been set and configured."
}

<#
.SYNOPSIS
Clones the specified source website.

.DESCRIPTION
Checks to see if the target website exists and, if it doesn't, creates it as a 
clone of the source website, with the specified physical path, app pool, etc.
#>
function Copy-Website(
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$sourceWebsiteName, 

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$targetWebsiteName,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$targetRootPath, 

    [string]$targetAppPoolName, 
    [string]$targetIpAddress, 
    [int]$targetPort
    )
{
    Clear-Host

    Set-Website -websiteName $targetWebsiteName `
        -targetRootPath $targetRootPath -appPoolName $targetAppPoolName -ipAddress $targetIpAddress -port $targetPort
    Copy-WebApplication -sourceWebsiteName $sourceWebsiteName `
        -targetWebsiteName $targetWebsiteName -targetRootPath $targetRootPath
}

Copy-Website -sourceWebsiteName $sourceWebsiteName `
    -targetWebsiteName $targetWebsiteName -targetRootPath $targetRootPath `
    -targetPort $targetWebsiteBindingPort