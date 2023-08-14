<#
.SYNOPSIS
Re-extracts frames from a video clip in a KdenLive project, using the original video settings.

.DESCRIPTION
Kdenlive can extract frames from a video clip.  However, it extracts them using the project  
settings (resolution, orientation, aspect ratio, etc), not the settings of the original video 
clip.  This can lead to problems if the frames are used for freeze frames in the project, 
because they may have different resolution, etc, than the video clips in the project.

This script solves this problem by re-extracting the frames using the original settings of 
the video clip.  The re-extracted frames can then be copied over the original frames. 

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1
                ffmpeg (can be found in the kdenlive application bin folder, 
                        eg C:\Program Files\kdenlive\bin\ffmpeg.exe)
Version:		1.0.0 
Date:			10 Jan 2021

This script is based on the extract-frames bash script mentioned in the article "Working with 
Extracted Frames in Higher Resolution than Project Profile", 
https://kdenlive.org/en/project/working-with-extracted-frames-in-higher-resolution-than-project-profile/

The current version of the extract-frames bash script, as at 10 Jan 2021, can be found at 
https://gist.github.com/TheDiveO/57fd76e4d15252232aaacc7e422a79a2

#>

$kdenliveProjectFilePath = 'C:\Presentations\AzurePipelines\Videos\Demo5_09_MultistagePipeline_DeployToTestWithApproval.kdenlive'
$folderContainingFrameFiles = 'C:\Temp\Backups'

$ffmpegPath = 'C:\Program Files\kdenlive\bin\ffmpeg.exe'

Clear-Host

if (-not (Test-Path $kdenliveProjectFilePath))
{
    Write-Error 'Kdenlive project file not found'
    return
}

$kdenXmlDoc = new-object xml
$kdenXmlDoc.Load($kdenliveProjectFilePath)

$kdenXmlMltNode = $kdenXmlDoc.mlt
$kdenXmlProfileNode = $kdenXmlMltNode.profile
$kdenFrameRateNumerator = [int]$kdenXmlProfileNode.frame_rate_num
$kdenFrameRateDenominator = [int]$kdenXmlProfileNode.frame_rate_den

if (-not $kdenFrameRateNumerator)
{
    Write-Error 'Kdenlive project frame rate numerator not found'
    return
}

if (-not $kdenFrameRateDenominator)
{
    Write-Error 'Kdenlive project frame rate denominator not found'
    return
}

if ($kdenFrameRateDenominator -eq 0)
{
    Write-Error 'Invalid Kdenlive project frame rate denominator:  Denominator cannot be 0'
    return
}

$kdenliveProjectName = [System.IO.Path]::GetFileNameWithoutExtension($kdenliveProjectFilePath)

$frameFileFilter = Join-Path -Path $folderContainingFrameFiles -ChildPath "$kdenliveProjectName-f*.png"
$regexPattern = "$kdenliveProjectName-f(\d{6})\.png"
$regex = [System.Text.RegularExpressions.Regex]::new($regexPattern, [System.Text.RegularExpressions.RegexOptions]::Compiled)

$framesFileInfo = Get-ChildItem -Path $frameFileFilter -File

foreach ($frameFileInfo in $framesFileInfo)
{
    $fileName = $frameFileInfo.Name
    $match = $regex.Match($fileName)

    if (-not $match.Success)
    {
        Write-Error "Filename '$fileName' does not match regex"
        continue
    }

    # If the match was successful there will always be at least one group: 
    # Groups[0] represents the entire match.
    # We only want to continue if there is at least two groups, with the second being the frame 
    # number extracted from the file name.
    if ($match.Groups.Count -le 1)
    {
        Write-Error "No frame number found in filename '$fileName'"
        continue
    }

    $frameNumber = ($match.Groups[1].Value) -as [int]

    if (-not $frameNumber)
    {
        Write-Error "No frame number found in filename '$fileName'"
        continue
    }
}
