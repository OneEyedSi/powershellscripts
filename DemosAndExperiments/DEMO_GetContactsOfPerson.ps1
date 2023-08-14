function Get-ContactOfPerson
    ([int]$PersonId, [array]$EncounterPairsList, [array]$KnownContacts = @())
{
    [int[]]$newContacts = @()

    if (-not $KnownContacts)
    {
        # Count the person themselves as a contact, to avoid endless loops.
        $KnownContacts = $PersonId
    }

    # Contacts can be in the forward and the backward directions.
    $newContacts += $encounterPairsList.Where({$_[0] -eq $personId}).ForEach({ $_[1] })
    $newContacts += $encounterPairsList.Where({$_[1] -eq $personId}).ForEach({ $_[0] })

    [int[]]$allContacts = $KnownContacts + $newContacts

    # Cast it to force LINQ to enumerate the elements to give us the Count of elements.
    [int[]]$uniqueContacts = [Linq.Enumerable]::Distinct($allContacts)

    if ($uniqueContacts.Count -gt $KnownContacts.Count)
    {
        $newContacts = $uniqueContacts.Where({$KnownContacts -notContains $_})
        $newContacts.ForEach({$uniqueContacts = Get-ContactOfPerson `
                                                -PersonId $_ `
                                                -EncounterPairsList $EncounterPairsList `
                                                -KnownContacts $uniqueContacts})
    }

    # If we're exiting the top level remove the person from the contact list.
    if ($KnownContacts.Count -eq 1)
    {
        $uniqueContacts = $uniqueContacts.Where({$_ -ne $PersonId})
    }
    return $uniqueContacts
}


$newContacts = @()
[int[]]$encounterPairs = @(
                            @(1,2),
                            @(1,4),
                            @(1,5),
                            @(3,4),
                            @(3,6),
                            @(3,7),
                            @(3,4),
                            @(3,6),
                            @(8,1),
                            @(9,1),
                            @(10,2),
                            @(2,1),
                            @(4,1),
                            @(3,2),
                            @(11,12),
                            @(11,13),
                            @(14,12)
                        )

Clear-Host

Get-ContactOfPerson -PersonId 1 -EncounterPairsList $encounterPairs