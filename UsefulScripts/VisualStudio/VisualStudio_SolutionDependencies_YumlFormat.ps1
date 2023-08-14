function GetAbsolutePath($path, $solutionFileFolderPath)
{
    # Path is absolute if it's a named drive (eg starts with "C:\...") 
    # or is an UNC path (starts with "\\...").

    $pathIsAbsolute = ($path.indexof(':') -gt -1 -or $path.indexof('\\') -gt -1)
    if (-not $pathIsAbsolute)
    {
        # Even if path is outside of the solution tree, 
        # eg "..\..\..\myproject.csproj", we can still get 
        # the absolute path.
        $path = [System.IO.Path]::GetFullPath((join-path $solutionFileFolderPath $path))
    } 

    return $path
}

function GetProjectInfo
    (    
    [Parameter(Position=0, 
        Mandatory=$true)]
    $solutionFileFolderPath,
    
    [Parameter(Position=1, 
        Mandatory=$true, 
        ValueFromPipeline=$true)]
    $solutionFileProjectLine
    )
{
    # Line in the solution file with information about the project will look like:
    # Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "Common", "Utilities\Common\Common.csproj", "{B0BF1606-3E49-4AB5-A3E9-039A70C840DC}"

    # Note the GUID representing the project is the second GUID; the first GUID 
    # is common to all projects.  Perhaps it represents the solution?

    begin 
    {
        $multipleProjectInfo = @()
    }

    process
    {
        $lineComponents = $solutionFileProjectLine.split(',')
        $projectNameRaw = $lineComponents[0].split('=')[1]
        $projectName = $projectNameRaw.trim().replace('"', '')
        $projectFilePath = $lineComponents[1].trim().replace('"', '')
        $projectFilePath = GetAbsolutePath $projectFilePath $solutionFileFolderPath
        $projectGuidRaw = $lineComponents[2].trim()
        $projectGuid = $projectGuidRaw.replace('"', '').replace('{', '').replace('}', '')

        $projectInfo = @{name=$projectName; filePath=$projectFilePath; guid=$projectGuid}
        $multipleProjectInfo += $projectInfo
    }

    end
    {
        return $multipleProjectInfo
    }
}

function GetAllProjectInfo($solutionFilePath)
{
    $solutionText = Get-Content $solutionFilePath

    # Get the lines in the solution file that point to project files.
    # Exclude setup project files (*.vdproj), and device deployment projects (*.vddproj) 
    # which are not XML.

    # Regex expression: 
    #    Match text that starts with ", 
    #    followed by 1 or more characters (any character except newline), 
    #    followed by a full stop, 
    #    NOT followed by 'vd',
    #    followed by 0 or more characters (any character except newline), 
    #    followed by 'proj',
    #    followed by "
    $matchedLines = $solutionText -match '".+[.](?!vd).*proj"'
    
    if ($matchedLines.Count -eq 0)
    {
        return @()
    }

    $solutionFileFolderPath = Split-Path $solutionFilePath -Parent
    $allProjectInfo = $matchedLines | GetProjectInfo $solutionFileFolderPath 
    return $allProjectInfo
}

function GetProjectNameByPath
    (    
    [Parameter(Position=0, 
        Mandatory=$true)]
    $allProjectInfo,
    
    [Parameter(Position=1, 
        Mandatory=$true, 
        ValueFromPipeline=$true)]
    $projectFilePath
    )
{
    begin 
    {
        $multipleProjectNames = @()
    }

    process
    {
        $ProjectName = ($allProjectInfo | Where-Object filePath -eq $projectFilePath).name
        $multipleProjectNames += $ProjectName
    }

    end
    {
        return $multipleProjectNames
    }
}

function GetArtifactProjectNameFromPath($ReferencedPath)
{
    $projectName = [io.path]::GetFileNameWithoutExtension($ReferencedPath)
    $fileExtension = [io.path]::GetExtension($ReferencedPath)

    $artifactText = 'ARTIFACT'
    if ($fileExtension -eq '.dacpac')
    {
        $artifactText = 'DACPAC'
    }

    return "$projectName ($artifactText)"
}

