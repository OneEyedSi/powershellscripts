<#
.SYNOPSIS
Experiments on how to pass parameter through the pipline ByPropertyName from a hashtable or an array.

.NOTES
It looks like the cleanest way to pass ByPropertyName is to either start with a hashtable or start 
with an array and convert it to a hashtable.
#>

Clear-Host

function Write-Title ($TitleText)
{
    Write-Host
    Write-Host $TitleText
    Write-Host ("-" * $TitleText.Length)
}

$ah = @(
        @{ChildPath='one'}
        @{ChildPath='two'}
        @{ChildPath='three'}
        )

# This will cause an error because you can't pass ByPropertyName from a hashtable.
# Error:
<#
Join-Path : The input object cannot be bound to any parameters for the command either 
because the command does not take pipeline input or the input and its properties do 
not match any of the parameters that take pipeline input.
#>
Write-Title 'Pass array of hash tables:'
$ah | Join-Path -Path 'C:\'

# Have to use a custom PSObject instead.
# Function to convert from hashtable to PSObject from 
# https://devblogs.microsoft.com/scripting/learn-about-using-powershell-value-binding-by-property-name/

function New-ObjectFromHashTable 
{
    [CmdletBinding()]
    param 
    (
        [parameter(Mandatory=$true, Position=1, ValueFromPipeline=$true)]
        [Hashtable]$Hashtable
    )

    begin { }

    process 
    {
        $r = new-object System.Management.Automation.PSObject          

        $Hashtable.Keys | 
            # The "{" must be on the same line as the "ForEach-Object".  If it's on the following 
            # line you'll get prompted to enter parameter[0].
            Foreach-Object {
                $key=$_
                $value=$Hashtable[$key]
                $r | Add-Member -MemberType NoteProperty -Name $key -Value $value -Force
            }

        $r
    } 

    end { }
}

Write-Title 'Pass array of PSCustomObjects using function 1:'
$ah | New-ObjectFromHashTable | Join-Path -Path 'C:\'

# Can simplify because can cast hashtable to PSCustomObject (since PowerShell 3).
# See answer https://stackoverflow.com/a/37705357/216440 to question 
# "PsObject array in powershell", 
# https://stackoverflow.com/questions/37705139/psobject-array-in-powershell
function New-ObjectFromHashTable2 
{
    [CmdletBinding()]
    param 
    (
        [parameter(Mandatory=$true, Position=1, ValueFromPipeline=$true)]
        [Hashtable]$Hashtable
    )

    begin { }

    process 
    {
        [PSCustomObject]$Hashtable 
    } 

    end { }
}

Write-Title 'Pass array of PSCustomObjects using function 2:'
$ah | New-ObjectFromHashTable2 | Join-Path -Path 'C:\'

# If we're going to simply cast to a PSCustomObject then we don't need the function at all.
Write-Title 'Pass array of PSCustomObjects converted from hashtables via ForEach-Object:'
$ah | ForEach-Object { [PSCustomObject]$_ } | Join-Path -Path 'C:\'

# Can we skip the hashtable completely?
Write-Title 'Pass array of PSCustomObjects converted from array:'
$a = @('one', 'two', 'three')
# PassThru parameter passes the input object through to the output.  If not specified Add-Member 
# does not return any output.
$a | ForEach-Object { $childPath = $_; New-Object PSObject | Add-Member -MemberType NoteProperty -Name 'ChildPath' -Value $childPath -PassThru} | 
    Join-Path -Path 'C:\'

Write-Title 'Pass array of PSCustomObjects from array (code reformated):'
$a | ForEach-Object { 
                        $childPath = $_
                        New-Object PSObject | 
                            Add-Member -MemberType NoteProperty -Name 'ChildPath' -Value $childPath -PassThru
                    } | 
    Join-Path -Path 'C:\'

# If we're starting with an array is it cleaner to create hashtable or go straight to PSCustomObject?
# Cleaner to create hashtable first.
Write-Title 'Convert array to hashtable to PSCustomObjects:'
$ah = $a.ForEach{@{'ChildPath'=$_}}
$ah | ForEach-Object { [PSCustomObject]$_ } | Join-Path -Path 'C:\'

# And this is maybe not cleaner but it is shorter.
Write-Title 'Convert array to hashtable to PSCustomObjects 2:'
$a.ForEach{ $h = @{'ChildPath'=$_}; [PSCustomObject]$h } | Join-Path -Path 'C:\'

# Creating a hashtable mapping the child paths to the full paths.
Write-Title 'Hashtable to map child paths to full paths:'
$h = @{}
$a.ForEach{ $h[$_] = (Join-Path -Path 'C:\' -ChildPath $_) }
$h
Write-Host
$h.Values
