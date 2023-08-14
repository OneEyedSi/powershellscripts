function Test-PathIsAbsolute ($Path)
{
    # Can't use [system.io.path]::IsPathFullyQualified($Path) as that was introduced in .NET Core 2.1 
    # and Windows PowerShell 5.1 is built on top of .NET Framework 4.5.

    # [system.io.path]::IsPathRooted($Path) considers paths that start with a separator, such as 
    # "\MyFolder\Myfile.txt" to be rooted.  So we can't use IsPathRooted by itself to determine if a 
    # path is absolute or not.
    # Following code based on Stackoverflow answer https://stackoverflow.com/a/35046453/216440
    
    # GetPathRoot('\\MyServer\MyFolder\MyFile.txt') returns '\\MyServer\MyFolder', not a separator 
    # character.
    $pathRoot = [system.io.path]::GetPathRoot($Path)    
    $leadingCharacterIsSeparator = ($pathRoot.Equals([system.io.path]::DirectorySeparatorChar.ToString()) `
                                -or $pathRoot.Equals([system.io.path]::AltDirectorySeparatorChar.ToString()))
    $isPathAbsolute = ([system.io.path]::IsPathRooted($Path) -and -not $leadingCharacterIsSeparator)

    return $isPathAbsolute
}

function Get-AbsolutePath ($Path)
{
    if (-not $Path)
    {
        return $null
    }

    $Path = $Path.Trim()
    if (Test-PathIsAbsolute -Path $Path)
    {
        return $Path
    }

    if ($Path.StartsWith("."))
    {
        $Path = $Path.Substring(1)
    }

    return Join-Path -Path $PSScriptRoot -ChildPath $Path
}

Get-AbsolutePath '\\FileServer01\MyFolder\MyFile.txt'