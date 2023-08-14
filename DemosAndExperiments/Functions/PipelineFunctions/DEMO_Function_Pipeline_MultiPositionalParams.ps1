function TestMultiplePositionalParameters
{
    param
	(  
	    [Parameter(
	        Position=0, 
	        Mandatory=$true)
	    ]
	    [String]$FirstParam,
		
	    [Parameter(
	        Position=1, 
	        Mandatory=$true, 
	        ValueFromPipeline=$true)
	    ]
	    [String]$SecondParam
    ) 
	
	begin
	{
		Write-Host '================================='
		Write-Host 'TestMultiplePositionalParameters'
		Write-Host '================================='
	}
	
	process
	{
		Write-Host '$FirstParam:' $FirstParam
		Write-Host '$SecondParam:' $SecondParam
		Write-Host ''		
	}
}

function TestMultiplePositionalParameters2
{
    param
	(  
	    [Parameter(
	        Position=0, 
	        Mandatory=$true, 
	        ValueFromPipeline=$true)
	    ]
	    [String]$FirstParam,
		
	    [Parameter(
	        Position=1, 
	        Mandatory=$true)
	    ]
	    [String]$SecondParam
    ) 
	
	begin
	{
		Write-Host '================================='
		Write-Host 'TestMultiplePositionalParameters2'
		Write-Host '================================='
	}
	
	process
	{
		Write-Host '$FirstParam:' $FirstParam
		Write-Host '$SecondParam:' $SecondParam
		Write-Host ''		
	}
}

Clear-Host

TestMultiplePositionalParameters 'first' 'second'
# Result: Works

"Input1","Input2" | TestMultiplePositionalParameters 'ExplicitArgument'
# Result: Works
 
"Input1","Input2" | TestMultiplePositionalParameters2 'ExplicitArgument'
# Result: Prompts for second parameter.  Presumably assigns 'ExplicitArgument' 
# to first parameter.  Still fails, even if enter second parameter value, with 
# error:

# The input object cannot be bound to any parameters for the 
# command either because the command does not take pipeline input or the input and its properties 
# do not match any of the parameters that take pipeline input.

# InvalidArgument: (Input1:String) [TestMultiplePositionalParameters2 
#   ], ParameterBindingException
#    + FullyQualifiedErrorId : InputObjectNotBound,TestMultiplePositionalParameters2
