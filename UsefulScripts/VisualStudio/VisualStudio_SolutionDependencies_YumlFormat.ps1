<#
.SYNOPSIS
Generates code for creating a graph of dependencies between projects in a Visual Studio solution.

.DESCRIPTION
Generates code for creating a dependency graph in https://yuml.me.  The graph will show the 
dependencies between the projects in a Visual Studio solution.

In addition to displaying projects, the dependency graph will include other dependencies, such as 
DACPAC files referenced from SQL Server Database projects.  Nodes representing DACPAC files will 
be labelled "filename (DACPAC)".  Nodes representing other files and artifacts will be labelled 
"filename (ARTIFACT)".

The layers in the dependency hierarchy can optionally be colour-coded.  This is useful for large 
solutions to highlight top-level projects, without parents, and bottom-level projects, without 
children.  Projects that share the same level in the hierarchy, counting from the top level 
projects, will share the same colour.  For example, all top level projects will share the same 
colour, then all children of those top level projects will share a different colour, etc.

Setting script variable $_useColours to $true enables the colour-coding of all projects in the 
solution.  If colour-coding is not enabled all projects will be coloured light grey.

For really large solutions even colour-coding the projects may not be enough for easy 
understanding of the dependency graph.  In that case individual projects and the dependency paths 
they belong to can be highlighted in colour, leaving the remaining projects coloured light grey.

To highlight specific projects, add the project names to the list in script variable 
$_projectNamesToHighlight.  Optionally you can set $_highlightNodesAbove or $_highlightNodesBelow 
$true.  When $_highlightNodesAbove is set the selected projects and all projects above them 
in the graph (parents, grandparents, etc) will be highlighted in colour.  When 
$_highlightNodesBelow is set the selected projects and all projects below them 
in the graph (children, grandchildren, etc) will be highlighted in colour.  If neither 
$_highlightNodesAbove nor $_highlightNodesBelow are set then only the projects listed in 
$_projectNamesToHighlight will be highlighted in colour.

When one of more projects are highlighted you can remove clutter by setting script variable 
$_showOnlyHighlightedNodes $true.  In that case all non-highlighted projects are removed from the 
graph, leaving only the highlighted projects.

If projects have been selected for highlighting then script variable $_useColours is ignored: Only 
the projects listed in $_projectNamesToHighlight will be highlighted, along with the projects 
above or below them in the graph if either $_highlightNodesAbove or $_highlightNodesBelow are set.

In addition to highlighting projects with colour, you can use $_showLevelNumbers to add text 
"(level nnn)" to each node, where nnn is the level in the hierarchy, counting from 0 at the 
top-level projects.  

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
Version:		2.1.1 
Date:			9 December 2024

For a generalised script for creating a Yuml.me dependency graph from arbitrary parent-child 
pairs, see DemosAndExperiments/DEMO_Hierarchy_GetYumlCodeForDependencyGraph.ps1 in the 
PowerShell repository.

#>

$_solutionFilePath = "C:\Working\SourceControl\Smartly\API\Integration.sln"

$_projectNamesToHighlight = @('Smartly.Workflow.API'
)                            
$_highlightNodesAbove = $false
$_highlightNodesBelow = $true
$_showOnlyHighlightedNodes = $true

# Ignored if _projectNamesToHighlight set.
$_useColours = $true

# -------------------------------------------------------------------------------------------------
# No changes needed below this point; the remaining code is generic.
# -------------------------------------------------------------------------------------------------

<#
.SYNOPSIS
Returns an absolute path from a path that is either absolute or relative, plus a folder path.
#>
function PipelineGetAbsolutePath
(           
    [Parameter(Position = 0, 
        Mandatory = $true)]
    $FolderPath, 
        
    [Parameter(Position = 1, 
        Mandatory = $true, 
        ValueFromPipeline = $true)]
    $Path
)
{
    begin
    {
        $absolutePaths = @()
    }

    process
    {
        # Path is absolute if it's a named drive (eg starts with "C:\...") 
        # or is an UNC path (starts with "\\...").

        $pathIsAbsolute = ($Path.indexof(':') -gt -1 -or $Path.indexof('\\') -gt -1)

        if ($pathIsAbsolute)
        {
            return $Path
        }

        # Even if path is outside of the solution tree, eg "..\..\..\myproject.csproj", we can still 
        # get the absolute path.
        $absolutePath = join-path $FolderPath $Path -Resolve
        $absolutePaths += $absolutePath
    }

    end
    {    
        return $absolutePaths
    }
}

