<#
.SYNOPSIS
Demonstrates how to write the output of an executable, called by PowerShell, to both console and 
a log file.

.DESCRIPTION
Want to run an executable in PowerShell that normally writes output to the console (stdout and, 
possibly, stderr).  Want to copy the output of the executable to a log file while still echoing 
it to the console.  This covers two use cases:

1. PowerShell script run manually (want output of executable displayed in console);

2. PowerShell script run via a scheduled task (want output of executable written to log file).

So we want stdout and stderr to both be copied to the log file while simultaneously both are 
written to the console.

The .NET console application will perform five tasks:

1. Write "Hello World!" to stdout;

2. List any command line arguments to stdout;

3. Write 23 lines to stdout and stderr, with the following text:
Before error 0
Before error 1
Before error 2
Before error 3
Before error 4
Before error 5
Before error 6
Before error 7
Before error 8
Before error 9

ERROR!!

After 0
After 1
After 2
After 3
After 4
After 5
After 6
After 7
After 8
After 9

The "Before error" and "After" lines, and the two blank lines, are written to stdout.  The "ERROR!!" 
line is written to stderr.

4. Writes the expected exit code to stdout.  See details of how the exit code is calculated below;

5. Returns the first command line argument as the exit code, if it's an integer.  If no command line 
arguments are specified, or if the first command line argument is not an integer, then it will 
return an exit code of 0.

.NOTES

The issue with the error output being written to the file in the wrong place only seems to occur if 
this script is run via Window PowerShell console.  If it's run via PowerShell ISE the error output 
appears to be written to the file in the correct place.  So run this script in Windows PowerShell 
console to check

Useful Resources:

1. "How to redirect output of console program to a file in PowerShell", 
http://chuchuva.com/pavel/2010/03/how-to-redirect-output-of-console-program-to-a-file-in-powershell/
- Explains the problems in redirecting stderr to a file:

	a. By default PowerShell will wrap the error in an exception, giving details of the line it 
	occurred on, etc, rather than just writing the raw error message to the file;
	
	b. This can be worked around by calling ToString() on every pipeline object that gets passed 
	through to the file.  However, in that case the text written to stderr will be passed through 
	the pipeline at a random time, so any errors written to the file will probably not appear in 
	the output sequence in the file in the same place they actually occurred, making it hard to 
	determine where the error actually occurred.

