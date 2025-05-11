[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param ()

BeforeDiscovery {
    try
    {
        if (-not (Get-Module -Name 'DscResource.Test'))
        {
            # Assumes dependencies has been resolved, so if this module is not available, run 'noop' task.
            if (-not (Get-Module -Name 'DscResource.Test' -ListAvailable))
            {
                # Redirect all streams to $null, except the error stream (stream 2)
                & "$PSScriptRoot/../../../build.ps1" -Tasks 'noop' 3>&1 4>&1 5>&1 6>&1 > $null
            }

            # If the dependencies has not been resolved, this will throw an error.
            Import-Module -Name 'DscResource.Test' -Force -ErrorAction 'Stop'
        }
    }
    catch [System.IO.FileNotFoundException]
    {
        throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -ResolveDependency -Tasks build" first.'
    }
}

BeforeAll {
    $script:dscModuleName = 'Viscalyx.GitHub'

    Import-Module -Name $script:dscModuleName

    $PSDefaultParameterValues['InModuleScope:ModuleName'] = $script:dscModuleName
    $PSDefaultParameterValues['Mock:ModuleName'] = $script:dscModuleName
    $PSDefaultParameterValues['Should:ModuleName'] = $script:dscModuleName
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    $PSDefaultParameterValues.Remove('Mock:ModuleName')
    $PSDefaultParameterValues.Remove('Should:ModuleName')

    # Unload the module being tested so that it doesn't impact any other tests.
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'Get-GitHubReleaseAssetMetadata' {
    BeforeAll {
        $mockReleaseDate = Get-Date

        $mockRelease = @{
            id           = 1
            name         = 'Release v1.0.0'
            tag_name     = 'v1.0.0'
            prerelease   = $false
            body         = 'Release notes for v1.0.0'
            created_at   = $mockReleaseDate.AddDays(-2).ToString('o')
            published_at = $mockReleaseDate.AddDays(-1).ToString('o')
            assets       = @(
                @{
                    name                 = 'app-v1.0.0.zip'
                    size                 = 1024
                    content_type         = 'application/zip'
                    browser_download_url = 'https://github.com/testOwner/testRepo/releases/download/v1.0.0/app-v1.0.0.zip'
                    created_at           = $mockReleaseDate.AddDays(-2).ToString('o')
                    updated_at           = $mockReleaseDate.AddDays(-1).ToString('o')
                    download_count       = 42
                },
                @{
                    name                 = 'app-v1.0.0.exe'
                    size                 = 2048
                    content_type         = 'application/octet-stream'
                    browser_download_url = 'https://github.com/testOwner/testRepo/releases/download/v1.0.0/app-v1.0.0.exe'
                    created_at           = $mockReleaseDate.AddDays(-2).ToString('o')
                    updated_at           = $mockReleaseDate.AddDays(-1).ToString('o')
                    download_count       = 24
                }
            )
        }

        Mock -CommandName Get-GitHubRelease -MockWith {
            return $mockRelease
        }
    }

    Context 'When retrieving asset metadata for an exact match' {
        BeforeAll {
            $testParams = @{
                OwnerName      = 'testOwner'
                RepositoryName = 'testRepo'
                AssetName      = 'app-v1.0.0.zip'
            }
        }

        It 'Should return the correct asset metadata' {
            $result = Get-GitHubReleaseAssetMetadata @testParams

            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'app-v1.0.0.zip'
            $result.Size | Should -Be 1024
            $result.content_type | Should -Be 'application/zip'
            $result.browser_download_url | Should -Be 'https://github.com/testOwner/testRepo/releases/download/v1.0.0/app-v1.0.0.zip'
        }
    }

    Context 'When retrieving asset metadata with a wildcard' {
        BeforeAll {
            $testParams = @{
                OwnerName      = 'testOwner'
                RepositoryName = 'testRepo'
                AssetName      = '*.zip'
            }
        }

        It 'Should return the metadata for the matching asset' {
            $result = Get-GitHubReleaseAssetMetadata @testParams

            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'app-v1.0.0.zip'
        }
    }

    Context 'When retrieving asset metadata with IncludePrerelease' {
        BeforeAll {
            $testParams = @{
                OwnerName         = 'testOwner'
                RepositoryName    = 'testRepo'
                AssetName         = 'app-v1.0.0.zip'
                IncludePrerelease = $true
            }
        }

        It 'Should call Get-GitHubRelease with IncludePrerelease parameter' {
            Get-GitHubReleaseAssetMetadata @testParams

            Should -Invoke -CommandName Get-GitHubRelease -ParameterFilter {
                $OwnerName -eq 'testOwner' -and
                $RepositoryName -eq 'testRepo' -and
                $IncludePrerelease -eq $true
            } -Exactly -Times 1
        }
    }

    Context 'When retrieving asset metadata with Token' {
        BeforeAll {
            $testParams = @{
                OwnerName      = 'testOwner'
                RepositoryName = 'testRepo'
                AssetName      = 'app-v1.0.0.zip'
                Token          = ConvertTo-SecureString -String "test-token" -AsPlainText -Force
            }
        }

        It 'Should call Get-GitHubRelease with Token parameter' {
            Get-GitHubReleaseAssetMetadata @testParams

            Should -Invoke -CommandName Get-GitHubRelease -ParameterFilter {
                $OwnerName -eq 'testOwner' -and
                $RepositoryName -eq 'testRepo' -and
                $null -ne $Token
            } -Exactly -Times 1
        }
    }

    Context 'When no releases are found' {
        BeforeAll {
            Mock -CommandName Get-GitHubRelease -MockWith {
                return $null
            }

            $testParams = @{
                OwnerName      = 'testOwner'
                RepositoryName = 'testRepo'
                AssetName      = 'app-v1.0.0.zip'
            }
        }

        It 'Should return null' {
            $result = Get-GitHubReleaseAssetMetadata @testParams

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When the specified asset is not found' {
        BeforeAll {
            $testParams = @{
                OwnerName      = 'testOwner'
                RepositoryName = 'testRepo'
                AssetName      = 'nonexistent-asset.zip'
            }

            $mockLocalizedStringMissingAsset = InModuleScope -ScriptBlock {
                $script:localizedData.Get_GitHubReleaseAssetMetadata_MissingAssetName
            }
        }

        It 'Should return null and write an error' {
            {
                Get-GitHubReleaseAssetMetadata @testParams -ErrorAction 'Stop'
            } | Should -Throw -ExpectedMessage $mockLocalizedStringMissingAsset

        }
    }
}