function NewProjectInfo
(   
    [Parameter(Position = 0, 
        Mandatory = $true)]
    $ProjectName,        
        
    [Parameter(Position = 1, 
        Mandatory = $true)]
    $ProjectFilePath,          
        
    [Parameter(Position = 2, 
        Mandatory = $false)]
    $ProjectId     
)
{
    $projectInfo = @{name = $ProjectName; filePath = $ProjectFilePath; hierarchyLevel = $null; isHighlighted = $false }
    if ($ProjectId)
    {
        $projectInfo.id = $ProjectId
    }

    return $projectInfo
}

<#
.SYNOPSIS
A pipeline function for extracting project information from the solution file.

.DESCRIPTION
Takes a line from the solution file via the pipeline, parses it to extract the project 
information, then adds the project information to a project information array.  Once complete the 
result is an array of hash tables, with each hash table representing information about a project 
in the solution.

.NOTES
A line in the solution file with information about the project will look like:
    Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "Common", "Utilities\Common\Common.csproj", "{B0BF1606-3E49-4AB5-A3E9-039A70C840DC}"

Note the GUID representing the project is the second GUID; the first GUID is common to all 
projects.  Perhaps it represents the solution?

Anyway, we can ignore project GUIDs.  They don't necessarily uniquely identify a project (they can 
be different in project references if a shared project is referenced by projects in different 
solutions - see comments under function PipelineGetProjectDependencies).  Also .NET Core project 
references don't include GUIDs, just the project file paths.
#>
function PipelineGetProjectInfoFromSolutionFile
(    
    [Parameter(Position = 0, 
        Mandatory = $true)]
    $SolutionFileFolderPath,
    
    [Parameter(Position = 1, 
        Mandatory = $true, 
        ValueFromPipeline = $true)]
    $SolutionFileProjectLine
)
{
    begin 
    {
        $multipleProjectInfo = @()
        $projectId = 1
    }

    process
    {
        $lineComponents = $SolutionFileProjectLine.split(',')
        $projectNameRaw = $lineComponents[0].split('=')[1]
        $projectName = $projectNameRaw.trim().replace('"', '')
        $projectFilePath = $lineComponents[1].trim().replace('"', '')
        $projectFilePath = $projectFilePath | PipelineGetAbsolutePath $SolutionFileFolderPath 

        $projectInfo = NewProjectInfo -ProjectName $projectName -ProjectFilePath $projectFilePath -ProjectId $projectId 
        $multipleProjectInfo += $projectInfo
        $projectId++
    }

    end
    {
        return $multipleProjectInfo
    }
}

<#
.SYNOPSIS
Reads the solution file and extracts project info about the projects listed in it.

.NOTES
Excludes lines referencing setup project files (*.vdproj), and device deployment projects 
(*.vddproj), which are not XML.
#>
function GetAllProjectInfo($SolutionFilePath)
{
    $solutionText = Get-Content $SolutionFilePath

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

    $solutionFileFolderPath = Split-Path $SolutionFilePath -Parent
    $allProjectInfo = $matchedLines | PipelineGetProjectInfoFromSolutionFile $solutionFileFolderPath 
    return $allProjectInfo
}

function PipelineGetProjectInfoById 
(
    [Parameter(Position = 0, 
        Mandatory = $true)]
    $AllProjectInfo,
        
    [Parameter(Position = 1, 
        Mandatory = $true, 
        ValueFromPipeline = $true)]
    $ProjectId
)
{
    begin
    {
        $projectsInfo = @()
    }

    process
    {
        $projectInfo = $AllProjectInfo | Where-Object id -eq $ProjectId | Select-Object -First 1
        $projectsInfo += $projectInfo
    }
    
    end
    {
        return $projectsInfo
    }
}

function PipelineGetProjectInfoByName  
(
    [Parameter(Position = 0, 
        Mandatory = $true)]
    $AllProjectInfo,
    
    [Parameter(Position = 1, 
        Mandatory = $true, 
        ValueFromPipeline = $true)]
    $ProjectName
)
{
    begin
    {
        $projectsInfo = @()
    }

    process
    {
        $projectInfo = $AllProjectInfo | Where-Object name -eq $ProjectName | Select-Object -First 1
        $projectsInfo += $projectInfo
    }
    
    end
    {
        return $projectsInfo
    }
}

