function MyFunction (
    [string]$FirstArg, 
    [string]$SecondArg, 
    [string]$ThirdArg
)
{
    if (-not $FirstArg)
    {
        Write-Host 'No FirstArg.'
        return
    }

    Write-Host "FirstArg: $FirstArg"

    if (-not $SecondArg)
    {
        Write-Output 'No SecondArg.'
        return
    }

   Write-Host "SecondArg: $SecondArg"

    if (-not $ThirdArg)
    {
        Write-Output 'No ThirdArg.'
        return
    }

    Write-Host "ThirdArg: $ThirdArg"
}

function Write-TextWithUnderline (
    [string]$Title, 
    [string]$UnderlineCharacter
)
{
    Write-Host $Title
    Write-Host ($UnderlineCharacter * ($Title.Length))
}

function Write-Title (
    [string]$Title
)
{
    Write-TextWithUnderline $Title '='
}

function Write-SubTitle (
    [string]$Title
)
{
    Write-TextWithUnderline $Title '-'
}

function Call-ViaSplatting (
    $ParameterCollection
)
{
    if ($ParameterCollection -is [array])
    {
        $collectionTypeDescription = 'array'
        $parameterDescription = 'array'
    }
    elseif ($ParameterCollection -is [System.Object[]])
    { 
        $collectionTypeDescription = 'Array'
        $parameterDescription = 'Array'
    }
    elseif ($ParameterCollection -is [hashtable])  
    {
        $collectionTypeDescription = 'hash table'
        $parameterDescription = 'hashtable' 
    }
    else
    {
        Write-Error "Unrecognised collection type: $($ParameterCollection.GetType().FullName).  Aborting."
        return
    }

    Write-SubTitle "Pass $collectionTypeDescription as `$${parameterDescription} (note the '`$'):"
    MyFunction $ParameterCollection
    Write-Host

    Write-SubTitle "Pass $collectionTypeDescription as `@${parameterDescription} (note the '`@'):"
    MyFunction @ParameterCollection
}

Clear-Host

[System.Object[]]$array1 = @(
                                'zero'
                                'one'
                            )
[System.Object[]]$array2 = @(
                                'zero'
                                'one'
                                'two'
                                'three'
                            )
[System.Object[]]$array3 = @(
                                'one'
                                'two'
                            )

Write-Title 'Array with fewer elements than the function parameters'
Call-ViaSplatting $array1

Write-Host
Write-Title 'Array with more elements than the function parameters'
Call-ViaSplatting $array2

$hashtable1 = @{
                    SecondArg = 'one'
                    FirstArg = 'zero'
                }
$hashtable2 = @{
                    SecondArg = 'one'
                    FirstArg = 'zero'
                    ThirdArg = 'two'
                    FourthArg = 'three'
                }
$hashtable3 = @{
                    SecondArg = 'one'
                    ThirdArg = 'two'
                }

Write-Host
Write-Title 'Hash table with fewer elements than the function parameters'
Call-ViaSplatting $hashtable1

Write-Host
Write-Title 'Hash table with more elements than the function parameters'
Call-ViaSplatting $hashtable2

Write-Host
Write-Title 'Call with mixture of positional and splatted array arguments'
MyFunction 'zero' @array3

Write-Host
Write-Title 'Call with mixture of positional and splatted hashtable arguments'
MyFunction 'zero' @hashtable3

Write-Host
Write-Title 'Call with mixture of named and splatted array arguments'
MyFunction -FirstArg 'zero' @array3

Write-Host
Write-Title 'Call with mixture of named and splatted hashtable arguments'
MyFunction -FirstArg 'zero' @hashtable3

<# Result:

Array with fewer elements than the function parameters
======================================================
Pass array as $array (note the '$'):
------------------------------------
FirstArg: zero one
No SecondArg.

Pass array as @array (note the '@'):
------------------------------------
FirstArg: zero
SecondArg: one
No ThirdArg.

Array with more elements than the function parameters
=====================================================
Pass array as $array (note the '$'):
------------------------------------
FirstArg: zero one two three
No SecondArg.

Pass array as @array (note the '@'):
------------------------------------
FirstArg: zero
SecondArg: one
ThirdArg: two

Hash table with fewer elements than the function parameters
===========================================================
Pass hash table as $hashtable (note the '$'):
---------------------------------------------
FirstArg: System.Collections.Hashtable
No SecondArg.

Pass hash table as @hashtable (note the '@'):
---------------------------------------------
FirstArg: zero
SecondArg: one
No ThirdArg.

Hash table with more elements than the function parameters
==========================================================
Pass hash table as $hashtable (note the '$'):
---------------------------------------------
FirstArg: System.Collections.Hashtable
No SecondArg.

Pass hash table as @hashtable (note the '@'):
---------------------------------------------
FirstArg: zero
SecondArg: one
ThirdArg: two

Call with mixture of positional and splatted array arguments
============================================================
FirstArg: zero
SecondArg: one
ThirdArg: two

Call with mixture of positional and splatted hashtable arguments
================================================================
FirstArg: zero
SecondArg: one
ThirdArg: two

Call with mixture of named and splatted array arguments
=======================================================
FirstArg: zero
SecondArg: one
ThirdArg: two

Call with mixture of named and splatted hashtable arguments
===========================================================
FirstArg: zero
SecondArg: one
ThirdArg: two

#>