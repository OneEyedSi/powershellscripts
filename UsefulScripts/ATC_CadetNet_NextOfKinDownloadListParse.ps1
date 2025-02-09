<#
.SYNOPSIS
Parses next of kin data for ATC cadets retrieved from CadetNet and converts it into a table.

.DESCRIPTION
Parses input data in the form of a two-column CSV file, similar to:

Next of Kin for USC,
"CDTW/O Bloggs, Joe",
Relationship,Mother
Last Name,Bloggs
First Name,J
Middle Name,
Address,"12 Somewhere Pl, Christchurch, 8010"
Primary Phone,021 123 4567
Secondary Phone,
Work Phone,ext.
Email,jane.bloggs@gmail.com
"CDTF/S Smith, Jane",
Relationship,Father
Last Name,Doe
First Name,John
Middle Name,Clancy
Address,"1/23 Other Road, Papanui, Christchurch, 8013"
Primary Phone,021 987 6543
Secondary Phone,
Work Phone,ext.
Email,john.doe@gmail.com

Outputs the data to a CSV file with the specified path, in the following format:

Cadet Surname,Cadet First Name,Cadet Rank,NoK Relationship,NoK Surname,NoK First Name,NoK Middle Name,NoK Address,NoK Primary Phone,NoK Secondary Phone,NoK Work Phone,NoK Email
Bloggs,Joe,CDTW/O,Mother,Bloggs,J,,"12 Somewhere Pl, Christchurch, 8010",021 123 4567,,ext.,jane.bloggs@gmail.com
Smith,Jane,CDTF/S,Father,Doe,John,Clancy,"1/23 Other Road, Papanui, Christchurch, 8013",021 987 6543,,ext.,john.doe@gmail.com

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1 or later
Version:		1.0.0 
Date:			9 Feb 2025

#>

$_inputFilePath = "C:\ATC\ContactLists\SqnContactList_NextOfKin_List_202501.csv"
$_outputFilePath = "C:\ATC\ContactLists\SqnContactList_NextOfKin_Table_202501.csv"

# --------------------------------------------------------------------------------------------------------------------------
# No changes needed below this point; the remaining code is generic.
# --------------------------------------------------------------------------------------------------------------------------

$_intputField = @{
    Relationship = 'Relationship'
    LastName = 'Last Name'
    FirstName = 'First Name'
    MiddleName = 'Middle Name'
    Address = 'Address'
    PrimaryPhone = 'Primary Phone'
    SecondaryPhone = 'Secondary Phone'
    WorkPhone = 'Work Phone'
    Email = 'Email'
}

$_outputField = @{
    CadetSurname = 'Cadet Surname'
    CadetFirstName = 'Cadet First Name'
    CadetRank = 'Cadet Rank'
    NoKRelationship = 'NoK Relationship'
    NoKSurname = 'NoK Surname'
    NoKFirstName = 'NoK First Name'
    NoKMiddleName = 'NoK Middle Name'
    NoKAddress = 'NoK Address'
    NoKPrimaryPhone = 'NoK Primary Phone'
    NoKSecondaryPhone = 'NoK Secondary Phone'
    NoKWorkPhone = 'NoK Work Phone'
    NoKEmail = 'NoK Email'
}

$_mappingFromInputToOutputField = @{
    $_intputField.Relationship = $_outputField.NoKRelationship
    $_intputField.LastName = $_outputField.NoKSurname
    $_intputField.FirstName = $_outputField.NoKFirstName
    $_intputField.MiddleName = $_outputField.NoKMiddleName
    $_intputField.Address = $_outputField.NoKAddress
    $_intputField.PrimaryPhone = $_outputField.NoKPrimaryPhone
    $_intputField.SecondaryPhone = $_outputField.NoKSecondaryPhone
    $_intputField.WorkPhone = $_outputField.NoKWorkPhone
    $_intputField.Email = $_outputField.NoKEmail
}



#region Functions **********************************************************************************************************

function Get-CadetInfo([string]$CadetInfo, [System.Collections.Specialized.OrderedDictionary]$CadetNoKDetails)
{    
    # Cadet details will be of the form: "CDT Doe Smith, Jim Bob"
    # ie "{rank} {surname(s)}, {first name(s)}"
    $cadetObjectParts = $CadetInfo -split ','
    
    $rankSurnameParts = $cadetObjectParts[0] -split ' ', 2
    if ($rankSurnameParts.Count -eq 2)
    {
        $rank = $rankSurnameParts[0]
        $surname = $rankSurnameParts[1]
    }
    else 
    {
        $rank = ''
        $surname = $rankSurnameParts[0]
    }

    if ($cadetObjectParts.Count -gt 1)
    {
        $firstName = $cadetObjectParts[1]
    }
    else 
    {
        $firstName = ''
    }

    $CadetNoKDetails[$outputField.CadetSurname] = $surname
    $CadetNoKDetails[$outputField.CadetFirstName] = $firstName
    $CadetNoKDetails[$outputField.CadetRank] = $rank

    return $CadetNoKDetails
}

