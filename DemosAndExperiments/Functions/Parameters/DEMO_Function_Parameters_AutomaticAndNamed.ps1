# Conclusion: Cannot combine named parameters and undeclared parameters.
function Write-Something (
	[Parameter(Mandatory=$True)]
	[string]$Message
	)
{
	Write-Host "Message: '$Message'"
	Write-Host "Number of undeclared arguments: $($Args.Count)"
	For ($i = 0; $i -lt $Args.Count; $i++)
	{
		Write-Host "    Arg[$i]: $Args[$i]"
	}
}

Clear-Host
# Result: 
<#
Message: 'No undeclared arguments.'
Number of undeclared arguments: 0
#>
Write-Something "No undeclared arguments."

# Result: 
<#
Write-Something : A positional parameter cannot be found that accepts argument 'First'.
t C:\Users\simone\Documents\SimonsDocuments\IT\PowerShell\DemosAndExperiments\Functions\DEMO_Function_Parameters_AutomaticAndNamed.ps1:19 char:1
 Write-Something "One undeclared argument." "First"
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   + CategoryInfo          : InvalidArgument: (:) [Write-Something], ParameterBindingException
   + FullyQualifiedErrorId : PositionalParameterNotFound,Write-Something
#>
Write-Something "One undeclared argument." "First"

# Result:
<#
Write-Something : A positional parameter cannot be found that accepts argument 'First'.
At C:\Users\simone\Documents\SimonsDocuments\IT\PowerShell\DemosAndExperiments\Functions\DEMO_Function_Parameters_AutomaticAndNamed.ps1:22 char:1
+ Write-Something "One undeclared argument." "First" 2 3
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidArgument: (:) [Write-Something], ParameterBindingException
    + FullyQualifiedErrorId : PositionalParameterNotFound,Write-Something
#>
Write-Something "One undeclared argument." "First" 2 3