function GetProjectInfoByPath ($AllProjectInfo, $ProjectFilePath)
{
    return ($AllProjectInfo | Where-Object filePath -eq $ProjectFilePath | Select-Object -First 1)
}

function PipelineGetProjectNameByPath
(    
    [Parameter(Position = 0, 
        Mandatory = $true)]
    $AllProjectInfo,
    
    [Parameter(Position = 1, 
        Mandatory = $true, 
        ValueFromPipeline = $true)]
    $ProjectFilePath
)
{
    begin 
    {
        $multipleProjectNames = @()
    }

    process
    {
        $projectInfo = GetProjectInfoByPath $AllProjectInfo $ProjectFilePath
        $multipleProjectNames += $projectInfo.name
    }

    end
    {
        return $multipleProjectNames
    }
}

function GetPathInfo ($RelativePaths, $ProjectFolderPath, [switch]$IsArtifact)
{    
    # Raw joined paths are not valid, they are of the form: 
    # C:\Working\MySolution\BusinessRules\..\Shared\Shared.csproj
    # So need to resolve them into valid paths.
    $absolutePaths = $RelativePaths | PipelineGetAbsolutePath -FolderPath $ProjectFolderPath
    $pathsInfo = $absolutePaths | Select-Object @{Name = 'Path'; Expression = { $_ } }, @{Name = 'IsArtifact'; Expression = { $IsArtifact } }
    return $pathsInfo
}

function GetProjectInfoFromFilePath ($ProjectFilePath, $NewProjectId, [switch]$IsArtifact)
{
    $projectName = [io.path]::GetFileNameWithoutExtension($ReferencedPath)

    if ($IsArtifact)
    {
        $fileExtension = [io.path]::GetExtension($ReferencedPath)
        $artifactText = if ($fileExtension -eq '.dacpac') { 'DACPAC' } else { 'ARTIFACT' } 
        $projectName = "$projectName ($artifactText)"
    }

    $projectInfo = NewProjectInfo $projectName $ProjectFilePath $NewProjectId

    return $projectInfo
}

<#
.SYNOPSIS
Pipeline function that returns a list of all projects with the projects each one depends on.

.DESCRIPTION
For each $ProjectInfo hash table passed through the pipeline, the function will open the listed 
project file and read the project dependencies from it.  It will then add a hash table to the 
output list, with the project name as the key and the list of referenced projects as the value.

.NOTES
Each project file will be in XML format.  There are slightly different formats for .NET Framework 
and .NET Core.

For .NET Framework the project file will be of the form:

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

For .NET Core / .NET the project file will be of the form:

    <Project Sdk="Microsoft.NET.Sdk.Web">
        :
        :
        <ItemGroup>
            :
            :
            <ProjectReference Include="..\Shared\Shared.csproj" />
            :
            :
        </ItemGroup>
        :
        :
    </Project>
    
Note that for both .NET Framework and .NET Core the ProjectReference element has the same Include 
attribute, with a relative path to the project file being referenced.  .NET Core doesn't have the 
<Name> sub-element or the <Project> sub-element with the GUID, however.

Even if we were confining ourselves to .NET Framework we couldn't determine dependencies using 
user-friendly names (the Name sub-element).  In some solutions the same project may be given 
different names when referenced in multiple other projects.

This seems to be related to which solution the referencing projects are in, if a project in one 
solution references a project in another.

Example:
Two solutions, Solution1 and Solution2.  Solution2 contains a project named Shared which is 
referenced by Project2 in Solution2 and by Project1 in Solution1.  

The reference to Shared by Project2 (which is in the same solution), appears as follows in 
Project2.csproj:

    <ProjectReference Include="..\..\Shared\Shared.csproj">
        <Name>Shared</Name>
        <Project>{E9BA2556-75AC-4679-9FA7-D1C0F46AA7BA}</Project>
        <Package>{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}</Package>
    </ProjectReference> 

Note the value of the Name sub-element: Shared.

The reference to Shared by Project1 (which is in a different solution), appears as follows in 
Project1.csproj:

    <ProjectReference Include="..\..\Solution2\Shared\Shared.csproj">
        <Project>{E9BA2556-75AC-4679-9FA7-D1C0F46AA7BA}</Project>
        <Name>Shared %28Shared\Shared%29</Name>
    </ProjectReference>