- The solution to these problems was to call cmd.exe to execute the executable, and use cmd.exe 
	to write stdout and stderr to the file. eg
		cmd /c s3.exe `>log.txt 2`>`&1
		(the backticks escape the redirection operators so PowerShell doesn't attempt the 
		redirection; it's done by cmd.exe instead)
	The problem with this is that all output goes to the file and none to the console.

2. "Tee-Object: The Most Underused Cmdlet in PowerShell", 
https://adamtheautomator.com/tee-object-powershell/
- Explains how to use the Tee-Object cmdlet to split output between the console and a file.

- The example they give is starting services and recording their initial state to a file before 
	starting them.  The naive way to do it would be to call Get-Service twice:
		PS> $servicesToStart = 'wuauserv','WebClient'
		PS> Get-Service -Name $servicesToStart | Out-File -FilePath 'C:\ServicesBefore.txt'
		PS> Get-Service -Name $servicesToStart | Start-Service

	With Tee-Object, however, you only need to call Get-Service once:
		PS> $servicesToStart = 'wuauserv','WebClient'
		PS> Get-Service -Name $servicesToStart | 
			Tee-Object -FilePath 'C:\ServicesBefore.txt' | 
			Start-Service

#>

$executablePath = "$PSScriptRoot\NetCoreConsoleAppDemo\NetCoreConsoleAppDemo\bin\Debug\netcoreapp3.1\NetCoreConsoleAppDemo.exe"
$outputFileFolder = "$PSScriptRoot\OutputFiles"

function Write-TitleText ([string]$UnderlineCharacter, [string]$TitleText)
{
    Write-Host 
    Write-Host $TitleText
    Write-Host ($UnderlineCharacter * $TitleText.Length)
}

function Write-Title ([string]$TitleText)
{
    Write-TitleText -UnderlineCharacter '=' -TitleText $TitleText
}

function Write-SubTitle ([string]$TitleText)
{
    Write-TitleText -UnderlineCharacter '-' -TitleText $TitleText
}

function Get-OutputFilePath([string]$OutputFileName)
{
    return (Join-Path -Path $outputFileFolder -ChildPath $OutputFileName)
}

Clear-Host

Write-Title 'Raw Invocation Operator:'
& $executablePath 123
Write-Host "Actual exit code: $LASTEXITCODE"
# Result:
# -------
# No output to file, the following output to the console (note error output as an exception):
<#
Hello World!

Command line arguments supplied:
    0: 123

Before error 0
Before error 1
Before error 2
Before error 3
Before error 4
Before error 5
Before error 6
Before error 7
Before error 8
Before error 9

ERROR!!

After 0
After 1
After 2
After 3
After 4
After 5
After 6
After 7
After 8
After 9

Expected exit code: 123
#>
# Actual exit code: 123

Write-Title 'Merge stderr into stdout, pass to Out-File:'
$outputFilePath = Get-OutputFilePath 'Test01_MergeStreams_OutFile.log'
& $executablePath 123 > $outputFilePath 2>&1
Write-Host "Actual exit code: $LASTEXITCODE"
# Result:
# -------
# No output to the console, the following output to the file:
# (note error text output as an exception and that it appears after all the "After" lines, 
# not between the two blank lines where it actually occurred.  
# WARNING: The position of the error text will vary each time this script is run.  Sometimes 
# it will appear in the correct place.)
<#
Hello World!

Command line arguments supplied:
    0: 123

Before error 0
Before error 1
Before error 2
Before error 3
Before error 4
Before error 5
Before error 6
Before error 7
Before error 8
Before error 9


After 0
After 1
After 2
NetCoreConsoleAppDemo.exe : ERROR!!
At C:\Users\SimonE\Documents\SimonsDocuments\IT\PowerShell\DemosAndExperiments\SplittingExecutableOutputBetweenConsoleA
ndFile\DEMO_SplittingExecutableOutputBetweenConsoleAndFile.ps1:173 char:1
+ & $executablePath 123 > $outputFilePath 2>&1
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (ERROR!!:String) [], RemoteException
    + FullyQualifiedErrorId : NativeCommandError
 
After 3
After 4
After 5
After 6
After 7
After 8
After 9

Expected exit code: 123
#>
# Actual exit code: 123

Write-Title 'Merge stderr into stdout, call ToString on pipeline objects, pass to Out-File:'
$outputFilePath = Get-OutputFilePath 'Test02_ToString_OutFile.log'
& $executablePath 123 2>&1 | ForEach-Object {$_.ToString()} | Out-File $outputFilePath
Write-Host "Actual exit code: $LASTEXITCODE"
# Result:
# -------
# No output to the console, the following output to the file:
# (note error text output as is, not as an exception, but that it still appears in the wrong 
# place, after both blank lines. 
# WARNING: The position of the error text will vary each time this script is run.  Sometimes 
# it will appear in the correct place.)
<#
Hello World!

Command line arguments supplied:
    0: 123

Before error 0
Before error 1
Before error 2
Before error 3
Before error 4
Before error 5
Before error 6
Before error 7
Before error 8
Before error 9


ERROR!!
After 0
After 1
After 2
After 3
After 4
After 5
After 6
After 7
After 8
After 9

Expected exit code: 123
#>
# Actual exit code: 123

Write-Title 'Call cmd.exe to write output to the file:'
$outputFilePath = Get-OutputFilePath 'Test03_cmd_RedirectToFile.log'
# The backticks are used to prevent PowerShell doing the redirection.
# Note that even though we're calling cmd.exe to execute the application we still get the correct 
# exit code when we read $LASTEXITCODE. 
cmd /c $executablePath 123 "`>$outputFilePath" 2`>`&1
Write-Host "Actual exit code: $LASTEXITCODE"
# Result:
# -------
# No output to the console, the following output to the file:
# (So the error output appears in the right place in the output file but there is still no 
# output to the console)
<#
Hello World!

Command line arguments supplied:
    0: 123

Before error 0
Before error 1
Before error 2
Before error 3
Before error 4
Before error 5
Before error 6
Before error 7
Before error 8
Before error 9

ERROR!!

After 0
After 1
After 2
After 3
After 4
After 5
After 6
After 7
After 8
After 9

Expected exit code: 123
#>
# Actual exit code: 123

Write-Title 'Use Tee-Object to output to both console and file:'
$outputFilePath = Get-OutputFilePath 'Test04_Tee-Object.log'
& $executablePath 123 2>&1 | Tee-Object -FilePath $outputFilePath
Write-Host "Actual exit code: $LASTEXITCODE"
# Result:
# -------
# Output to both console and file:
# (Error output is still in the wrong position.)
# WARNING: The position of the error text will vary each time this script is run.  Sometimes 
# it will appear in the correct place.
<#
Hello World!

