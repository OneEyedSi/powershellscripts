<#
.SYNOPSIS
Demonstrates how Pester can be used to check whether a property of an object is set, when the object is not exposed 
by the function under test.

.DESCRIPTION

.NOTES
Author:			Simon Elms
Requires:		* Windows PowerShell 5.1 or cross-platform PowerShell 6+
                * PowerShell modules:
                    - IISAdministration, version 1.1.0.0 or greater
Version:		1.0.0 
Date:			26 Apr 2025

#>
BeforeAll {
    Import-Module 'IISAdministration'

    # Function under test.
    function Set-AppPool (
        [string]$AppPoolName
    )
    {
        $iisServerManager = Get-IISServerManager

        $appPool = $iisServerManager.ApplicationPools[$AppPoolName]

        # We want to check this property is set:
        $appPool.AutoStart = $true
       
        $iisServerManager.CommitChanges()

        # Problem: $appPool is not exposed by the function under test, 
        # so how can we check AutoStart was set?
    }
}

Describe 'Set-AppPool' {
    BeforeAll {
        $appPoolName = 'TestAppPool'
    }

    BeforeEach {
        # Object we want to check the property of must be defined so that we can access it in tests: 
 
        # The object that has the property we want to check is an app pool object, which is assigned to 
        # $appPools[$AppPoolName]. 
        # $appPools[$AppPoolName] must be defined in such a way that it is visible to the test.
        # Define it as a hashtable, to make it easy for the function under test to add keys to it by 
        # using dot notation (same notation used for setting the value of a property and setting a 
        # hashtable value). 
        $appPools = @{} 
        $appPools[$AppPoolName] = @{ Name = $AppPoolName; ProcessModel = @{} }

        $mockedIISServerManager = [PSCustomObject]@{ ApplicationPools = $appPools }
        $mockedIISServerManager | Add-Member -MemberType ScriptMethod -Name CommitChanges -Value { }

        # This mock will ensure $appPools[$AppPoolName], defined above, is made available to the 
        # function under test.
        Mock Get-IISServerManager { return $mockedIISServerManager }
    }

    It 'sets AutoStart property to true' {

        Set-AppPool -AppPoolName $appPoolName

        # Checks that ApplicationPool.AutoStart property is set. 
        # The ApplicationPool object is private, not exposed by function under test.  However, it's 
        # accessible to the test via $appPools[$AppPoolName], defined in the BeforeEach block above.
        $appPool = $appPools[$AppPoolName] 
        $appPool.ContainsKey('AutoStart') | Should -BeTrue 
        $appPool.AutoStart | Should -BeTrue
    }
}