function GetProjectDependencies
    (    
    [Parameter(Position=0, 
        Mandatory=$true)]
    $allProjectInfo,
    
    [Parameter(Position=1, 
        Mandatory=$true, 
        ValueFromPipeline=$true)]
    $projectInfo
    )
{
    # Project file will be XML, of the form:
    <#
        <Project DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
            :
            :
            <ItemGroup>
                :
                :
                <ProjectReference Include="..\Shared\Shared.csproj">
                    <Name>Shared</Name>
                    <Project>{D3459F66-9439-4C4C-933D-CDBF91409AD7}</Project>
                    <Package>{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}</Package>
                </ProjectReference>
                :
                :
            </ItemGroup>
            :
            :
        </Project>
    #>

    # Can't determine dependencies using user-friendly names.  In some 
    # solutions the same project may be given different names when 
    # referenced in multiple other projects.
    #
    # This seems to be related to which solution the referencing projects 
    # are in, if a project in one solution references a project in another.
    #
    # eg Two solutions, Solution1 and Solution2.  Solution2 contains a 
    # project named Shared which is referenced by Project2 in Solution2 and 
    # by Project1 in Solution1.  
    #
    # The reference to Shared by Project2 (which is in the same solution), 
    # appears as follows in Project2.csproj:
    #    <ProjectReference Include="..\..\Shared\Shared.csproj">
    #      <Name>Shared</Name>
    #      <Project>{E9BA2556-75AC-4679-9FA7-D1C0F46AA7BA}</Project>
    #      <Package>{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}</Package>
    #    </ProjectReference> 
    #
    # The reference to Shared by Project1 (which is in a different 
    # solution), appears as follows in Project1.csproj:
    #    <ProjectReference Include="..\..\Solution2\Shared\Shared.csproj">
    #      <Project>{E9BA2556-75AC-4679-9FA7-D1C0F46AA7BA}</Project>
    #      <Name>Shared %28Shared\Shared%29</Name>
    #    </ProjectReference>
    #
    # Note the different names in the two ProjectReferences.

    # Likewise, cannot determine dependencies using project GUIDs.  In some 
    # solutions the GUID in the project file ProjectReference/Project element 
    # does not match the GUID for the referenced project in the solution file.
    #
    # eg Shared.proj file:
    #    <ProjectReference Include="..\..\Utilities\Utilities.csproj">
    #      <Name>Utilities</Name>
    #      <Project>{D3459F66-9439-4C4C-933D-CDBF91409AD7}</Project>
    #      <Package>{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}</Package>
    #    </ProjectReference> 
    #
    # while the Utilities project details in the .sln solution file are:
    #    Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "Utilities", "Utilities\Utilities.csproj", "{2C78DA61-B6EF-4E4E-8FF8-4A95D75C8188}"
	#        ProjectSection(WebsiteProperties) = preProject
	#        	 Debug.AspNetCompiler.Debug = "True"
	#        	 Release.AspNetCompiler.Debug = "False"
	#        EndProjectSection
    #    EndProject
    #
    # Note the different GUIDs for the Utility project in the Shared.proj
    # file and the .sln file.

    # So the only way to reliably link a project to the other projects it 
    # references is via the filename.  Both the relative paths in the 
    # project file and in the solution file will need to be converted to 
    # absolute paths, to be able to match them.

    begin 
    {
        $multipleProjectDependencies = @{}
    }

    process
    {
        $projectFileName = $projectInfo.filePath
        $xmlDoc = new-object xml
        $xmlDoc.load($projectFileName)
        $referencedRelativePaths = $xmlDoc.Project.ItemGroup.ProjectReference.Include

        $projectFolderPath = Split-Path $projectFileName -Parent
        # Raw joined paths are not valid, they are of the form: 
        # C:\Working\MySolution\BusinessRules\..\Shared\Shared.csproj
        # So need to resolve them into valid paths.
        $referencedAbsolutePaths = $referencedRelativePaths | 
            Select-Object @{Name='ChildPath';Expression={$_}} | 
            Join-Path $projectFolderPath -Resolve
    
        $referencedProjectNames = $referencedAbsolutePaths | GetProjectNameByPath $allProjectInfo
        
        # Special case for SQL Server Data Tools projects: References to dacpac files:
                
        $referencedRelativePaths = $xmlDoc.Project.ItemGroup.ArtifactReference.Include
        $referencedAbsolutePaths = $referencedRelativePaths | 
            Select-Object @{Name='ChildPath';Expression={$_}} | 
            Join-Path $projectFolderPath -Resolve

        $referencedProjectNames += ($referencedAbsolutePaths | 
                                    ForEach-Object {GetArtifactProjectNameFromPath $_})

        $projectDetails = @{hierarchyLevel=$null;dependencies=$referencedProjectNames}
        $multipleProjectDependencies.Add($projectInfo.name, $projectDetails)
    }

    end
    {
        return $multipleProjectDependencies
    }
}

