How to Split the Output of an Executable run in PowerShell between the Console and a File
=========================================================================================
Simon Elms, 25 Oct 2020

Situation:
----------
Want to run an executable in PowerShell that normally writes output to the console (stdout and, 
possibly, stderr).  Want to copy the output of the executable to a log file while still echoing 
it to the console.  This covers two use cases:

1. PowerShell script run manually (want output of executable displayed in console);

2. PowerShell script run via a scheduled task (want output of executable written to log file).

So we want stdout and stderr to both be copied to the log file while both still write to the 
console.

Useful Resources:
-----------------
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

