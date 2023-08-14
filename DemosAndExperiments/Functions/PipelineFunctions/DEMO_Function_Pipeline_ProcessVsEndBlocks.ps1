function Write-Title ([Parameter(Mandatory=$true)]$title)
{
	Write-Host '========================================================='
	Write-Host $title
	Write-Host '========================================================='
}

# Notice we're using parameters enclosed in a param block, inside the function body.
function TestEndBlock{
    param(  
    [Parameter(
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [Alias('FullName')]
    [String[]]$FilePath
    ) 
	
	begin
	{
		Write-Host 'BEGIN BLOCK'
		if ($FilePath -eq $null)
		{
			Write-Host '$FilePath IS NULL'
		}
		else
		{
			Write-Host '$FilePath type:' $FilePath.gettype().fullname
			Write-Host '$FilePath count:' $FilePath.Count
			Write-Host '$FilePath:' $FilePath
		}
		Write-Host ''
	}	
	
	end
	{
		Write-Host '------------------------------'
        Write-Host 'END BLOCK'
		Write-Host '$input type:' $input.gettype().fullname
		Write-Host '$input count:' $input.Count
		Write-Host '$input:' $input
		
		Write-Host 'Iterating through $input:'
	    foreach($inpath in $input)
	    {
	        Write-Host "    Element: $inpath"
	    }
		Write-Host ''
		
		Write-Host '$FilePath type:' $FilePath.gettype().fullname
		Write-Host '$FilePath count:' $FilePath.Count
		Write-Host '$FilePath:' $FilePath
		
		Write-Host 'Iterating through $FilePath:'
	    foreach($path in $FilePath)
	    {
	        Write-Host "    Element: $path"
	    }
		Write-Host ''
	}
}

# Notice we're using parameters enclosed in parentheses, before the function body.
# Either style of parameter works as well with piped input.

# To test this, modify the start of the function to:
<#
function TestProcessBlock {
    param( 
    [Parameter(
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [Alias('FullName')]
    [String[]]$FilePath
    ) 
	
	begin
	{
#>
# (ie enclose the parameter in a param block inside the function body) then rerun 
# this script and compare outputs.  They will be identical.
function TestProcessBlock(  
    [Parameter(
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [Alias('FullName')]
    [String[]]$FilePath
    ) 
{	
	begin
	{
		Write-Host 'BEGIN BLOCK'
		if ($FilePath -eq $null)
		{
			Write-Host '$FilePath IS NULL'
		}
		else
		{
			Write-Host '$FilePath type:' $FilePath.gettype().fullname
			Write-Host '$FilePath count:' $FilePath.Count
			Write-Host '$FilePath:' $FilePath
		}
		Write-Host ''
		
		$cumulative = @()
	}	
	
	process
	{
		Write-Host '------------------------------'
        Write-Host 'PROCESS BLOCK'
		Write-Host '$input type:' $input.gettype().fullname
		Write-Host '$input count:' $input.Count
		Write-Host '$input:' $input
			
	    Write-Host 'Iterating through $input:'
	    foreach($inpath in $input)
	    {
	        Write-Host "    Element: $inpath"
	    }
		Write-Host ''
		
		Write-Host '$FilePath type:' $FilePath.gettype().fullname
		Write-Host '$FilePath count:' $FilePath.Count
		Write-Host '$FilePath:' $FilePath
		
		Write-Host 'Iterating through $FilePath:'
	    foreach($path in $FilePath)
	    {
	        Write-Host "    Element: $path"
			$cumulative += $path
	    }
		Write-Host ''
	}
	
	end
	{
		Write-Host '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'		
		Write-Host 'END BLOCK'
		
		Write-Host '$cumulative count:' $cumulative.Count
		Write-Host '$cumulative:' $cumulative
		Write-Host ''
	}
}

Clear-Host

Write-Host '*************************************************************'
Write-Host 'TestEndBlock'
Write-Host '*************************************************************'

$testInput = "N:\Test1.txt"
Write-Title 'TestEndBlock "N:\Test1.txt"'
TestEndBlock $testInput

$testInput = "F:\Test1.txt", "F:\Test2.txt"
Write-Title 'TestEndBlock "F:\Test1.txt", "F:\Test2.txt"'
TestEndBlock $testInput

$testInput = "D:\scripts\s1.txt","D:\scripts\s2.txt"
Write-Title '"D:\scripts\s1.txt","D:\scripts\s2.txt" | TestEndBlock'
$testInput | TestEndBlock

Write-Title 'dir C:\Temp\Test\*.txt | TestEndBlock'
dir C:\Temp\*.txt | TestEndBlock

Write-Host '*************************************************************'
Write-Host 'TestProcessBlock'
Write-Host '*************************************************************'

$testInput = "N:\Test1.txt"
Write-Title 'TestProcessBlock "N:\Test1.txt"'
TestProcessBlock $testInput

$testInput = "F:\Test1.txt", "F:\Test2.txt"
Write-Title 'TestProcessBlock "F:\Test1.txt", "F:\Test2.txt"'
TestProcessBlock $testInput

$testInput = "D:\scripts\s1.txt","D:\scripts\s2.txt"
Write-Title '"D:\scripts\s1.txt","D:\scripts\s2.txt" | TestProcessBlock'
$testInput | TestProcessBlock

Write-Title 'dir C:\Temp\Test\*.txt | TestProcessBlock'
dir C:\Temp\*.txt | TestProcessBlock