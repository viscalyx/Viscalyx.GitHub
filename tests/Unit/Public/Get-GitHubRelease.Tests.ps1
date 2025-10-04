[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param ()

BeforeDiscovery {
    try
    {
        if (-not (Get-Module -Name 'DscResource.Test'))
        {
            # Assumes dependencies have been resolved, so if this module is not available, run 'noop' task.
            if (-not (Get-Module -Name 'DscResource.Test' -ListAvailable))
            {
                # Redirect all streams to $null, except the error stream (stream 2)
                & "$PSScriptRoot/../../../build.ps1" -Tasks 'noop' 3>&1 4>&1 5>&1 6>&1 > $null
            }

            # If the dependencies have not been resolved, this will throw an error.
            Import-Module -Name 'DscResource.Test' -Force -ErrorAction 'Stop'
        }
    }
    catch [System.IO.FileNotFoundException]
    {
        throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -ResolveDependency -Tasks noop" first.'
    }
}

BeforeAll {
    $script:moduleName = 'Viscalyx.GitHub'

    Import-Module -Name $script:moduleName -Force -ErrorAction 'Stop'

    $PSDefaultParameterValues['InModuleScope:ModuleName'] = $script:moduleName
    $PSDefaultParameterValues['Mock:ModuleName'] = $script:moduleName
    $PSDefaultParameterValues['Should:ModuleName'] = $script:moduleName
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    $PSDefaultParameterValues.Remove('Mock:ModuleName')
    $PSDefaultParameterValues.Remove('Should:ModuleName')

    # Unload the module being tested so that it doesn't impact any other tests.
    Get-Module -Name $script:moduleName -All | Remove-Module -Force
}

Describe 'Get-GitHubRelease' {
    BeforeAll {
        Mock -CommandName Invoke-RestMethod -MockWith {
            $releaseDate = Get-Date

            return @(
                @{
                    id           = 1
                    name         = 'Release v1.1.0'
                    tag_name     = 'v1.1.0'
                    prerelease   = $false
                    created_at   = $releaseDate.AddDays(-2).ToString('o')
                    published_at = $releaseDate.AddDays(-2).ToString('o')
                    assets       = @(
                        @{
                            name                 = 'app-v1.1.0.zip'
                            size                 = 1024
                            browser_download_url = 'https://github.com/testowner/testrepo/releases/download/v1.1.0/app-v1.1.0.zip'
                        }
                    )
                },
                @{
                    id           = 2
                    name         = 'Release v1.2.0-beta'
                    tag_name     = 'v1.2.0-beta'
                    prerelease   = $true
                    created_at   = $releaseDate.AddDays(-1).ToString('o')
                    published_at = $releaseDate.AddDays(-1).ToString('o')
                    assets       = @(
                        @{
                            name                 = 'app-v1.2.0-beta.zip'
                            size                 = 1024
                            browser_download_url = 'https://github.com/testowner/testrepo/releases/download/v1.2.0-beta/app-v1.2.0-beta.zip'
                        }
                    )
                }
            )
        }
    }

    Context 'When retrieving releases without allowing prereleases' {
        BeforeAll {
            $testParams = @{
                OwnerName      = 'testOwner'
                RepositoryName = 'testRepo'
            }
        }

        It 'Should return the latest non-prerelease version' {
            $result = Get-GitHubRelease @testParams

            $result | Should -Not -BeNullOrEmpty
            $result.tag_name | Should -Be 'v1.1.0'
            $result.prerelease | Should -BeFalse
        }

        It 'Should call Invoke-RestMethod with the correct parameters' {
            $testParams = @{
                OwnerName      = 'testOwner'
                RepositoryName = 'testRepo'
            }

            $null = Get-GitHubRelease @testParams

            Should -Invoke -CommandName Invoke-RestMethod -ParameterFilter {
                $Uri -eq 'https://api.github.com/repos/testOwner/testRepo/releases' -and
                $Headers.Accept -eq 'application/vnd.github.v3+json' -and
                $Method -eq 'Get'
            } -Exactly -Times 1
        }
    }

    Context 'When retrieving releases with prerelease allowed' {
        BeforeAll {
            $testParams = @{
                OwnerName         = 'testOwner'
                RepositoryName    = 'testRepo'
                IncludePrerelease = $true
            }
        }

        It 'Should return the latest version including prereleases' {
            $result = Get-GitHubRelease @testParams -Latest

            $result | Should -Not -BeNullOrEmpty
            $result.tag_name | Should -Be 'v1.2.0-beta'
            $result.prerelease | Should -BeTrue
        }
    }

    Context 'When retrieving releases with a token' {
        BeforeAll {
            $testParams = @{
                OwnerName      = 'testOwner'
                RepositoryName = 'testRepo'
                Token          = ConvertTo-SecureString 'test-token' -AsPlainText -Force
            }
        }

        It 'Should call Invoke-RestMethod with the authorization header' {
            $null = Get-GitHubRelease @testParams

            Should -Invoke -CommandName Invoke-RestMethod -ParameterFilter {
                $Headers.Authorization -eq 'Bearer test-token'
            } -Exactly -Times 1
        }
    }

    Context 'When no releases are found' {
        BeforeAll {
            Mock -CommandName Invoke-RestMethod -MockWith {
                return @()
            }

            $testParams = @{
                OwnerName      = 'testOwner'
                RepositoryName = 'testRepo'
            }
        }

        It 'Should return null' {
            $result = Get-GitHubRelease @testParams

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When the API request fails' {
        BeforeAll {
            Mock -CommandName Invoke-RestMethod -MockWith {
                throw 'API request failed'
            }

            $testParams = @{
                OwnerName      = 'testOwner'
                RepositoryName = 'testRepo'
            }

            $errorMessage = InModuleScope -ScriptBlock {
                $script:localizedData.Get_GitHubRelease_Error_ApiRequest -f 'API request failed'
            }
        }

        It 'Should throw an error with the correct message' {
            {
                $null = Get-GitHubRelease @testParams -ErrorAction 'Stop'
            } | Should -Throw -ExpectedMessage $errorMessage
        }
    }
}
