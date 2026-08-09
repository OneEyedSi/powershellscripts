<#
.SYNOPSIS
Generates code for creating a graph of dependencies between projects in a Visual Studio solution.

.DESCRIPTION
Generates code for creating a dependency graph in either YUML (https://yuml.me) or Mermaid format.  
The graph will show the dependencies between the projects in a Visual Studio solution.

In addition to displaying projects, the dependency graph will include other dependencies, such as 
DACPAC files referenced from SQL Server Database projects.  Nodes representing DACPAC files will 
be labelled "filename (DACPAC)".  Nodes representing other files and artifacts will be labelled 
"filename (ARTIFACT)". 

The layers in the dependency hierarchy can optionally be colour-coded.  This is useful for large 
solutions to highlight top-level projects, without parents, and bottom-level projects, without 
children.  Projects that share the same level in the hierarchy, counting from the top level 
projects, will share the same colour.  For example, all top level projects will share the same 
colour, then all children of those top level projects will share a different colour, etc.

For really large solutions even colour-coding the project nodes may not be enough for easy 
understanding of the dependency graph.  In that case individual project nodes and the dependency 
paths they belong to can be highlighted in colour, leaving the remaining project nodes in the 
default colour.

To further simplify a complex dependency graph, the graph can be filtered to show only the 
highlighted project nodes and the dependency paths they belong to, removing all other project 
nodes from the graph.

RUNNING THE SCRIPT:
Either:
1. From the PowerShell console:
    Open a PowerShell 7.0 or later console, navigate to the folder containing the script, then run 
    the script, specifying at least the -SolutionFilePath and the -Format parameter values.  
    For example:
    .\VisualStudio_SolutionDependencies.ps1 -SolutionFilePath "C:\SourceControl\Web\MyWebsite.sln" -Format "YUML"

2. Inside an editor, such as Visual Studio Code or PowerShell ISE:
    Open the script file in the editor.  Ignore the parameters in the Param block, and 
    instead set the default variables immediately below the Param() block.  Set the default 
    variables for at least the solution file path and the output format, and optionally for the 
    other default variables as well.  Then run the script.  The output will be displayed in the 
    editor terminal window.

    NOTE: The reason the parameters are ignored when running the script inside an editor is that 
    it's not possible to set default values for switch parameters.  The alternative, boolean 
    parameters, are too awkward to call when running the script from the command line, and users 
    would expect switch parameters rather than boolean parameters.  So the default variables were 
    added to allow the script to be run inside an editor.

Once the script has been run, copy and paste the output code into the YUML or Mermaid editor to 
generate the dependency graph.

.PARAMETER SolutionFilePath
The path to the Visual Studio solution file to analyse.

.PARAMETER Format
Determines the format of the output code.  Valid values are: 
- "YUML"
- "MERMAID".

.PARAMETER ShowTargetFrameworks
Includes the .NET target framework(s) for each project in the dependency graph.

.PARAMETER UseColours
Displays the project nodes in the dependency graph in different colours, based on their level in 
the dependency hierarchy.  Top level projects (without parents) will be displayed in one colour, 
the children of those top level projects will be displayed in a different colour, and so on.

If a project node has multiple parents at different levels in the hierarchy, it will have the 
colour associated with the longest path from a top level project to that project node.  For 
example, if a project node has one parent at level 1 and another parent at level 3, the project 
node will be displayed in the colour associated with level 4 (the longest path from a top level 
project to that project node).

.PARAMETER ProjectNamesToHighlight
Comma-separated list of project names to highlight in colour.  All other project nodes will be 
displayed in the default colour of the renderer.

If this parameter is specified then parameter UseColours is ignored.

.PARAMETER HighlightNodesAbove
Highlights all project nodes in the dependency graph above the projects listed in 
ProjectNamesToHighlight.  In other words, it highlights the projects referencing the projects 
listed in ProjectNamesToHighlight, and the projects referencing those projects, etc.

.PARAMETER HighlightNodesBelow
Highlights all project nodes in the dependency graph below the projects listed in 
ProjectNamesToHighlight.  In other words, it highlights the projects referenced by the projects 
listed in ProjectNamesToHighlight, and the projects referenced by those projects, etc.

.PARAMETER ShowOnlyHighlightedNodes
Includes only the highlighted project nodes in the dependency graph.  All other nodes are removed 
from the graph.  Used to reduce clutter in the graph for large solutions, when only a few projects 
are of interest.

If ProjectNamesToHighlight is not set and UseColours is set then all project nodes will be 
highlighted, so this parameter will have no effect.

If ProjectNamesToHighlight is set then only the projects listed in ProjectNamesToHighlight will be 
highlighted, along with the nodes above or below them in the graph if either HighlightNodesAbove 
or HighlightNodesBelow are set.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 7.0
Version:		5.0.0
Date:			8 Aug 2026

For a generalised script for creating a YUML dependency graph from arbitrary parent-child 
pairs, see DemosAndExperiments/DEMO_Hierarchy_GetYumlCodeForDependencyGraph.ps1 in the 
PowerShell repository.

Why the script requires PowerShell 7.0 or later:

Using Measure-Object to measure hashtables was introduced in PowerShell 6.  It's used in 
function PipelineGetProjectRelationship to get the maximum project Id.  In PowerShell 5.1 
Measure-Object can only be used to measure PS object properties, not hashtables.

string.ReplaceLineEndings() was introduced in PowerShell 7.  The script uses 
string.ReplaceLineEndings() to normalise line endings in the generated YUML or Mermaid code.

#>

Param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$SolutionFilePath,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Format,

    [Parameter(Mandatory = $false)]
    [switch]$ShowTargetFrameworks,

    [Parameter(Mandatory = $false)]
    [switch]$UseColours,

    [Parameter(Mandatory = $false, ParameterSetName = "HighlightNamedNodesOnly")]
    [array]$ProjectNamesToHighlight,

    [Parameter(Mandatory = $false, ParameterSetName = "HighlightNamedNodesOnly")]
    [switch]$HighlightNodesAbove,

    [Parameter(Mandatory = $false, ParameterSetName = "HighlightNamedNodesOnly")]
    [switch]$HighlightNodesBelow,

    [Parameter(Mandatory = $false, ParameterSetName = "HighlightNamedNodesOnly")]
    [switch]$ShowOnlyHighlightedNodes
)