Command line arguments supplied:
NetCoreConsoleAppDemo.exe : ERROR!!
At C:\Users\SimonE\Documents\SimonsDocuments\IT\PowerShell\DemosAndExperiments\SplittingExecutableOutputBetweenConsoleA
ndFile\DEMO_SplittingExecutableOutputBetweenConsoleAndFile.ps1:311 char:1
+ & $executablePath 123 2>&1 | Tee-Object -FilePath $outputFilePath
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (ERROR!!:String) [], RemoteException
    + FullyQualifiedErrorId : NativeCommandError
 
    0: 123

Before error 0
Before error 1
Before error 2
Before error 3
Before error 4
Before error 5
Before error 6
Before error 7
Before error 8
Before error 9


After 0
After 1
After 2
After 3
After 4
After 5
After 6
After 7
After 8
After 9

Expected exit code: 123
#>
# Actual exit code: 123

Write-Title 'Use Tee-Object with ToString:'
$outputFilePath = Get-OutputFilePath 'Test05_Tee-Object_ToString.log'
& $executablePath 123 2>&1 | foreach-object {$_.ToString()} | Tee-Object -FilePath $outputFilePath
Write-Host "Actual exit code: $LASTEXITCODE"
# Result:
# -------
# Output to both console and file:
# (Error output is just the text, not an exception, but it's still in the wrong position.)
# WARNING: The position of the error text will vary each time this script is run.  Sometimes 
# it will appear in the correct place.
<#
Hello World!

Command line arguments supplied:
    0: 123

Before error 0
Before error 1
Before error 2
Before error 3
Before error 4
Before error 5
Before error 6
Before error 7
Before error 8
Before error 9


ERROR!!
After 0
After 1
After 2
After 3
After 4
After 5
After 6
After 7
After 8
After 9

Expected exit code: 123
#>
# Actual exit code: 123

Write-Title 'Use cmd.exe and Tee-Object:'
$outputFilePath = Get-OutputFilePath 'Test06_cmd_Tee-Object.log'
# The backticks are used to prevent PowerShell doing the redirection.
cmd /c $executablePath 123 2`>`&1 | Tee-Object -FilePath $outputFilePath
Write-Host "Actual exit code: $LASTEXITCODE"
# Result:
# -------
# Output to both console and file:
# (Error output is just the text, not an exception, and it's in the correct position.)
<#
Hello World!

Command line arguments supplied:
    0: 123

Before error 0
Before error 1
Before error 2
Before error 3
Before error 4
Before error 5
Before error 6
Before error 7
Before error 8
Before error 9

ERROR!!

After 0
After 1
After 2
After 3
After 4
After 5
After 6
After 7
After 8
After 9

Expected exit code: 123
#>
# Actual exit code: 123

###################################################################################################
# BIG PROBLEM WITH Tee-Object: It outputs in UTF-16 and there is no way to change this encoding.
# So if Tee-Object is used to append to a log file created via, say, Set-Content, which defaults 
# to UTF-8 encoding, any text added via Tee-Object will appear with spaces between the characters, 
# which are the NULL bytes from the UTF-16 encoding.  So we need to find another way of Tee-ing 
# the output.
###################################################################################################

Write-Title 'Use cmd.exe and Tee-Object to append to file:'
$outputFilePath = Get-OutputFilePath 'Test07_cmd_Tee-Object_Append.log'
Set-Content -Path $outputFilePath -Value 'Line to create file'
# The backticks are used to prevent PowerShell doing the redirection.
cmd /c $executablePath 123 2`>`&1 | Tee-Object -FilePath $outputFilePath -Append
Write-Host "Actual exit code: $LASTEXITCODE"
# Result:
# -------
# Output to both console and file (apart from first line, only output to file):
# (Error output is just the text, not an exception, and it's in the correct position.  However, 
# all text output by Tee-Object appears double-spaced because the file was created using UTF-8 
# encoding but Tee-Object uses UTF-16)
<#
Line to create file
H e l l o   W o r l d !  
  
 C o m m a n d   l i n e   a r g u m e n t s   s u p p l i e d :  
         0 :   1 2 3  
  
 B e f o r e   e r r o r   0  
 B e f o r e   e r r o r   1  
 B e f o r e   e r r o r   2  
 B e f o r e   e r r o r   3  
 B e f o r e   e r r o r   4  
 B e f o r e   e r r o r   5  
 B e f o r e   e r r o r   6  
 B e f o r e   e r r o r   7  
 B e f o r e   e r r o r   8  
 B e f o r e   e r r o r   9  
  
 E R R O R ! !  
  
 A f t e r   0  
 A f t e r   1  
 A f t e r   2  
 A f t e r   3  
 A f t e r   4  
 A f t e r   5  
 A f t e r   6  
 A f t e r   7  
 A f t e r   8  
 A f t e r   9  
  
 E x p e c t e d   e x i t   c o d e :   1 2 3  
 
