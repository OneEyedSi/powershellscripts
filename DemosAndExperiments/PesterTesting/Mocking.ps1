<#
.SYNOPSIS
Demonstrates mocking objects in Pester.

.NOTES
Tests from "Unit Testing PowerShell Code with Pester" from the "Hey, Scripting Guy!" blog:
https://blogs.technet.microsoft.com/heyscriptingguy/2015/12/16/unit-testing-powershell-code-with-pester/

ThESE TESTS WILL FAIL UNLESS Remote Server Administration Tools (RSAT) ARE INSTALLED ON THE 
MACHINE RUNNING THE TESTS.  RSAT FOR Windows 8.1 CAN BE DOWNLOADED HERE:
https://www.microsoft.com/en-us/download/details.aspx?id=39296

This is the case even though the AD commands have been mocked.  Pester needs to access the 
original commands to copy their parameters and will fail with a CommandNotFoundException if it 
cannot see them.
#>

<#
.SYNOPSIS
Function under test.
#>
function Disable-StaleADUser
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [string] $DomainName, 
        [uint32] $DaysToExpire = 90
    )

    $threshold = (Get-Date).AddDays(-$DaysToExpire)

    Get-ADUser -Server $DomainName -Properties LastLogonTimestamp -Filter * | 
        Where-Object { $_.LastLogonTimestamp -lt $threshold } |
        Disable-ADAccount
}

<#
.SYNOPSIS
Gets a test user for testing Disable-StaleADUser.
#>
function TestUser([string] $DisplayName, [datetime]$LastLogonTimestamp) {
    $user = New-Object Microsoft.ActiveDirectory.Management.ADUser
    $user.DisplayName = $DisplayName
    $user.LastLogonTimestamp = $LastLogonTimestamp

    return $user
}

<#
.SYNOPSIS
Pester tests.

.NOTES
ThESE TESTS WILL FAIL UNLESS Remote Server Administration Tools (RSAT) ARE INSTALLED ON THE 
MACHINE RUNNING THE TESTS.  RSAT FOR Windows 8.1 CAN BE DOWNLOADED HERE:
https://www.microsoft.com/en-us/download/details.aspx?id=39296

This is the case even though the AD commands have been mocked.  Pester needs to access the 
original commands to copy their parameters and will fail with a CommandNotFoundException if it 
cannot see them.
#>
Describe 'Disable-StaleADUser' {
    $today = New-Object datetime(2000, 1, 1)

    Mock Get-Date { return $today }

    Mock Get-ADUser {
        TestUser -DisplayName 'Thirty' -LastLogonTimestamp $today.AddDays(-30)
        TestUser -DisplayName 'Forty' -LastLogonTimestamp $today.AddDays(-40)
        TestUser -DisplayName 'Fifty' -LastLogonTimestamp $today.AddDays(-50)
        TestUser -DisplayName 'Sixty' -LastLogonTimestamp $today.AddDays(-60)
    }

    Mock Disable-ADAccount

    It 'Disables the correct accounts when DaysToExpire is set to 40' {
        Disable-StaleADUser -DaysToExpire 40 -DomainName WhoCares

        Assert-MockCalled Disable-ADAccount -Scope It -Times 0 -ParameterFilter { 
            $Identity.DisplayName -eq 'Thirty' }

        Assert-MockCalled Disable-ADAccount -Scope It -Times 0 -ParameterFilter { 
            $Identity.DisplayName -eq 'Forty' }

        Assert-MockCalled Disable-ADAccount -Scope It -Times 1 -ParameterFilter { 
            $Identity.DisplayName -eq 'Fifty' }

        Assert-MockCalled Disable-ADAccount -Scope It -Times 1 -ParameterFilter { 
            $Identity.DisplayName -eq 'Sixty' }
    }
}