# Set these default variables when running the script in an editor, like Visual Studio Code.
# Using these default variables gets around the limitation that the switch parameters in the 
# Param() block cannot have default values set.
# When running the script from the command line, the parameter values set in the command line 
# will be used and these default variables will be ignored, even if set.
$_solutionFilePathDefault = "C:\Working\SourceControl\Test.sln"
#Valid values: YUML, MERMAID
$_formatDefault = "MERMAID"
$_showTargetFrameworksDefault = $true

$_useColoursDefault = $true

$_projectNamesToHighlightDefault = @()
$_highlightNodesAboveDefault = $true
$_highlightNodesBelowDefault = $true
$_showOnlyHighlightedNodesDefault = $true

# -------------------------------------------------------------------------------------------------
# No changes needed below this point; the remaining code is generic.
# -------------------------------------------------------------------------------------------------

#region YUML-specific formatting code -------------------------------------------------------------

function GetYumlNodeHierarchyLevelColour($LevelNumber)
{
    # It seems with the revamp of Yuml that it no longer obeys all the CSS colour names exactly.  For example, 
    # "yellow" is now displayed as #fde68a instead of #FFFF00, and "red" is now #fca5a5 instead of #ff0000.  
    # So use colour codes instead.
    <#
        #FF00FF: Magenta
        #9370DB: MediumPurple
        #6495ED: CornflowerBlue
        #00FFFF: Cyan
        #3CB371: MediumSeaGreen
        #7CFC00: LawnGreen
        #FFD700: Gold
        #FF8C00: DarkOrange
        #FA8072: Salmon
        #CD853F: Peru
    #>
    $colours = @('#FF00FF', '#9370DB', '#6495ED', '#00FFFF', `
            '#3CB371', '#7CFC00', '#FFD700', '#FF8C00', '#FA8072', '#CD853F')

    $numberColours = $colours.Count
    $colourIndex = $LevelNumber % $numberColours
    $colour = $colours[$colourIndex]
    return $colour
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
        $targetFrameworks = $ProjectInfo.targetFrameworks

        $node = "[$name]"
        if ($isHighlighted)
        {
            $colour = GetYumlNodeHierarchyLevelColour $hierarchyLevel
            $node = "[$name{bg:$colour}]"
            if ($targetFrameworks)
            {
                $node = "[$name{bg:$colour}|$targetFrameworks]"
            }
        }
        elseif ($targetFrameworks)
        {
            $node = "[$name|$targetFrameworks]"
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

function BuildYumlCode
(    
    [Parameter(Position = 0, 
        Mandatory = $true)]
    $AllProjectInfo,

    [Parameter(Position = 1, 
        Mandatory = $true)]
    $IsolatedProjectInfo,

    [Parameter(Position = 2, 
        Mandatory = $true)]
    $AllProjectRelationships
)
{
    $dependencyGraph = @()

    $isolatedProjectNodes = $IsolatedProjectInfo | PipelineGetYumlNode
    $dependencyGraph += $isolatedProjectNodes

    $relationships = $AllProjectRelationships | PipelineGetYumlRelationship $AllProjectInfo
    $dependencyGraph += $relationships

    return $dependencyGraph
}

#endregion YUML-specific formatting code ----------------------------------------------------------

#region Mermaid-specific formatting code ----------------------------------------------------------

function GetMermaidCodeTemplate()
{
    # NOTE: Available layout engines are: 
    #   - dagre (the default, if no YAML front-matter is added to the code.  Messy for large 
    #           graphs, with curving edges)
    #   - elk (good for large graphs, highly structured and clean, with right-angles in the edges)
    #   - cose-bilkent (for clustered distribution of nodes, not good for top-down graphs)
    #   - tidy-tree (for hierarchical top-down graphs, not good for dependency graphs, where
    #           nodes can have multiple parents)
    $documentTemplate = @"
---
config:
  layout: elk
---
flowchart TD

classDef magenta fill:Magenta;
classDef mediumPurple fill:MediumPurple;
classDef cornflowerBlue fill:CornflowerBlue;
classDef cyan fill:Cyan;
classDef mediumSeaGreen fill:MediumSeaGreen;
classDef lawnGreen fill:LawnGreen;
classDef gold fill:Gold;
classDef darkOrange fill:DarkOrange;
classDef salmon fill:Salmon;
classDef peru fill:Peru;

classDef highlight stroke: Red,stroke-width: 5px;

{{nodes}}

{{relationships}}
"@

    # Ensure the line endings are appropriate for the environment the script is running in.
    # NOTE: string.ReplaceLineEndings() was introduced in PowerShell 7.
    return $documentTemplate.ReplaceLineEndings()
}

function GetMermaidNodeHierarchyLevelColourClass($LevelNumber)
{
    $colourClasses = @('magenta', 'mediumPurple', 'cornflowerBlue', 'cyan', 'mediumSeaGreen', 
        'lawnGreen', 'gold', 'darkOrange', 'salmon', 'peru')

    $numberColours = $colourClasses.Count
    $colourIndex = $LevelNumber % $numberColours
    $colourClass = $colourClasses[$colourIndex]
    return $colourClass
}

function GetProjectIdText($ProjectId)
{
    #ASSUMPTION: There won't be more than 9999 nodes (4 digits).
    $projectIdText = "{0:D4}" -f $ProjectId
    return $projectIdText
}

function PipelineGetMermaidNode 
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
        $targetFrameworks = $ProjectInfo.targetFrameworks
        $projectIdText = GetProjectIdText $ProjectInfo.id

        $nodeInnerText = "<b>$name</b>"
        if ($targetFrameworks)
        {
            # If multiple target frameworks are specified, they will be separated by semi-colons.  
            # Replace the semi-colons with line breaks for better readability in the graph.
            # Remove the trailing semi-colon, if any, before replacing the semi-colons with line 
            # breaks.
            $targetFrameworks = $targetFrameworks.TrimEnd(';').Replace(';', '<br/>')
            $nodeInnerText += "<br/>$targetFrameworks"
        }

        $node = "$projectIdText[`"$nodeInnerText`"]"
        if ($isHighlighted)
        {
            $colourClass = GetMermaidNodeHierarchyLevelColourClass $hierarchyLevel
            $node = "$node:::${colourClass}"
        }

        $nodes += $node
    }

    end
    {
        return $nodes
    }
}