Note the value of the Name sub-element here is different: 
Shared %28Shared\Shared%29.

Likewise, for .NET Framework we cannot determine dependencies using project GUIDs.  In some 
solutions the GUID in the project file ProjectReference/Project element does not match the GUID 
for the referenced project in the solution file.

Example:

Shared.proj file:

    <ProjectReference Include="..\..\Utilities\Utilities.csproj">
        <Name>Utilities</Name>
        <Project>{D3459F66-9439-4C4C-933D-CDBF91409AD7}</Project>
        <Package>{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}</Package>
    </ProjectReference> 

while the Utilities project details in the .sln solution file are:

    Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "Utilities", "Utilities\Utilities.csproj", "{2C78DA61-B6EF-4E4E-8FF8-4A95D75C8188}"
        ProjectSection(WebsiteProperties) = preProject
            Debug.AspNetCompiler.Debug = "True"
            Release.AspNetCompiler.Debug = "False"
        EndProjectSection
    EndProject

Note the different GUIDs for the Utility project in the Shared.proj file and the .sln file.

So the only way to reliably link a project to the other projects it references is via the 
filename.  Fortunately this method will work for both .NET Framework and .NET Core.  Both the 
relative paths in the project file and in the solution file will need to be converted to absolute 
paths, to be able to match them.
#>
function PipelineGetProjectRelationship
(    
    [Parameter(Position = 0, 
        Mandatory = $true)]
    $AllProjectInfo,
    
    [Parameter(Position = 1, 
        Mandatory = $true, 
        ValueFromPipeline = $true)]
    $ProjectInfo
)
{
    begin 
    {
        $maxProjectId = $AllProjectInfo | Measure-Object -Property id -Maximum | Select-Object -ExpandProperty Maximum
        $newProjectId = $maxProjectId + 1
        $projectRelationships = @()
    }

    process
    {
        $parentProjectFileName = $ProjectInfo.filePath
        $parentProjectFolderPath = Split-Path $parentProjectFileName -Parent
        $parentProjectId = $ProjectInfo.id

        $xmlDoc = new-object xml
        $xmlDoc.load($parentProjectFileName)

        $referencedPathsInfo = @()

        $referencedRelativePaths = $xmlDoc.Project.ItemGroup.ProjectReference.Include
        if ($referencedRelativePaths)
        {
            $referencedPathsInfo = GetPathInfo -RelativePaths $referencedRelativePaths -ProjectFolderPath $parentProjectFolderPath 
        }

        # Special case for SQL Server Data Tools projects: References to dacpac files:
                
        $referencedRelativePaths = $xmlDoc.Project.ItemGroup.ArtifactReference.Include
        if ($referencedRelativePaths)
        {
            $referencedArtifactsPathsInfo = 
            GetPathInfo -RelativePaths $referencedRelativePaths -ProjectFolderPath $parentProjectFolderPath -IsArtifact
            $referencedPathsInfo += $referencedArtifactsPathsInfo
        }

        foreach ($pathInfo in $referencedPathsInfo)
        {
            $referencedPath = $pathInfo.Path     
            $isArtifact = $pathInfo.IsArtifact       
            $referencedProjectInfo = GetProjectInfoByPath $AllProjectInfo $referencedPath
            if (-not $referencedProjectInfo)
            {
                $newProjectInfo = GetProjectInfoFromFilePath -ProjectFilePath $referencedPath -NewProjectId $newProjectId -IsArtifact:$isArtifact
                $AllProjectInfo += $newProjectInfo
                $referencedProjectInfo = $newProjectInfo
                $newProjectId++
            }

            $relationship = @{parentId = $parentProjectId; childId = $referencedProjectInfo.id }
            $projectRelationships += $relationship
        }
    }

    end
    {
        return $AllProjectInfo, $projectRelationships
    }
}

