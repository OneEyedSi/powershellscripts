<#
.SYNOPSIS
Unit tests for function Install-RequiredModule in ModulesInstallFromRepository3.ps1.

.NOTES
Author:			Simon Elms
Requires:		Pester v5.5 or v.5.6 PowerShell module
Version:		1.0.0 
Date:			7 Jan 2025

WARNING:  Windows 10 and 11 come with Pester 3.4 pre-installed.  You cannot upgrade this version of Pester to a later one 
via 

    Update-Module Pester

Instead you'll have to install the new version side-by-side with the built-in one via Install-Module.

However, if you attempt to install a later version of Pester via a simple Install-Module command it will fail.  
For example:

    Install-Module Pester -RequiredVersion 5.6.1

Results in an error:

    "PackageManagement\Install-Package : A Microsoft-signed module named 'Pester' with version '3.4.0' that was previously 
    installed conflicts with the new module 'Pester' from publisher 'CN=DigiCert Trusted Root G4, OU=www.digicert.com, 
    O=DigiCert Inc, C=US' with version '5.6.1'. Installing the new module may result in system instability. If you still 
    want to install or update, use -SkipPublisherCheck parameter."

This is because the version of Pester pre-installed with Windows 10 or 11 is signed by Microsoft while later versions of 
Pester are community-maintained so signed with a different certificate.  

To avoid this error install the later version of Pester with the -SkipPublisherCheck switch.  For example:

    Install-Module Pester -RequiredVersion 5.6.1 -SkipPublisherCheck

#>

#region Requirements *******************************************************************************************************

# "#Requires" is not a comment, it's a requires directive.
# ModuleVersion is the minimum version, not the exact version.
#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.5.0"; MaximumVersion="5.6.99" }

#endregion Requirements ****************************************************************************************************

#region Setup **************************************************************************************************************

# Can't dot source using ". .\ModulesInstallFromRepository3.ps1" (without quotes) as relative paths are relative to the 
# current working directory, not the directory this test file is in.  So Use $PSScriptRoot to get the directory this file 
# is in, and dot source the file to test relative to this directory.
# -InTestContext switch ensures the script under test doesn't run automatically when dot sourced into this script.
BeforeAll {
    . (Join-Path $PSScriptRoot 'ModulesInstallFromRepository3.ps1') -InTestContext
}

#endregion Setup ***********************************************************************************************************

#region Tests **************************************************************************************************************