function PipelineGetMermaidRelationship
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

        $parentProjectIdText = GetProjectIdText $parentInfo.id
        $childProjectIdText = GetProjectIdText $childInfo.id

        $relationship = "$parentProjectIdText --> $childProjectIdText"
        $relationships += $relationship
    }

    end
    {
        return $relationships
    }
}

function BuildMermaidCode
(    
    [Parameter(Position = 0, 
        Mandatory = $true)]
    $AllProjectInfo,

    [Parameter(Position = 1, 
        Mandatory = $true)]
    $IsolatedProjectInfo,

    [Parameter(Position = 2, 
        Mandatory = $true)]
    $AllProjectRelationships
)
{    
    $template = GetMermaidCodeTemplate
    $resultingDocument = $template

    $nodes = $AllProjectInfo | PipelineGetMermaidNode
    $nodeLines = $nodes -join [Environment]::NewLine
    $resultingDocument = $resultingDocument -replace "{{nodes}}", $nodeLines

    $relationships = $AllProjectRelationships | PipelineGetMermaidRelationship $AllProjectInfo
    $relationshipLines = $relationships -join [Environment]::NewLine
    $resultingDocument = $resultingDocument -replace "{{relationships}}", $relationshipLines

    # Convert the document into an array of strings, as per the YUML result.
    $dependencyGraph = $resultingDocument -split [Environment]::NewLine

    return $dependencyGraph
}

#endregion Mermaid-specific formatting code -------------------------------------------------------

#region Functions for building code in different formats ------------------------------------------