<#
.SYNOPSIS
Returns an array of the absolulte paths to nswag.json files used by NSwag CodeGen.
#>
function PipelineGetNSwagJsonFilePath 
(    
    [Parameter(Position = 0, 
        Mandatory = $true)]
    $ParentProjectFolderPath,
    
    [Parameter(Position = 1, 
        Mandatory = $true, 
        ValueFromPipeline = $true)]
    $CommandText
)
{
    begin 
    {
        $nSwagRelativeFilePaths = @()
    }

    process
    {
        if (-not $CommandText)
        {
            return
        }

        $commandSegments = $commandText -split ' '
        if (-not $commandSegments -or $commandSegments.Length -lt 3)
        {
            return
        }

        $indexOfRun = [array]::IndexOf($commandSegments, 'run')
        if ($indexOfRun -lt 0)
        {
            return
        }

        $nSwagRelativeFilePaths = @()

        # Scenario 1: Command is of the form "$(nswag exe name) run nswag.json ..."
        # Get the nswag.json filename from the command.
        if ($commandSegments.Length -gt ($indexOfRun + 1))
        {
            $nSwagRelativeFilePath = $commandSegments[$indexOfRun + 1]
            if (-not $nSwagRelativeFilePath)
            {
                return
            }
            
            # Command could be of the form "$(nswag exe name) run /variables:...", without a filename.
            if (-not $nSwagRelativeFilePath.StartsWith('/') -and -not $nSwagRelativeFilePath.StartsWith('--'))
            {
                $nSwagRelativeFilePaths += nSwagRelativeFilePaths
            }
        }

        # Scenario 2: Command is of the form "$(nswag exe name) run" (no file name)
        # One or more nswag.json files will be in project root.
        if (-not $nSwagRelativeFilePaths)
        {
            # Need wildcard in -Path if using Get-ChildItem -Include
            $path = Join-Path $ParentProjectFolderPath '*'
            $nSwagRelativeFilePaths += (Get-ChildItem -Path $path -Include 'nswag.json', '*.nswag' -File)

            if (-not $nSwagRelativeFilePaths)
            {
                return
            }
        }
    }

    end 
    {
        if (-not $nSwagRelativeFilePaths)
        {
            return @()
        }
        $nSwagFilesAbsolutePathsInfo = GetPathInfo -RelativePaths $nSwagRelativeFilePaths `
            -ProjectFolderPath $ParentProjectFolderPath
        return $nSwagFilesAbsolutePathsInfo
    }
}

<#
.SYNOPSIS
Pipeline function that returns a list of NSwag CodeGen projects with the projects each one is 
generating client code for.

.DESCRIPTION
For each $ProjectInfo hash table passed through the pipeline, the function will open the listed 
project file and find the nswag.json or *.nswag file used by NSwag CodeGen.  It will then open 
that JSON file to determine the project NSwag CodeGen is generating client code for.  It will 
then add a hash table to the output list, with the project name as the key and the referenced 
projects as the value.

.NOTES
Each project file will be in XML format.  

The project file will be of the form:

    <Project ...>
        :
        :
        <Target Name="GenerateApiClientSourceCode" BeforeTargets="CoreCompile">
            <Exec Command="$(NSwagExe_Net80) run nswag.json /variables:Configuration=$(Configuration),OutputPath=$(MSBuildThisFileDirectory)" />
            <ItemGroup>
                <Compile Include="$(MSBuildThisFileDirectory)\*.cs" Exclude="@(Compile)" />
            </ItemGroup>
        </Target>
        :
        :
    </Project>

The nswag.json file can use either webApiToOpenApi or aspNetCoreToOpenApi.  The file will be of 
the  form:

    {
        "runtime": "Net70",
        "defaultVariables": null,
        "documentGenerator": {
            "webApiToOpenApi": {
                :
                :
                "assemblyPaths": [
                    "../Core.API/bin/$(Configuration)/net7.0/Core.API.dll"
                ],
                :
                :
            }
        },
        "codeGenerators": {
            "openApiToCSharpClient": {
                :
                :
            }
        }
    }

or of the form:

    {
        "runtime": "Net80",
        "defaultVariables": null,
        "documentGenerator": {
            "aspNetCoreToOpenApi": {
                "project": "../Core.API/Core.API.csproj",
                :
                :
            }
        },
        "codeGenerators": {
            "openApiToCSharpClient": {
                :
                :
            }
        }
    }

The only way to link the NSwag CodeGen project to the projects it is generating code for is by 
extracting the referenced project name from the csproj or DLL filename in the nswag.json file.
#>
function PipelineGetNSwagCodeGenProjectRelationship
(    
    [Parameter(Position = 0, 
        Mandatory = $true)]
    $AllProjectInfo,
    
    [Parameter(Position = 1, 
        Mandatory = $true, 
        ValueFromPipeline = $true)]
    $ProjectInfo
)
{
    begin 
    {
        $maxProjectId = $AllProjectInfo | Measure-Object -Property id -Maximum | Select-Object -ExpandProperty Maximum
        $newProjectId = $maxProjectId + 1
        $projectRelationships = @()
    }

    process
    {
        $parentProjectFileName = $ProjectInfo.filePath
        $parentProjectFolderPath = Split-Path $parentProjectFileName -Parent
        $parentProjectId = $ProjectInfo.id

        $xmlDoc = new-object xml
        $xmlDoc.load($parentProjectFileName)

        $referencedPathsInfo = @()

        $commandsText = $xmlDoc.Project.Target.Exec.Command

        if (-not $commandsText)
        {
            return
        }

        if (-not $commandsText -is [array])
        {
            $commandsText = @($commandsText)
        }
        
        $nSwagFilesAbsolutePathsInfo = $commandsText | 
        PipelineGetNSwagJsonFilePath $ParentProjectFolderPath

        if (-not $nSwagFilesAbsolutePathsInfo)
        {
            return
        }

        # if ($commandsText)
        # {

        #     $referencedPathsInfo = GetPathInfo -RelativePaths $referencedRelativePaths -ProjectFolderPath $parentProjectFolderPath 
        # }

        foreach ($pathInfo in $referencedPathsInfo)
        {
            $referencedPath = $pathInfo.Path     
            $isArtifact = $pathInfo.IsArtifact       
            $referencedProjectInfo = GetProjectInfoByPath $AllProjectInfo $referencedPath
            if (-not $referencedProjectInfo)
            {
                $newProjectInfo = GetProjectInfoFromFilePath -ProjectFilePath $referencedPath -NewProjectId $newProjectId -IsArtifact:$isArtifact
                $AllProjectInfo += $newProjectInfo
                $referencedProjectInfo = $newProjectInfo
                $newProjectId++
            }

            $relationship = @{parentId = $parentProjectId; childId = $referencedProjectInfo.id }
            $projectRelationships += $relationship
        }
    }

    end
    {
        return $AllProjectInfo, $projectRelationships
    }
}

function GetHierarchyLevelColour($LevelNumber)
{
    $colours = @('magenta', 'mediumblue', 'cyan', `
            'lawngreen', 'yellow', 'darkorange', 'red', 'brown')

    $numberColours = $colours.Count
    $colourIndex = $LevelNumber % $numberColours
    $colour = $colours[$colourIndex]
    return $colour
}