function RecordProjectHierarchy($allProjectDependencies)
{
    $levelNumber = 0
    $numberProjectsFound = 999
    while ($numberProjectsFound -gt 0)
    {
        # Have to explicitly set data type as string array, otherwise variable 
        # can decide it's a simple string instead, and concatenate 
        # dependencies to the end of the string instead of adding them to the 
        # array.
        [string[]]$projectDependenciesList = $()
        $allProjectDependencies.Values | 
            Where-Object {$_.hierarchyLevel -eq $null} | 
            ForEach-Object {$projectDependenciesList += $_.dependencies}
        $projectDependenciesList = $projectDependenciesList | Select-Object -Unique

        $allProjectDependencies.GetEnumerator() | 
            Where-Object {$_.value.hierarchyLevel -eq $null `
                            -and $_.key -NotIn $projectDependenciesList} | 
            ForEach-Object {$_.value.hierarchyLevel = $levelNumber}
        $measureInfo = $allProjectDependencies.GetEnumerator() | 
            Where-Object {$_.value.hierarchyLevel -eq $levelNumber} | 
            Measure-Object
        $numberProjectsFound = $measureInfo.Count

        $levelNumber += 1
    }
}

<#
.SYNOPSIS
Adds referenced artifacts, such as DACPAC files, to the project list.

.DESCRIPTION
Adds referenced artifacts, such as DACPAC files, to the project list to ensure they will have the 
correct colours set.
#>
function AddReferencedArtifacts($allProjectDependencies)
{
    # Have to explicitly set data type as string array, otherwise variable 
    # can decide it's a simple string instead, and concatenate 
    # dependencies to the end of the string instead of adding them to the 
    # array.
    [string[]]$projectDependenciesList = $()
    $allProjectDependencies.Values | 
        Where-Object {$_.hierarchyLevel -eq $null} | 
        ForEach-Object {$projectDependenciesList += $_.dependencies}
    $projectDependenciesList | 
        Where-Object {$_ -like '*(ARTIFACT)*' -or $_ -like '*(DACPAC)*'} | 
        Select-Object -Unique | 
        ForEach-Object {$allProjectDependencies.Add($_, @{hierarchyLevel=$null;dependencies=@()})}
}

function GetHierarchyLevelColour($levelNumber)
{
    $colours = @('magenta', 'mediumblue', 'cyan', `
        'lawngreen', 'yellow', 'darkorange', 'red', 'brown')

    $numberColours = $colours.Count
    $colourIndex = $levelNumber % $numberColours
    $colour = $colours[$colourIndex]
    return $colour
}

function GenerateProjectDependencyGraph($solutionFilePath, $useColours)
{
    $allProjectInfo = GetAllProjectInfo $solutionFilePath
    $allProjectDependencies = $allProjectInfo | GetProjectDependencies $allProjectInfo
    AddReferencedArtifacts $allProjectDependencies
    RecordProjectHierarchy $allProjectDependencies

    $graphs = @()
    foreach ($key in $allProjectDependencies.Keys)
    {
        $projectDetails = $allProjectDependencies[$key]
        $nodeColour = GetHierarchyLevelColour $projectDetails.hierarchyLevel

        # Orphaned projects that do not depend on other projects and do not have other projects 
        #   depend on them.
        if ($projectDetails.hierarchyLevel -eq 0 -and -not $projectDetails.dependencies)
        {
            if ($useColours)
            {
                $graphs += "[$key{bg:$nodeColour}]"
            }
            else
            {
                $graphs += "[$key]"
            }
        }
        # Projects that are part of a hierarchy.
        else
        {
            foreach ($dependency in $projectDetails.dependencies)
            {
                if ($useColours)
                {
                    $childProjectDetails = $allProjectDependencies[$dependency]
                    $childColour = GetHierarchyLevelColour $childProjectDetails.hierarchyLevel

                    $graphs += "[$key{bg:$nodeColour}]->[$dependency{bg:$childColour}]"
                }
                else
                {
                    $graphs += "[$key]->[$dependency]"
                }
            }
        }
    }

    return $graphs
}

$solutionFilePath = "C:\Working\OnlineAPITest\ForteTMS.sln"
$useColours = $true
Clear-Host
GenerateProjectDependencyGraph $solutionFilePath $useColours