function GetCodeBuilder([string]$Format)
{
    $codeBuilder = switch ($Format.ToUpper())
    {
        "YUML"      { ${function:BuildYumlCode} }
        "MERMAID"   { ${function:BuildMermaidCode} }
        default     { throw "Invalid format specified: $Format.  Valid values are: YUML, MERMAID." }
    }

    return $codeBuilder
}

#endregion Functions for building code in different formats ---------------------------------------

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
            $absolutePaths += $Path
            return 
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
    $projectInfo = 
    @{
        name = $ProjectName 
        filePath = $ProjectFilePath
        hierarchyLevel = $null
        isHighlighted = $false
        targetFrameworks = $null
    }

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
        # Using Measure-Object to measure hashtables was introduced in PowerShell 6.  It's used 
        # here to get the maximum project Id.  In PowerShell 5.1, Measure-Object can only be used 
        # to measure PS object properties, not hashtables, so this technique won't work in 
        # PowerShell 5.1.
        $maxProjectId = $AllProjectInfo | 
            Measure-Object -Property id -Maximum | 
            Select-Object -ExpandProperty Maximum
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

function PipelineGetNetTargetFramework 
(    
    [Parameter(Position = 0, 
    Mandatory = $true, 
    ValueFromPipeline = $true)]
    $ProjectInfo
)
{
    begin 
    {
        $allProjectInfo = @()
    }

    process
    {
        $projectFileName = $ProjectInfo.filePath

        $xmlDoc = new-object xml
        $xmlDoc.load($projectFileName)
        
        # Getting the value of $xmlDoc.Project.PropertyGroup... will return one value for each PropertyGroup element, 
        # regardless of whether it contains a TargetFramework / TargetFrameworks / TargetFrameworkVersion element.
        # The values returned for PropertyGroups without a target framework are $null.  Get rid of the nulls and join 
        # any remaining items.

        # Single target framework - "TargetFramework" singular.
        $targetFrameworks = $xmlDoc.Project.PropertyGroup.TargetFramework.Where{ $_ -ne $null } -join ';'
        if (-not $targetFrameworks)
        {
            # Multiple target frameworks - "TargetFrameworks" plural.
            $targetFrameworks = $xmlDoc.Project.PropertyGroup.TargetFrameworks.Where{ $_ -ne $null } -join ';'
        }
        if (-not $targetFrameworks)
        {
            # For .NET Framework projects.
            $targetFrameworks = $xmlDoc.Project.PropertyGroup.TargetFrameworkVersion.Where{ $_ -ne $null } -join ';'
        }

        if ($targetFrameworks)
        {
            $ProjectInfo.targetFrameworks = $targetFrameworks.Trim()
        }

        $allProjectInfo += $ProjectInfo
    }

    end
    {
        return $allProjectInfo
    }
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

function GenerateProjectDependencyGraph($SolutionFilePath, $Format, $ProjectNamesToHighlight, 
    [bool]$HighlightNodesAbove, [bool]$HighlightNodesBelow, [bool]$ShowOnlyHighlightedNodes, 
    [bool]$UseColours, [bool]$ShowTargetFrameworks)
{
    $allProjectInfo = GetAllProjectInfo $SolutionFilePath

    $allProjectInfo, $allProjectRelationships = $allProjectInfo | PipelineGetProjectRelationship $allProjectInfo

    SetHierarchyLevels $allProjectInfo $allProjectRelationships

    if ($ShowTargetFrameworks)
    {
        $allProjectInfo = $allProjectInfo | PipelineGetNetTargetFramework
    }

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

    $codeBuilder = GetCodeBuilder $Format

    $dependencyGraph = $codeBuilder.Invoke($allProjectInfo, $isolatedProjectsInfo, 
                                            $allProjectRelationships)

    return $dependencyGraph
}

#region Main script -------------------------------------------------------------------------------

Clear-Host

if ($host.Name -ne 'ConsoleHost')
{
    # Script is being run inside an editor, not in the PowerShell console.  In this case, use the 
    # values set in the default variables at the top of the script, rather than the values of the 
    # parameters in the Param() block.    
    $SolutionFilePath = $_solutionFilePathDefault
    $Format = $_formatDefault
    $ShowTargetFrameworks = $_showTargetFrameworksDefault
    $UseColours = $_useColoursDefault
    $ProjectNamesToHighlight = $_projectNamesToHighlightDefault
    $HighlightNodesAbove = $_highlightNodesAboveDefault
    $HighlightNodesBelow = $_highlightNodesBelowDefault
    $ShowOnlyHighlightedNodes = $_showOnlyHighlightedNodesDefault
}

if ($ProjectNamesToHighlight)
{
    $UseColours = $false
}

GenerateProjectDependencyGraph $SolutionFilePath $Format $ProjectNamesToHighlight `
    $HighlightNodesAbove $HighlightNodesBelow $ShowOnlyHighlightedNodes `
    $UseColours $ShowTargetFrameworks

#endregion Main script ----------------------------------------------------------------------------