Describe 'Install-RequiredModule' {
    BeforeAll {
        function Get-MockedRepositoryDetails ([switch]$IsTrusted)
        {
            $installationPolicy = 'Untrusted'
            if ($IsTrusted)
            {
                $installationPolicy = 'Trusted'
            }
            $details = @{ Name='MyRepository'; InstallationPolicy=$installationPolicy }
            return [pscustomobject] $details
        }

        $moduleName = 'MyModule'
        $repository = 'PSGallery'

        Mock Write-Host
    }

    Context 'ParameterSet "ModuleName"' {
        BeforeAll {
            function Get-ModuleDetails ()
            {
                $details = @{ Version='1.0.0'; Name=$moduleName; Repository=$repository; Description='Mocked module' }
                return [pscustomobject] $details
            }            
        }

        Context 'Module is already installed' {
            BeforeAll {
                $installedModuleDetails = Get-ModuleDetails
                $foundModuleDetails = Get-ModuleDetails
                Mock Get-InstalledModule { return $installedModuleDetails } 
            }

            It 'executes without error' {            
                { Install-RequiredModule -RepositoryName $repository -ModuleName $moduleName } | 
                    Should -Not -Throw
            } 

            It 'does not attempt to find module' {
                Mock Find-Module { return $foundModuleDetails } 

                Install-RequiredModule -RepositoryName $repository -ModuleName $moduleName  
                
                Should -Not -Invoke Find-Module -Scope It
            } 
        }

        Context 'Module is installed in previous PowerShell version' {
            BeforeAll {
                $installedModuleDetails = Get-ModuleDetails
                $foundModuleDetails = Get-ModuleDetails
                Mock Get-InstalledModule { return $installedModuleDetails } 
            }

            It 'executes without error' {            
                { Install-RequiredModule -RepositoryName $repository -ModuleName $moduleName } | 
                    Should -Not -Throw
            } 

            It 'does not attempt to find module' {
                Mock Find-Module { return $foundModuleDetails } 

                Install-RequiredModule -RepositoryName $repository -ModuleName $moduleName  
                
                Should -Not -Invoke Find-Module -Scope It
            } 
        }

        Context 'Module is not already installed' {
            BeforeAll {
                $installedModuleDetails = Get-ModuleDetails
                $foundModuleDetails = Get-ModuleDetails  
                $repositoryDetails = Get-MockedRepositoryDetails -IsTrusted          

                # This weirdness with the hashtable $getInstalledModuleState ensures that the first time Get-InstalledModule is 
                # called it returns $Null but after Install-Module is called Get-InstalledModule returns the module details.
                Mock Get-InstalledModule { return $getInstalledModuleState.ModuleDetails } 
                Mock Install-Module { return $getInstalledModuleState.ModuleDetails = $installedModuleDetails } 

            }
            BeforeEach {
                $getInstalledModuleState = @{ ModuleDetails = $Null }
            }

            It 'attempts to find module in specified repository' {
                Mock Find-Module { return $foundModuleDetails } 

                Install-RequiredModule -RepositoryName $repository -ModuleName $moduleName  
                
                Should -Invoke Find-Module -ParameterFilter { $Name -eq $moduleName -and $Repository -eq $repository }
            }

            It 'throws error if cannot find module in specified repository' {
                Mock Find-Module { return $Null } 

                { Install-RequiredModule -RepositoryName $repository -ModuleName $moduleName } | 
                    Should -Throw "Module '$ModuleName' not found in repository '$repository'.  Exiting."
            }

            # We can't test the code branch where repository installation policy is not Trusted.
            # Pester has a bug when mocking Set-PSRepository, causing it to throw an exception.
            # See https://github.com/pester/Pester/issues/619

            It 'attempts to install module for current user if module is found in specified repository' {
                Mock Find-Module { return $foundModuleDetails } 
                Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }

                Install-RequiredModule -RepositoryName $repository -ModuleName $moduleName 

                Should -Invoke Install-Module `
                    -ParameterFilter { $Name -eq $moduleName -and $Repository -eq $repository -and $Scope -eq 'CurrentUser' } `
                    -Times 1 -Exactly
            }

            It 'throws error if module was not installed successfully' {
                # Ensures second call to Get-InstalledModule, after call to Install-Module, doesn't return any info.
                Mock Get-InstalledModule { return $Null }
                
                Mock Find-Module { return $foundModuleDetails } 
                Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }

                { Install-RequiredModule -RepositoryName $repository -ModuleName $moduleName } | 
                    Should -Throw "Unknown error installing module '$moduleName' from repository '$repository'.  Exiting."
            }

            It 'does not throw error if module was installed successfully' {
                # BeforeAll ensures the second call to Get-InstalledModule, after call to Install-Module, returns info 
                # about module.
                Mock Find-Module { return $foundModuleDetails }
                Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }

                { Install-RequiredModule -RepositoryName $repository -ModuleName $moduleName } | Should -Not -Throw
            }
        }
    }
    
    Context 'ParameterSet "ModuleDetails"' {
        BeforeAll {
            $installedVersion = '2.0.0'

            function Get-ModuleDetails ([string]$VersionNumber)
            {
                $details = @{ Version=$VersionNumber; Name=$moduleName; Repository=$repository; Description='Mocked module' }
                return [pscustomobject] $details
            }
        }

        Context 'No version specified' {
            BeforeAll {
                $inputDetails = @{ ModuleName = $moduleName }
            }
            
            Context 'Module is already installed' {
                BeforeAll {
                    $installedModuleDetails = Get-ModuleDetails $installedVersion
                    $foundModuleDetails = Get-ModuleDetails $installedVersion
                    Mock Get-InstalledModule { return $installedModuleDetails } 
                }

                It 'executes without error' {            
                    { Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails } | 
                        Should -Not -Throw
                } 

                It 'does not attempt to find module' {
                    Mock Find-Module { return $foundModuleDetails } 

                    Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails  
                    
                    Should -Not -Invoke Find-Module -Scope It
                } 
            }

            Context 'Module is not already installed' {
                BeforeAll {
                    $installedModuleDetails = Get-ModuleDetails $installedVersion
                    $foundModuleDetails = Get-ModuleDetails $installedVersion        

                    Mock Get-InstalledModule { return $getInstalledModuleState.ModuleDetails } 
                    Mock Install-Module { return $getInstalledModuleState.ModuleDetails = $installedModuleDetails } 

                }
                BeforeEach {
                    $getInstalledModuleState = @{ ModuleDetails = $Null }
                }

                It 'attempts to find module in specified repository' {
                    Mock Find-Module { return $foundModuleDetails } 
    
                    Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails  
                    
                    Should -Invoke Find-Module -ParameterFilter { $Name -eq $moduleName -and $Repository -eq $repository }
                }

                It 'throws error if cannot find module in specified repository' {
                    Mock Find-Module { return $Null } 

                    { Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails } | 
                        Should -Throw "Module '$ModuleName' not found in repository '$repository'.  Exiting."
                }

                # We can't test the code branch where repository installation policy is not Trusted.
                # Pester has a bug when mocking Set-PSRepository, causing it to throw an exception.
                # See https://github.com/pester/Pester/issues/619

                It 'attempts to install module for current user if module is found in specified repository' {
                    Mock Find-Module { return $foundModuleDetails } 
                    $repositoryDetails = Get-MockedRepositoryDetails -IsTrusted
                    Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }

                    Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails 

                    Should -Invoke Install-Module `
                        -ParameterFilter { $Name -eq $moduleName -and $Repository -eq $repository -and $Scope -eq 'CurrentUser' } `
                        -Times 1 -Exactly
                }

                It 'throws error if module was not installed successfully' {
                    # Ensures second call to Get-InstalledModule, after call to Install-Module, doesn't return any info.
                    Mock Get-InstalledModule { return $Null }
                    
                    Mock Find-Module { return $foundModuleDetails } 
                    $repositoryDetails = Get-MockedRepositoryDetails -IsTrusted
                    Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }
    
                    { Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails } | 
                        Should -Throw "Unknown error installing module '$moduleName' from repository '$repository'.  Exiting."
                }
    
                It 'does not throw error if module was installed successfully' {
                    # BeforeAll ensures the second call to Get-InstalledModule, after call to Install-Module, returns info 
                    # about module.
                    Mock Find-Module { return $foundModuleDetails } 
                    $repositoryDetails = Get-MockedRepositoryDetails -IsTrusted
                    Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }
    
                    { Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails } | Should -Not -Throw
                }
            }
        }

        Context 'RequiredVersion specified' {

            Context 'Module of same version is already installed' {
                BeforeAll {
                    $inputDetails = @{ ModuleName = $moduleName; RequiredVersion = $installedVersion }
                    $installedModuleDetails = Get-ModuleDetails $installedVersion
                    $foundModuleDetails = Get-ModuleDetails $installedVersion
                    Mock Get-InstalledModule { return $installedModuleDetails } 
                }

                It 'executes without error' {            
                    { Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails } | 
                        Should -Not -Throw
                } 

                It 'does not attempt to find module' {
                    Mock Find-Module { return $foundModuleDetails } 

                    Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails 
                    
                    Should -Not -Invoke Find-Module -Scope It
                } 
            }

            Context 'Module is not already installed' {
                BeforeAll {
                    $requiredVersion = '3.0.0'
                    $inputDetails = @{ ModuleName = $moduleName; RequiredVersion = $requiredVersion }
                    $installedModuleDetails = Get-ModuleDetails $requiredVersion
                    $foundModuleDetails = Get-ModuleDetails $requiredVersion
    
                    Mock Get-InstalledModule { return $getInstalledModuleState.ModuleDetails } 
                    Mock Install-Module { return $getInstalledModuleState.ModuleDetails = $installedModuleDetails } 
    
                }
                BeforeEach {
                    $getInstalledModuleState = @{ ModuleDetails = $Null }
                }

                It 'attempts to find module with the specified version in the specified repository' {
                    Mock Find-Module { return $foundModuleDetails } 
    
                    Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails  
                    
                    Should -Invoke Find-Module `
                        -ParameterFilter { $Name -eq $moduleName `
                                        -and $Repository -eq $repository `
                                        -and $RequiredVersion -eq $requiredVersion }
                }
    
                It 'throws error if cannot find module with the specified version in the specified repository' {
                    Mock Find-Module { return $Null } 
    
                    { Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails } | 
                        Should -Throw "Module '$ModuleName' with RequiredVersion $requiredVersion not found in repository '$repository'.  Exiting."
                }
    
                # We can't test the code branch where repository installation policy is not Trusted.
                # Pester has a bug when mocking Set-PSRepository, causing it to throw an exception.
                # See https://github.com/pester/Pester/issues/619
    
                It 'attempts to install module with the specified version for current user if module is found in specified repository' {
                    Mock Find-Module { return $foundModuleDetails } 
                    $repositoryDetails = Get-MockedRepositoryDetails -IsTrusted
                    Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }
    
                    Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails 

                    Should -Invoke Install-Module `
                        -ParameterFilter { $Name -eq $moduleName `
                                        -and $Repository -eq $repository `
                                        -and $Scope -eq 'CurrentUser' `
                                        -and $RequiredVersion -eq $requiredVersion } `
                        -Times 1 -Exactly
                }

                It 'throws error if module was not installed successfully' {
                    # Ensures second call to Get-InstalledModule, after call to Install-Module, doesn't return any info.
                    Mock Get-InstalledModule { return $Null }
                    
                    Mock Find-Module { return $foundModuleDetails } 
                    $repositoryDetails = Get-MockedRepositoryDetails -IsTrusted
                    Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }
    
                    { Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails } | 
                        Should -Throw "Unknown error installing module '$moduleName' with RequiredVersion $requiredVersion from repository '$repository'.  Exiting."
                }
    
                It 'does not throw error if module was installed successfully' {
                    # BeforeAll ensures the second call to Get-InstalledModule, after call to Install-Module, returns info 
                    # about module.
                    Mock Find-Module { return $foundModuleDetails } 
                    $repositoryDetails = Get-MockedRepositoryDetails -IsTrusted
                    Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }
    
                    { Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails } | Should -Not -Throw
                }    
            }

            Context 'Different version of the module is already installed' {
                BeforeAll {
                    $requiredVersion = '3.0.0'
                    $inputDetails = @{ ModuleName = $moduleName; RequiredVersion = $requiredVersion }
                    $installedModuleDetails = Get-ModuleDetails $installedVersion
                    $foundModuleDetails = Get-ModuleDetails $requiredVersion
                    $requiredModuleDetails = Get-ModuleDetails $requiredVersion

                    Mock Get-InstalledModule { return $getInstalledModuleState.ModuleDetails } 
                    Mock Install-Module { return $getInstalledModuleState.ModuleDetails = $requiredModuleDetails } 

                }
                BeforeEach {
                    $getInstalledModuleState = @{ ModuleDetails = $Null }
                }

                It 'attempts to find module with the specified version in the specified repository' {
                    Mock Find-Module { return $foundModuleDetails } 
    
                    Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails  
                    
                    Should -Invoke Find-Module `
                        -ParameterFilter { $Name -eq $moduleName `
                                        -and $Repository -eq $repository `
                                        -and $RequiredVersion -eq $requiredVersion }
                }

                It 'throws error if cannot find module with the specified version in the specified repository' {
                    Mock Find-Module { return $Null } 

                    { Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails } | 
                        Should -Throw "Module '$ModuleName' with RequiredVersion $requiredVersion not found in repository '$repository'.  Exiting."
                }

                # We can't test the code branch where repository installation policy is not Trusted.
                # Pester has a bug when mocking Set-PSRepository, causing it to throw an exception.
                # See https://github.com/pester/Pester/issues/619

                It 'attempts to install module with the specified version for current user if module is found in specified repository' {
                    Mock Find-Module { return $foundModuleDetails } 
                    $repositoryDetails = Get-MockedRepositoryDetails -IsTrusted
                    Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }

                    Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails 

                    Should -Invoke Install-Module `
                        -ParameterFilter { $Name -eq $moduleName `
                                        -and $Repository -eq $repository `
                                        -and $Scope -eq 'CurrentUser' `
                                        -and $RequiredVersion -eq $requiredVersion } `
                        -Times 1 -Exactly
                }

                It 'throws error if module was not installed successfully' {
                    # Ensures second call to Get-InstalledModule, after call to Install-Module, doesn't return any info.
                    Mock Get-InstalledModule { return $Null }
                    
                    Mock Find-Module { return $foundModuleDetails } 
                    $repositoryDetails = Get-MockedRepositoryDetails -IsTrusted
                    Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }
    
                    { Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails } | 
                        Should -Throw "Unknown error installing module '$moduleName' with RequiredVersion $requiredVersion from repository '$repository'.  Exiting."
                }
    
                It 'does not throw error if module was installed successfully' {
                    # BeforeAll ensures the second call to Get-InstalledModule, after call to Install-Module, returns info 
                    # about module.
                    Mock Find-Module { return $foundModuleDetails } 
                    $repositoryDetails = Get-MockedRepositoryDetails -IsTrusted
                    Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }
    
                    { Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails } | Should -Not -Throw
                }    
            }
        }

        Context 'MinimumVersion specified' {

            Context 'Module of the minimum version is already installed' {
                BeforeAll {
                    $inputDetails = @{ ModuleName = $moduleName; MinimumVersion = $installedVersion }
                    $installedModuleDetails = Get-ModuleDetails $installedVersion
                    $foundModuleDetails = Get-ModuleDetails $installedVersion
                    Mock Get-InstalledModule { return $installedModuleDetails } 
                }

                It 'executes without error' {            
                    { Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails } | 
                        Should -Not -Throw
                } 

                It 'does not attempt to find module' {
                    Mock Find-Module { return $foundModuleDetails } 

                    Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails 
                    
                    Should -Not -Invoke Find-Module -Scope It
                } 
            }

            Context 'Module of a greater version is already installed' {
                BeforeAll {
                    $minimumVersion = '1.0.0'
                    $inputDetails = @{ ModuleName = $moduleName; MinimumVersion = $minimumVersion }
                    $installedModuleDetails = Get-ModuleDetails $installedVersion
                    $foundModuleDetails = Get-ModuleDetails $minimumVersion
                    Mock Get-InstalledModule { return $installedModuleDetails } 
                }

                It 'executes without error' {            
                    { Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails } | 
                        Should -Not -Throw
                } 

                It 'does not attempt to find module' {
                    Mock Find-Module { return $foundModuleDetails } 

                    Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails 
                    
                    Should -Not -Invoke Find-Module -Scope It
                } 

                It 'logs the version of the module already installed' {
                    Mock Find-Module { return $foundModuleDetails } 

                    Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails 
                    
                    Should -Invoke Write-Host -Scope It `
                        -ParameterFilter { $Object -eq "Version $installedVersion of module '$moduleName' is already installed."}
                } 
            }

            Context 'Module is not already installed' {
                Context 'Repository has the minimum version of the module' {                 
                    BeforeAll {
                        $minimumVersion = '3.0.0'
                        $inputDetails = @{ ModuleName = $moduleName; MinimumVersion = $minimumVersion }
                        $installedModuleDetails = Get-ModuleDetails $minimumVersion
                        $foundModuleDetails = Get-ModuleDetails $minimumVersion
        
                        Mock Get-InstalledModule { return $getInstalledModuleState.ModuleDetails } 
                        Mock Install-Module { return $getInstalledModuleState.ModuleDetails = $installedModuleDetails } 
        
                    }
                    BeforeEach {
                        $getInstalledModuleState = @{ ModuleDetails = $Null }
                    }

                    It 'attempts to find module with the minimum version in the specified repository' {
                        Mock Find-Module { return $foundModuleDetails } 
        
                        Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails  
                        
                        Should -Invoke Find-Module `
                            -ParameterFilter { $Name -eq $moduleName `
                                            -and $Repository -eq $repository `
                                            -and $MinimumVersion -eq $minimumVersion }
                    }
        
                    It 'throws error if cannot find module with the minimum version in the specified repository' {
                        Mock Find-Module { return $Null } 
        
                        { Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails } | 
                            Should -Throw "Module '$ModuleName' with MinimumVersion $minimumVersion not found in repository '$repository'.  Exiting."
                    }
        
                    # We can't test the code branch where repository installation policy is not Trusted.
                    # Pester has a bug when mocking Set-PSRepository, causing it to throw an exception.
                    # See https://github.com/pester/Pester/issues/619
        
                    It 'attempts to install module with the minimum version for current user if module is found in specified repository' {
                        Mock Find-Module { return $foundModuleDetails } 
                        $repositoryDetails = Get-MockedRepositoryDetails -IsTrusted
                        Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }
        
                        Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails 

                        Should -Invoke Install-Module `
                            -ParameterFilter { $Name -eq $moduleName `
                                            -and $Repository -eq $repository `
                                            -and $Scope -eq 'CurrentUser' `
                                            -and $MinimumVersion -eq $minimumVersion } `
                            -Times 1 -Exactly
                    }

                    It 'throws error if module was not installed successfully' {
                        # Ensures second call to Get-InstalledModule, after call to Install-Module, doesn't return any info.
                        Mock Get-InstalledModule { return $Null }
                        
                        Mock Find-Module { return $foundModuleDetails } 
                        $repositoryDetails = Get-MockedRepositoryDetails -IsTrusted
                        Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }
        
                        { Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails } | 
                            Should -Throw "Unknown error installing module '$moduleName' with MinimumVersion $minimumVersion from repository '$repository'.  Exiting."
                    }
        
                    It 'does not throw error if module was installed successfully' {
                        # BeforeAll ensures the second call to Get-InstalledModule, after call to Install-Module, returns info 
                        # about module.
                        Mock Find-Module { return $foundModuleDetails } 
                        $repositoryDetails = Get-MockedRepositoryDetails -IsTrusted
                        Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }
        
                        { Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails } | Should -Not -Throw
                    } 
        
                    It 'logs the version of the module installed' {
                        Mock Find-Module { return $foundModuleDetails } 
                        $repositoryDetails = Get-MockedRepositoryDetails -IsTrusted
                        Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }
        
                        Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails 

                        Should -Invoke Write-Host -Scope It `
                            -ParameterFilter { $Object -eq "Version $minimumVersion of module '$moduleName' successfully installed."}
                    }
                } 
                Context 'Repository has a greater version of the module' {                 
                    BeforeAll {
                        $minimumVersion = '3.0.0'
                        $repositoryModuleVersion = '4.0.0'
                        $inputDetails = @{ ModuleName = $moduleName; MinimumVersion = $minimumVersion }
                        $installedModuleDetails = Get-ModuleDetails $repositoryModuleVersion
                        $foundModuleDetails = Get-ModuleDetails $repositoryModuleVersion
        
                        Mock Get-InstalledModule { return $getInstalledModuleState.ModuleDetails } 
                        Mock Install-Module { return $getInstalledModuleState.ModuleDetails = $installedModuleDetails } 
        
                    }
                    BeforeEach {
                        $getInstalledModuleState = @{ ModuleDetails = $Null }
                    }

                    It 'attempts to find module with the minimum version in the specified repository' {
                        Mock Find-Module { return $foundModuleDetails } 
        
                        Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails  
                        
                        Should -Invoke Find-Module `
                            -ParameterFilter { $Name -eq $moduleName `
                                            -and $Repository -eq $repository `
                                            -and $MinimumVersion -eq $minimumVersion }
                    }
        
                    It 'throws error if cannot find module with the minimum version in the specified repository' {
                        Mock Find-Module { return $Null } 
        
                        { Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails } | 
                            Should -Throw "Module '$ModuleName' with MinimumVersion $minimumVersion not found in repository '$repository'.  Exiting."
                    }
        
                    # We can't test the code branch where repository installation policy is not Trusted.
                    # Pester has a bug when mocking Set-PSRepository, causing it to throw an exception.
                    # See https://github.com/pester/Pester/issues/619
        
                    It 'attempts to install module with the minimum version for current user if module is found in specified repository' {
                        Mock Find-Module { return $foundModuleDetails } 
                        $repositoryDetails = Get-MockedRepositoryDetails -IsTrusted
                        Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }
        
                        Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails 

                        Should -Invoke Install-Module `
                            -ParameterFilter { $Name -eq $moduleName `
                                            -and $Repository -eq $repository `
                                            -and $Scope -eq 'CurrentUser' `
                                            -and $MinimumVersion -eq $minimumVersion } `
                            -Times 1 -Exactly
                    }

                    It 'throws error if module was not installed successfully' {
                        # Ensures second call to Get-InstalledModule, after call to Install-Module, doesn't return any info.
                        Mock Get-InstalledModule { return $Null }
                        
                        Mock Find-Module { return $foundModuleDetails } 
                        $repositoryDetails = Get-MockedRepositoryDetails -IsTrusted
                        Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }
        
                        { Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails } | 
                            Should -Throw "Unknown error installing module '$moduleName' with MinimumVersion $minimumVersion from repository '$repository'.  Exiting."
                    }
        
                    It 'does not throw error if module was installed successfully' {
                        # BeforeAll ensures the second call to Get-InstalledModule, after call to Install-Module, returns info 
                        # about module.
                        Mock Find-Module { return $foundModuleDetails } 
                        $repositoryDetails = Get-MockedRepositoryDetails -IsTrusted
                        Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }
        
                        { Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails } | Should -Not -Throw
                    } 
        
                    It 'logs the version of the module installed' {
                        Mock Find-Module { return $foundModuleDetails } 
                        $repositoryDetails = Get-MockedRepositoryDetails -IsTrusted
                        Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }
        
                        Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails 

                        Should -Invoke Write-Host -Scope It `
                            -ParameterFilter { $Object -eq "Version $repositoryModuleVersion of module '$moduleName' successfully installed."}
                    }
                }   
            }
        }

        Context 'MaximumVersion specified' {

            Context 'Module of the maximum version is already installed' {
                BeforeAll {
                    $inputDetails = @{ ModuleName = $moduleName; MaximumVersion = $installedVersion }
                    $installedModuleDetails = Get-ModuleDetails $installedVersion
                    $foundModuleDetails = Get-ModuleDetails $installedVersion
                    Mock Get-InstalledModule { return $installedModuleDetails } 
                }

                It 'executes without error' {            
                    { Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails } | 
                        Should -Not -Throw
                } 

                It 'does not attempt to find module' {
                    Mock Find-Module { return $foundModuleDetails } 

                    Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails 
                    
                    Should -Not -Invoke Find-Module -Scope It
                } 
            }

            Context 'Module of a lesser version is already installed' {
                BeforeAll {
                    $maximumVersion = '4.0.0'
                    $inputDetails = @{ ModuleName = $moduleName; MaximumVersion = $maximumVersion }
                    $installedModuleDetails = Get-ModuleDetails $installedVersion
                    $foundModuleDetails = Get-ModuleDetails $maximumVersion
                    Mock Get-InstalledModule { return $installedModuleDetails } 
                }

                It 'executes without error' {            
                    { Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails } | 
                        Should -Not -Throw
                } 

                It 'does not attempt to find module' {
                    Mock Find-Module { return $foundModuleDetails } 

                    Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails 
                    
                    Should -Not -Invoke Find-Module -Scope It
                } 

                It 'logs the version of the module already installed' {
                    Mock Find-Module { return $foundModuleDetails } 

                    Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails 
                    
                    Should -Invoke Write-Host -Scope It `
                        -ParameterFilter { $Object -eq "Version $installedVersion of module '$moduleName' is already installed."}
                } 
            }

            Context 'Module is not already installed' {
                Context 'Repository has the maximum version of the module' {                 
                    BeforeAll {
                        $maximumVersion = '4.0.0'
                        $inputDetails = @{ ModuleName = $moduleName; MaximumVersion = $maximumVersion }
                        $installedModuleDetails = Get-ModuleDetails $maximumVersion
                        $foundModuleDetails = Get-ModuleDetails $maximumVersion
        
                        Mock Get-InstalledModule { return $getInstalledModuleState.ModuleDetails } 
                        Mock Install-Module { return $getInstalledModuleState.ModuleDetails = $installedModuleDetails } 
        
                    }
                    BeforeEach {
                        $getInstalledModuleState = @{ ModuleDetails = $Null }
                    }

                    It 'attempts to find module with the maximum version in the specified repository' {
                        Mock Find-Module { return $foundModuleDetails } 
        
                        Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails  
                        
                        Should -Invoke Find-Module `
                            -ParameterFilter { $Name -eq $moduleName `
                                            -and $Repository -eq $repository `
                                            -and $MaximumVersion -eq $maximumVersion }
                    }
        
                    It 'throws error if cannot find module with the maximum version in the specified repository' {
                        Mock Find-Module { return $Null } 
        
                        { Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails } | 
                            Should -Throw "Module '$ModuleName' with MaximumVersion $maximumVersion not found in repository '$repository'.  Exiting."
                    }
        
                    # We can't test the code branch where repository installation policy is not Trusted.
                    # Pester has a bug when mocking Set-PSRepository, causing it to throw an exception.
                    # See https://github.com/pester/Pester/issues/619
        
                    It 'attempts to install module with the maximum version for current user if module is found in specified repository' {
                        Mock Find-Module { return $foundModuleDetails } 
                        $repositoryDetails = Get-MockedRepositoryDetails -IsTrusted
                        Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }
        
                        Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails 

                        Should -Invoke Install-Module `
                            -ParameterFilter { $Name -eq $moduleName `
                                            -and $Repository -eq $repository `
                                            -and $Scope -eq 'CurrentUser' `
                                            -and $MaximumVersion -eq $maximumVersion } `
                            -Times 1 -Exactly
                    }

                    It 'throws error if module was not installed successfully' {
                        # Ensures second call to Get-InstalledModule, after call to Install-Module, doesn't return any info.
                        Mock Get-InstalledModule { return $Null }
                        
                        Mock Find-Module { return $foundModuleDetails } 
                        $repositoryDetails = Get-MockedRepositoryDetails -IsTrusted
                        Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }
        
                        { Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails } | 
                            Should -Throw "Unknown error installing module '$moduleName' with MaximumVersion $maximumVersion from repository '$repository'.  Exiting."
                    }
        
                    It 'does not throw error if module was installed successfully' {
                        # BeforeAll ensures the second call to Get-InstalledModule, after call to Install-Module, returns info 
                        # about module.
                        Mock Find-Module { return $foundModuleDetails } 
                        $repositoryDetails = Get-MockedRepositoryDetails -IsTrusted
                        Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }
        
                        { Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails } | Should -Not -Throw
                    } 
        
                    It 'logs the version of the module installed' {
                        Mock Find-Module { return $foundModuleDetails } 
                        $repositoryDetails = Get-MockedRepositoryDetails -IsTrusted
                        Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }
        
                        Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails 

                        Should -Invoke Write-Host -Scope It `
                            -ParameterFilter { $Object -eq "Version $maximumVersion of module '$moduleName' successfully installed."}
                    }
                } 
                Context 'Repository has a lesser version of the module' {                 
                    BeforeAll {
                        $maximumVersion = '4.0.0'
                        $repositoryModuleVersion = '3.0.0'
                        $inputDetails = @{ ModuleName = $moduleName; MaximumVersion = $maximumVersion }
                        $installedModuleDetails = Get-ModuleDetails $repositoryModuleVersion
                        $foundModuleDetails = Get-ModuleDetails $repositoryModuleVersion
        
                        Mock Get-InstalledModule { return $getInstalledModuleState.ModuleDetails } 
                        Mock Install-Module { return $getInstalledModuleState.ModuleDetails = $installedModuleDetails } 
        
                    }
                    BeforeEach {
                        $getInstalledModuleState = @{ ModuleDetails = $Null }
                    }

                    It 'attempts to find module with the maximum version in the specified repository' {
                        Mock Find-Module { return $foundModuleDetails } 
        
                        Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails  
                        
                        Should -Invoke Find-Module `
                            -ParameterFilter { $Name -eq $moduleName `
                                            -and $Repository -eq $repository `
                                            -and $MaximumVersion -eq $maximumVersion }
                    }
        
                    It 'throws error if cannot find module with the maximum version in the specified repository' {
                        Mock Find-Module { return $Null } 
        
                        { Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails } | 
                            Should -Throw "Module '$ModuleName' with MaximumVersion $maximumVersion not found in repository '$repository'.  Exiting."
                    }
        
                    # We can't test the code branch where repository installation policy is not Trusted.
                    # Pester has a bug when mocking Set-PSRepository, causing it to throw an exception.
                    # See https://github.com/pester/Pester/issues/619
        
                    It 'attempts to install module with the maximum version for current user if module is found in specified repository' {
                        Mock Find-Module { return $foundModuleDetails } 
                        $repositoryDetails = Get-MockedRepositoryDetails -IsTrusted
                        Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }
        
                        Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails 

                        Should -Invoke Install-Module `
                            -ParameterFilter { $Name -eq $moduleName `
                                            -and $Repository -eq $repository `
                                            -and $Scope -eq 'CurrentUser' `
                                            -and $MaximumVersion -eq $maximumVersion } `
                            -Times 1 -Exactly
                    }

                    It 'throws error if module was not installed successfully' {
                        # Ensures second call to Get-InstalledModule, after call to Install-Module, doesn't return any info.
                        Mock Get-InstalledModule { return $Null }
                        
                        Mock Find-Module { return $foundModuleDetails } 
                        $repositoryDetails = Get-MockedRepositoryDetails -IsTrusted
                        Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }
        
                        { Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails } | 
                            Should -Throw "Unknown error installing module '$moduleName' with MaximumVersion $maximumVersion from repository '$repository'.  Exiting."
                    }
        
                    It 'does not throw error if module was installed successfully' {
                        # BeforeAll ensures the second call to Get-InstalledModule, after call to Install-Module, returns info 
                        # about module.
                        Mock Find-Module { return $foundModuleDetails } 
                        $repositoryDetails = Get-MockedRepositoryDetails -IsTrusted
                        Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }
        
                        { Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails } | Should -Not -Throw
                    } 
        
                    It 'logs the version of the module installed' {
                        Mock Find-Module { return $foundModuleDetails } 
                        $repositoryDetails = Get-MockedRepositoryDetails -IsTrusted
                        Mock Get-PSRepository -ParameterFilter { $Name -eq $repository } { return $repositoryDetails }
        
                        Install-RequiredModule -RepositoryName $repository -ModuleDetails $inputDetails 

                        Should -Invoke Write-Host -Scope It `
                            -ParameterFilter { $Object -eq "Version $repositoryModuleVersion of module '$moduleName' successfully installed."}
                    }
                }   
            }
        }
    }
}

#endregion Tests ***********************************************************************************************************