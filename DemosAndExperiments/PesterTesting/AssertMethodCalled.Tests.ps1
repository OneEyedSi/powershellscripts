<#
.SYNOPSIS
Demonstrates how Pester can be used to check whether a method of an object is called, when the object is not exposed 
by the function under test.

.DESCRIPTION

.NOTES
Author:			Simon Elms
Requires:		* Windows PowerShell 5.1 or cross-platform PowerShell 6+
                * PowerShell modules:
                    - IISAdministration, version 1.1.0.0 or greater
Version:		1.0.0 
Date:			25 Apr 2025

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
		
		# Configure app pool ... 

		
		# We want to check this method is called:
		$iisServerManager.CommitChanges()

        # Problem: $iisServerManager is not exposed by the function under test, 
        # so how can we check CommitChanges was called?
	}
}

Describe 'Set-AppPool' {
	BeforeAll {
		$appPoolName = 'TestAppPool'

		function CommitChangesMock 
		{
			# Dummy, to test whether CommitChanges method called.
		}

		# Required, so we can use Should -Invoke to check whether CommitChangesMock called.
		Mock CommitChangesMock 
	}

	BeforeEach {
		$appPools = @{}
        $appPools[$AppPoolName] = @{ Name = $AppPoolName; ProcessModel = @{} }

		$mockedIISServerManager = [PSCustomObject]@{ ApplicationPools = $appPools }
		# Shadow the actual CommitChanges method with a dummy that calls our mocked function.
		$mockedIISServerManager | 
			Add-Member -MemberType ScriptMethod -Name CommitChanges -Value { CommitChangesMock } 

		# This makes the IISServerManager object, with the CommitChanges method we want to check, available to 
		# the function under test.
		Mock Get-IISServerManager { return $mockedIISServerManager }
	}

	It 'commits the changes after updating the app pool settings' {

		Set-AppPool -AppPoolName $appPoolName

		# Checks that the mocked dummy function was called.  
		# It will only be called if IISServerManager.CommitChanges() is called by the function under test.
		Should -Invoke CommitChangesMock -Times 1 -Exactly
	}
}