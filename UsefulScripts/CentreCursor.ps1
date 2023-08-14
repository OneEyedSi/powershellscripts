<#
.SYNOPSIS
Moves mouse cursor to centre of primary monitor.

.DESCRIPTION
For finding the mouse when it gets lost on a multi-monitor setup.  Create a shortcut with a 
hot key and add it to All Programs.  If the mouse gets lost hit the shortcut key and it will 
reappear in the centre of the primary monitor.

.NOTES
Details of the shortcut to create:

Target: %systemroot%\system32\windowspowershell\v1.0\powershell.exe -ExecutionPolicy RemoteSigned -File "C:\Path To Script\CentreCursor.ps1"

Shortcut key: Ctrl + Alt + Shift + C

Run: Minimized

.NOTES
This script courtesy of https://superuser.com/questions/384099/is-there-a-win7-shortcut-to-position-mouse-in-center-of-primary-screen

#>
[System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") | out-null
[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | out-null
$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$center = $bounds.Location
$center.X += $bounds.Width / 2
$center.Y += $bounds.Height / 2
[System.Windows.Forms.Cursor]::Position = $center