function SetHierarchyLevels ($AllProjectInfo, $AllProjectRelationships)
{
    $maxHierarchyLevel = 50
    $workingLevel = 0
    $workingRelationships = $AllProjectRelationships.Clone()
    $parentIds = $workingRelationships | Select-Object -ExpandProperty parentId -Unique
    $childIds = $workingRelationships | Select-Object -ExpandProperty childId -Unique

    while ($parentIds.Length -gt 0 -and $workingLevel -le $maxHierarchyLevel)
    {
        $orphanIds = $parentIds | Where-Object { $_ -notin $childIds }
        if ($orphanIds)
        {
            $orphanIds | 
            PipelineGetProjectInfoById -AllProjectInfo $AllProjectInfo |
            ForEach-Object { $_.hierarchyLevel = $workingLevel }

            $parentIds = $parentIds | Where-Object { $_ -notin $orphanIds }
            
            # Children of the projects at the current hierarchy level which have no children of their own:
            # Set their hierarchy level one higher than the current level.
            $orphanChildIds = $workingRelationships | 
            Where-Object { $_.parentId -in $orphanIds } | 
            Select-Object -ExpandProperty childId -Unique | 
            Where-Object { $_ -notin $parentIds }

            if ($orphanChildIds)
            {
                $orphanChildIds | 
                PipelineGetProjectInfoById -AllProjectInfo $AllProjectInfo |
                ForEach-Object { $_.hierarchyLevel = $workingLevel + 1 }
            }

            $workingRelationships = $workingRelationships | Where-Object { $_.parentId -notin $orphanIds }
            $childIds = $workingRelationships | Select-Object -ExpandProperty childId -Unique
        }
        $workingLevel++
    }
}

