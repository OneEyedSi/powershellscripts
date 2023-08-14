<#
.SYNOPSIS
Demonstrates whether the Clone() method of a hash table or an array does a shallow or deep copy 
of each element.
#>

function Write-Title ($TitleText)
{
    Write-Host
    Write-Host $TitleText
    Write-Host ("-" * $TitleText.Length)
}

<#
.SYNOPSIS
Demonstrates whether the Clone() method of a hash table does a shallow or deep copy 
of each element.

.NOTES
Conclusion:  HashTable.Clone() does a shallow copy of everything apart from elements that are 
    arrays, where it appears to do a deep copy.
#>
function Test-HashTable()
{

    $htXml = New-Object xml
    $htXml.LoadXml("<x></x>")

    $ht = @{
            String = "Hello World!"
            Int = 31
            Array = @(0, 1, @{Array1=1; Array2=2})
            HashTable = @{ First = 1; Second = 2 }
            Xml = $htXml
        }

    $newht = $ht.Clone()

    Clear-Host

    Write-Title "Hash table:"
    Write-Host $ht

    # Identical to original, including HashTable and Array elements.
    Write-Title "Hash table copy:"
    Write-Host $newht

    $ht.String = "Changed"
    $ht.NewString = "New string"
    $ht.Array += 6
    $ht.HashTable.Third = 3
    $ht.Xml.LoadXml("<y></y>")

    Write-Title "Hash table after changes:"
    Write-Host $ht

    # Changes to elements in original are not picked up by copy, except in the 
    # HashTable element.  There the element added to the HashTable element in 
    # the original IS picked up by the copy, indicating that a hash table 
    # element of a hash table is a shallow copy of the original.
    Write-Title "Hash table copy after hash table changed:"
    Write-Host $newht

    Write-Title "Hash table Xml element after changes:"
    Write-Host $ht.Xml.OuterXml

    # Changes to the Xml element in the original are picked up in the copy, 
    # indicating that CLone() only does a shallow copy of a .NET object.
    Write-Title "Hash table copy Xml element after changes:"
    Write-Host $newht.Xml.OuterXml

    $ht.Array = @(11, 12)
    $ht.HashTable = @{Different=11; One=12}

    Write-Title "Hash table after Array and HashTable elements replaced:"
    Write-Host $ht

    # The Array and HashTable elements that were replaced in the original do 
    # not appear in the copy.
    Write-Title "Hash table copy after Array and HashTable elements replaced:"
    Write-Host $newht
}

function Write-Array (
    [array]$arr
    )
{
    Write-Host "0: $($arr[0])"
    Write-Host "1: $($arr[1])"
    Write-Host "2 - $($arr[2].GetType().Name):"
    Write-Host "2.0: $($arr[2][0])"
    Write-Host "2.1: $($arr[2][1])"
    Write-Host "2.2.Array1: $($arr[2][2].Array1)"
    Write-Host "2.2.Array2: $($arr[2][2].Array2)"
    Write-Host "3 - $($arr[3].GetType().Name):"
    Write-Host "3.First: $($arr[3]['First'])"
    Write-Host "3.Second: $($arr[3]['Second'])"
}

<#
.SYNOPSIS
Demonstrates whether the Clone() method of an array does a shallow or deep copy 
of each element.

.NOTES
Conclusion:  HashTable.Clone() does a shallow copy.  Elements that are value types or strings 
are copied and the copy does not update when the original is changed.  Elements that are arrays 
and hash tables are shallow copied, so that when the original array or hash table is updated the 
copy reflects the change.
#>
function Test-Array()
{
    $a = @(
            "Hello world!",
            31,
            @(0, 1, @{Array1=1; Array2=2}),
            @{ First = 1; Second = 2 }
        )

    $newa = $a.Clone()

    Write-Title "Array:"
    Write-Array $a

    Write-Title "Array copy:"
    Write-Array $newa
    
    $a[0] = 'Goodbye cruel world!'
    $a[1] = 33
    $a[2][0] = 10
    $a[2][2]['Array1'] = 11
    $a[3]['First'] = 111
    
    Write-Title "Original Array after change:"
    Write-Array $a

    Write-Title "Array copy after original array changed:"
    Write-Array $newa
}

<#
.SYNOPSIS
Displays the menu.

.DESCRIPTION
Displays the menu the user can choose from.
#>
function Show-Menu ( 
    $MenuItems
    )
{    
    Write-Host "Select the test to run (type a letter followed by the [Enter] key, or press CTRL+C to exit)" `
        -ForegroundColor "Yellow"
    foreach ($menuItem in $MenuItems)
    {
        Write-Host "`t$($menuItem.Key)) $($menuItem.MenuText)" -ForegroundColor "Yellow"  
    }
    Write-Host
}

<#
.SYNOPSIS
Runs the user's choice of test.

.DESCRIPTION
Loops until the user enters a valid selection then runs that selected test, or they enter 
CTRL+C to abort.
#>
function Select-Test ()
{    
    $menuItems = @(
                        # Note that the function names have to be surrounded by curly braces otherwise the 
                        # functions will be executed and the return values assigned to the hash 
                        # tables' Function keys.
                        @{Key="A"; MenuText="Array"; Function={Test-Array}},
                        @{Key="H"; MenuText="Hash table"; Function={Test-HashTable}}
                    )
    Clear-Host
    Show-Menu $menuItems

    $userSelection = ""
    while ($True)
    {
        $selectionIsValid = $False
        $userSelection = Read-Host  
               
        ForEach ($menuItem in $menuItems)
        {
            $selectionIsValid = $True
            
            if ($userSelection -eq $menuItem.Key) 
            {
                Write-Host "Running $($menuItem.MenuText) test..." -ForegroundColor "Yellow"   
                Write-Host
                $menuItem.Function.Invoke()
                break
            }
        }

        $nextStepText = "Select again from the menu or press CTRL+C to exit"
        if (-not $selectionIsValid)
        {                
            $nextStepText = "Invalid selection.  Please try again or press CTRL+C to exit"
        }
        Write-Host
        Write-Host $nextStepText -ForegroundColor "Yellow"
        Write-Host

        Show-Menu $menuItems
    }
}

Select-Test