#>
# Actual exit code: 123

###################################################################################################
# cmd.exe and Add-Content with -PassThru normally work.  However, I've found a case when using 
# DTExec to run a SSIS package that it outputs only to the file, not to the console.  Can't tell 
# why and there doesn't seem to be any help online.  So seems unreliable.
###################################################################################################

Write-Title 'Use cmd.exe and Add-Content:'
$outputFilePath = Get-OutputFilePath 'Test08_cmd_Add-Content.log'
Set-Content -Path $outputFilePath -Value 'Line to create file'
# The backticks are used to prevent PowerShell doing the redirection.
cmd /c $executablePath 123 2`>`&1 | Add-Content -Path $outputFilePath -PassThru
Write-Host "Actual exit code: $LASTEXITCODE"
# Result:
# -------
# Output to both console and file (apart from first line, only output to file):
# (Error output is just the text, not an exception, and it's in the correct position.  And text 
# output by Add-Content uses the correct UTF-8 encoding)
<#
Line to create file
Hello World!

Command line arguments supplied:
    0: 123

Before error 0
Before error 1
Before error 2
Before error 3
Before error 4
Before error 5
Before error 6
Before error 7
Before error 8
Before error 9

ERROR!!

After 0
After 1
After 2
After 3
After 4
After 5
After 6
After 7
After 8
After 9

Expected exit code: 123
#>
# Actual exit code: 123

Write-Title 'Capture output as variable:'
$outputFilePath = Get-OutputFilePath 'Test09_CaptureAsVariable.log'
Set-Content -Path $outputFilePath -Value 'Line to create file'
$result = & $executablePath 123 2>&1 | Out-String 
Add-Content -Path $outputFilePath -Value $result
Write-Host $result
Write-Host "Actual exit code: $LASTEXITCODE"
# Result:
# -------
# Output to both console and file (apart from first line, only output to file):
# (Error output is an exception, and it's in the wrong position.  It uses the correct UTF-8 
# encoding though)
# WARNING: The position of the error text will vary each time this script is run.  Sometimes 
# it will appear in the correct place.
<#
Line to create file
Hello World!

Command line arguments supplied:
    0: 123

Before error 0
Before error 1
Before error 2
Before error 3
Before error 4
Before error 5
Before error 6
Before error 7
Before error 8
Before error 9


After 0
After 1
NetCoreConsoleAppDemo.exe : ERROR!!
At C:\Users\SimonE\Documents\SimonsDocuments\IT\PowerShell\DemosAndExperiments\SplittingExecutableOutputBetweenConsoleAndFile\DEMO_SplittingExecutableOutputBetweenConsoleAndFile.ps1:587 
char:11
+ $result = & $executablePath 123 2>&1 | Out-String
+           ~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (ERROR!!:String) [], RemoteException
    + FullyQualifiedErrorId : NativeCommandError
 
After 2
After 3
After 4
After 5
After 6
After 7
After 8
After 9

Expected exit code: 123

#>
# Actual exit code: 123

###################################################################################################
# cmd.exe then capturing the output into a variable seems to work, even with DTExec.
###################################################################################################

Write-Title 'Capture output as variable via cmd.exe:'
$outputFilePath = Get-OutputFilePath 'Test10_cmd_CaptureAsVariable.log'
Set-Content -Path $outputFilePath -Value 'Line to create file'
# The backticks are used to prevent PowerShell doing the redirection.
# Out-String collates the output as a single multi-line string, rather than as an array of strings.
# Want a multi-line string as that preserves line feeds at the end of each line, which an array of 
# strings does not.
$result = cmd /c $executablePath 123 2`>`&1 | Out-String 
Add-Content -Path $outputFilePath -Value $result
Write-Host $result
Write-Host "Actual exit code: $LASTEXITCODE"
# Result:
# -------
# Output to both console and file (apart from first line, only output to file):
# (Error output is just the text, not an exception, and it's in the correct position.  And text 
# output by Add-Content uses the correct UTF-8 encoding)
<#
Line to create file
Hello World!

Command line arguments supplied:
    0: 123

Before error 0
Before error 1
Before error 2
Before error 3
Before error 4
Before error 5
Before error 6
Before error 7
Before error 8
Before error 9

ERROR!!

After 0
After 1
After 2
After 3
After 4
After 5
After 6
After 7
After 8
After 9

Expected exit code: 123

#>
# Actual exit code: 123