function PipelineGetAncestor 
(    
    [Parameter(Position = 0, 
        Mandatory = $true)]
    $AllProjectInfo,

    [Parameter(Position = 1, 
        Mandatory = $true)]
    $AllProjectRelationships,

    [Parameter(Position = 2, 
        Mandatory = $true, 
        ValueFromPipeline = $true)]
    $ProjectInfo
)
{
    begin
    {
        $ancestorProjectsInfo = @()
    }

    process
    {
        $projectId = $ProjectInfo.id
        $parentIds = $AllProjectRelationships | 
        Where-Object { $_.childId -eq $projectId } | 
        Select-Object -ExpandProperty parentId
        $parentProjectsInfo = $AllProjectInfo | Where-Object { $parentIds -contains $_.id }

        if ($parentProjectsInfo)
        {
            $ancestorProjectsInfo += $parentProjectsInfo
            $higherLevelProjectsInfo = $parentProjectsInfo | PipelineGetAncestor $AllProjectInfo $AllProjectRelationships
            $ancestorProjectsInfo += $higherLevelProjectsInfo
        }
    }
    
    end
    {
        $ancestorProjectIds = $ancestorProjectsInfo | Select-Object -ExpandProperty id -Unique
        $ancestorProjectsInfo = $AllProjectInfo | Where-Object { $ancestorProjectIds -contains $_.id }
        return $ancestorProjectsInfo
    }
}

function PipelineGetDescendant
(    
    [Parameter(Position = 0, 
        Mandatory = $true)]
    $AllProjectInfo,

    [Parameter(Position = 1, 
        Mandatory = $true)]
    $AllProjectRelationships,

    [Parameter(Position = 2, 
        Mandatory = $true, 
        ValueFromPipeline = $true)]
    $ProjectInfo
)
{
    begin
    {
        $descendantProjectsInfo = @()
    }

    process
    {
        $projectId = $ProjectInfo.id
        $childIds = $AllProjectRelationships | 
        Where-Object { $_.parentId -eq $projectId } | 
        Select-Object -ExpandProperty childId
        $childProjectsInfo = $AllProjectInfo | Where-Object { $childIds -contains $_.id }

        if ($childProjectsInfo)
        {
            $descendantProjectsInfo += $childProjectsInfo
            $lowerLevelProjectsInfo = $childProjectsInfo | PipelineGetDescendant $AllProjectInfo $AllProjectRelationships
            $descendantProjectsInfo += $lowerLevelProjectsInfo
        }
    }
    
    end
    {
        $descendantProjectIds = $descendantProjectsInfo | Select-Object -ExpandProperty id -Unique
        $descendantProjectsInfo = $AllProjectInfo | Where-Object { $descendantProjectIds -contains $_.id }
        return $descendantProjectsInfo
    }
}

function SetProjectHighlight ($AllProjectInfo, $AllProjectRelationships, $ProjectNamesToHighlight, 
    [bool]$HighlightNodesAbove, [bool]$HighlightNodesBelow)
{
    if (-not $AllProjectInfo -or -not $AllProjectRelationships -or -not $ProjectNamesToHighlight)
    {
        return
    }

    $workingProjectsInfo = $ProjectNamesToHighlight | PipelineGetProjectInfoByName $AllProjectInfo
    $projectsInfoToHighlight = @()
    if ($HighlightNodesAbove)
    {
        $ancestorProjectsInfo = $workingProjectsInfo | PipelineGetAncestor $AllProjectInfo $AllProjectRelationships
        $projectsInfoToHighlight += $ancestorProjectsInfo
    }
    if ($HighlightNodesBelow)
    {
        $descendantProjectsInfo = $workingProjectsInfo | PipelineGetDescendant $AllProjectInfo $AllProjectRelationships
        $projectsInfoToHighlight += $descendantProjectsInfo
    }

    $projectsInfoToHighlight += $workingProjectsInfo

    if ($projectsInfoToHighlight)
    {
        $projectsInfoToHighlight.ForEach{ $_.isHighlighted = $true }
    }
}

function GetIsolatedProjectInfo ($AllProjectInfo, $AllProjectRelationships)
{
    $parentIds = @($AllProjectRelationships | Select-Object -ExpandProperty parentId)
    $childIds = @($AllProjectRelationships | Select-Object -ExpandProperty childId)

    $allProjectIdsInRelationships = ($parentIds += $childIds) | Select-Object -Unique

    $isolatedProjectsInfo = $AllProjectInfo | Where-Object { $_.id -notin $allProjectIdsInRelationships } 
    return $isolatedProjectsInfo
}