function Get-CadetNoKInfo([int]$LineNumberOfFirstNamedFieldForCadet, [array]$InputLineObjects, [hashtable]$OutputField, 
    [hashtable]$MappingFromInputToOutputField, [string]$FirstInputFieldNameForCadet)
{
    # Use an OrderedDictionary instead of a Hashtable to ensure the keys appear in the order they are added.  This will 
    # set the column order of the output CSV file.
    $returnObject = @{
        NextLineNumber = -1
        CadetNoKDetails = [System.Collections.Specialized.OrderedDictionary]@{}
    }
    
    # Line number should be on the first line of a cadet's info which has a field name.
    # Currently that's 'Relationship'.
    $lineObject = $InputLineObjects[$LineNumberOfFirstNamedFieldForCadet]
    $nokRelationshipWithCadet = $lineObject.Value
    
    $cadetNoKDetails = [System.Collections.Specialized.OrderedDictionary]@{}

    # Cadet name doesn't have field name.  It should be the line before the 'Relationship' line.
    # If the 'Relationship' line is the first line then obviously there is no cadet name.
    # We still want to parse this cadet info, though, to get to the next cadet.
    if ($LineNumberOfFirstNamedFieldForCadet -eq 0)
    {
        # No cadet name or rank.
        $cadetNoKDetails[$outputField.CadetSurname] = ''
        $cadetNoKDetails[$outputField.CadetFirstName] = ''
        $cadetNoKDetails[$outputField.CadetRank] = ''
    }
    else
    {
        $cadetLineObject = $InputLineObjects[$LineNumberOfFirstNamedFieldForCadet - 1]
        # The lines with the cadet info don't have a field name.  The first field is the cadet's name and rank.
        # The first field is converted into line object "FieldName" field.  So pass that as the cadet info.
        $cadetInfo = $cadetLineObject.FieldName
        $cadetNoKDetails = Get-CadetInfo -CadetInfo $cadetInfo -CadetNoKDetails $cadetNoKDetails
    }

    $cadetNoKDetails[$outputField.NoKRelationship] = $nokRelationshipWithCadet

    $fieldName = ''
    $lineNumber = $LineNumberOfFirstNamedFieldForCadet
    while ($lineNumber -lt $InputLineObjects.Count -and $fieldName -ne $FirstInputFieldNameForCadet)
    {
        $lineNumber++
        if ($lineNumber -ge $InputLineObjects.Count)
        {
            break
        }

        $lineObject = $InputLineObjects[$lineNumber]
        $fieldName = $lineObject.FieldName
        # Reached next cadet.
        if ($fieldName -eq $FirstInputFieldNameForCadet)
        {
            break
        }

        $outputFieldName = $MappingFromInputToOutputField[$fieldName]
        $nextFieldName = ''
        if ($lineNumber -lt $InputLineObjects.Count - 1)
        {
            $nextLineObject = $InputLineObjects[$lineNumber + 1]
            $nextFieldName = $nextLineObject.FieldName
        }
        # We already know the cadet info will be in the field name column and we don't want to treat this as a error.  
        # Identify this line by the following line, which should be the first named field for the cadet.  
        if ($nextFieldName -ne $FirstInputFieldNameForCadet -and -not $outputFieldName)
        {
            Write-Host "No output field maps to input field '$fieldName'.  Skipping this field." -ForegroundColor Red
            continue
        }

        if ($outputFieldName)
        {
            $cadetNoKDetails[$outputFieldName] = $lineObject.Value
        }
    }

    $returnObject.NextLineNumber = $lineNumber
    $returnObject.CadetNoKDetails = [PsCustomObject]$cadetNoKDetails

    return $returnObject
}

#endregion Functions *******************************************************************************************************

#region Main script ********************************************************************************************************
Clear-Host

if (-not (test-path -Path $_inputFilePath))
{
    Write-Host "Input file '$_inputFilePath' not found.  Aborting." -ForegroundColor Red
    return
}

$contents = Get-Content -Path $_inputFilePath

if (-not $contents)
{
    Write-Host "Input file '$_inputFilePath' is empty.  Aborting." -ForegroundColor Red
    return
}

# Force PowerShell to treat input CSV file as always having two columns: FieldName and Value.
$headers = 'FieldName', 'Value'
$inputLineObjects = $contents | ConvertFrom-Csv -Header $headers

$outputData = @()
# First named field for each cadet is 'Relationship'.
$firstInputFieldNameForCadet = $_intputField.Relationship

# Line numbers are zero-based.
$lineNumber = 0
$fieldName = ''

while ($lineNumber -lt $inputLineObjects.Count)
{
    $lineObject = $inputLineObjects[$lineNumber]
    $fieldName = $lineObject.FieldName

    if ($fieldName -ne $firstInputFieldNameForCadet)
    {
        $lineNumber++
        continue
    }

    $cadetInfo = Get-CadetNoKInfo -LineNumberOfFirstNamedFieldForCadet $lineNumber -InputLineObjects $inputLineObjects `
        -OutputField $_outputField -MappingFromInputToOutputField $_mappingFromInputToOutputField `
        -FirstInputFieldNameForCadet $_intputField.Relationship

    if ($cadetInfo.NextLineNumber -eq -1)
    {
        $lineNumber++
        continue        
    }

    $lineNumber = $cadetInfo.NextLineNumber
    $cadetNoKDetails = $cadetInfo.CadetNoKDetails
    $outputData += $cadetNoKDetails
}

$outputData | Export-Csv -Path $_outputFilePath

Write-Host "New next of kin file saved as '$_outputFilePath'."

#endregion Main script *****************************************************************************************************