function PipelineGetYumlNode 
(    
    [Parameter(Position = 0, 
        Mandatory = $true, 
        ValueFromPipeline = $true)]
    $ProjectInfo
)
{
    begin
    {
        $nodes = @()
    }

    process
    {
        $name = $ProjectInfo.name
        $isHighlighted = $ProjectInfo.isHighlighted
        $hierarchyLevel = $ProjectInfo.hierarchyLevel

        $node = "[$name]"
        if ($isHighlighted)
        {
            $colour = GetHierarchyLevelColour $hierarchyLevel
            $node = "[$name{bg:$colour}]"
        }

        $nodes += $node
    }

    end
    {
        return $nodes
    }
}

function PipelineGetYumlRelationship
(    
    [Parameter(Position = 0, 
        Mandatory = $true)]
    $AllProjectInfo,

    [Parameter(Position = 1, 
        Mandatory = $true, 
        ValueFromPipeline = $true)]
    $ProjectRelationship
)
{
    begin
    {
        $relationships = @()
    }

    process
    {
        $parentInfo = $ProjectRelationship.parentId | PipelineGetProjectInfoById -AllProjectInfo $AllProjectInfo 
        $childInfo = $ProjectRelationship.childId | PipelineGetProjectInfoById -AllProjectInfo $AllProjectInfo

        # Parent or child info may be null if $AllProjectInfo is filtered to only include highlighted nodes.
        if (-not $parentInfo -or -not $childInfo)
        {
            return
        }

        $parentNode = $parentInfo | PipelineGetYumlNode 
        $childNode = $childInfo | PipelineGetYumlNode 
        $relationship = "$parentNode->$childNode"
        $relationships += $relationship
    }

    end
    {
        return $relationships
    }
}

function GenerateProjectDependencyGraph($SolutionFilePath, $ProjectNamesToHighlight, 
    [bool]$HighlightNodesAbove, [bool]$HighlightNodesBelow, [bool]$ShowOnlyHighlightedNodes, 
    [bool]$UseColours)
{
    $allProjectInfo = GetAllProjectInfo $SolutionFilePath

    $allProjectInfo, $allProjectRelationships = $allProjectInfo | PipelineGetProjectRelationship $allProjectInfo
    SetHierarchyLevels $allProjectInfo $allProjectRelationships

    # Projects that do not depend on other projects and do not have other projects depend on them.
    $isolatedProjectsInfo = GetIsolatedProjectInfo $allProjectInfo $allProjectRelationships
    if ($isolatedProjectsInfo)
    {
        $isolatedProjectsInfo.ForEach{ $_.hierarchyLevel = 0 }
    }

    if ($ProjectNamesToHighlight)
    {
        SetProjectHighlight $allProjectInfo $allProjectRelationships $ProjectNamesToHighlight `
            $HighlightNodesAbove $HighlightNodesBelow
    }
    elseif ($UseColours)
    {
        $allProjectInfo.ForEach{ $_.isHighlighted = $true }
    }

    if ($ProjectNamesToHighlight -and $ShowOnlyHighlightedNodes)
    {
        $allProjectInfo = $allProjectInfo | Where-Object { $_.isHighlighted }

        # If neither $HighlightNodesAbove nor $HighlightNodesBelow are set then only the highlighted 
        # nodes will be displayed.  Ensure they are included in the isolated projects because they 
        # won't appear in the relationships (since no relationships will be included).
        if (-not $HighlightNodesAbove -and -not $HighlightNodesBelow)
        {
            $isolatedProjectsInfo = $allProjectInfo
        }
        else 
        {
            $isolatedProjectsInfo = $isolatedProjectsInfo | Where-Object { $_.isHighlighted }
        }
    }

    $isolatedProjectNodes = $isolatedProjectsInfo | PipelineGetYumlNode

    $dependencyGraph = @()
    $dependencyGraph += $isolatedProjectNodes

    $relationships = $allProjectRelationships | PipelineGetYumlRelationship $allProjectInfo
    $dependencyGraph += $relationships

    return $dependencyGraph
}

Clear-Host
GenerateProjectDependencyGraph $_solutionFilePath $_projectNamesToHighlight `
    $_highlightNodesAbove $_highlightNodesBelow $_showOnlyHighlightedNodes $_useColours