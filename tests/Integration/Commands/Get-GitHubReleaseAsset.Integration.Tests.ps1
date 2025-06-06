[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Suppressing this rule because Script Analyzer does not understand Pester syntax.')]
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
}

Describe 'Get-GitHubReleaseAsset' {
    Context 'When retrieving release asset metadata from a public repository' {
        BeforeAll {
            $getGitHubReleaseParameters = @{
                OwnerName = 'PowerShell'
                RepositoryName = 'PowerShell'
                AssetName = 'PowerShell-*.zip'
            }
        }

        It 'Should not throw when retrieving the latest release asset' {
            { Get-GitHubReleaseAsset @getGitHubReleaseParameters } | Should -Not -Throw
        }

        It 'Should return the correct metadata format' {
            $result = Get-GitHubReleaseAsset @getGitHubReleaseParameters

            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Match 'PowerShell-.*\.zip$'
            $result.Size | Should -BeGreaterThan 0
            $result.browser_download_url | Should -Match 'https://github.com/PowerShell/PowerShell/releases/download/.*'
        }
    }

    Context 'When retrieving release asset with IncludePrerelease' {
        BeforeAll {
            $getGitHubReleaseParameters = @{
                OwnerName = 'PowerShell'
                RepositoryName = 'PowerShell'
                AssetName = 'PowerShell-*.zip'
                IncludePrerelease = $true
            }
        }

        It 'Should not throw when retrieving the latest release asset including prereleases' {
            { Get-GitHubReleaseAsset @getGitHubReleaseParameters } | Should -Not -Throw
        }
    }

    Context 'When repository does not exist' {
        BeforeAll {
            $getGitHubReleaseParameters = @{
                OwnerName = 'PowerShell'
                RepositoryName = 'NonExistentRepository9876543210'
                AssetName = 'test.zip'
            }
        }

        It 'Should throw when accessing a nonexistent repository' {
            { Get-GitHubReleaseAsset @getGitHubReleaseParameters -ErrorAction 'Stop' } | Should -Throw
        }
    }

    Context 'When asset does not exist' {
        BeforeAll {
            $getGitHubReleaseParameters = @{
                OwnerName = 'PowerShell'
                RepositoryName = 'PowerShell'
                AssetName = 'NonExistentAsset9876543210.zip'
            }
        }

        It 'Should not throw but return null when the asset is not found' {
            {
                $result = Get-GitHubReleaseAsset @getGitHubReleaseParameters -ErrorAction 'Stop'
            } |  Should -Throw
        }
    }

    Context 'When passing release through pipeline' {
        BeforeAll {
            $getGitHubReleaseParameters = @{
                OwnerName = 'PowerShell'
                RepositoryName = 'PowerShell'
            }
        }

        It 'Should correctly process release objects received through the pipeline' {
            $release = Get-GitHubRelease @getGitHubReleaseParameters |
                Where-Object -FilterScript {
                    $_.prerelease -eq $false -and $_.draft -eq $false
                } |
                Select-Object -First 1

            $release | Should -Not -BeNullOrEmpty

            $result = $release | Get-GitHubReleaseAsset -AssetName 'PowerShell-*.zip'

            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Match 'PowerShell-.*\.zip$'
            $result.Size | Should -BeGreaterThan 0
            $result.browser_download_url | Should -Match 'https://github.com/PowerShell/PowerShell/releases/download/.*'
        }

        Context 'When asset does not exist' {
            It 'Should not throw but return null when the asset is not found' {

                $release = Get-GitHubRelease @getGitHubReleaseParameters |
                    Where-Object -FilterScript {
                        $_.prerelease -eq $false -and $_.draft -eq $false
                    } |
                    Select-Object -First 1

                $release | Should -Not -BeNullOrEmpty

                {
                    $release | Get-GitHubReleaseAsset -AssetName 'NonExistentAsset9876543210.zip' -ErrorAction 'Stop'
                } |  Should -Throw
            }
        }
    }

    Context 'When passing multiple releases through pipeline' {
        BeforeAll {
            $getGitHubReleaseParameters = @{
                OwnerName = 'PowerShell'
                RepositoryName = 'PowerShell'
            }
        }

        It 'Should correctly process multiple release objects received through the pipeline' {
            $releases = Get-GitHubRelease @getGitHubReleaseParameters |
                Where-Object -FilterScript {
                    $_.prerelease -eq $false -and $_.draft -eq $false
                } |
                Select-Object -First 3

            $releases | Should -Not -BeNullOrEmpty
            $releases.Count | Should -BeGreaterOrEqual 1

            $result = $releases | Get-GitHubReleaseAsset -AssetName 'PowerShell-*win-arm64.zip'

            $result | Should -Not -BeNullOrEmpty

            $result | Should -HaveCount 3

            $result[0].Name | Should -Match 'PowerShell-.*\win-arm64.zip$'
            $result[1].Name | Should -Match 'PowerShell-.*\win-arm64.zip$'
            $result[2].Name | Should -Match 'PowerShell-.*\win-arm64.zip$'
        }
    }

    Context 'When passing a release with no assets through pipeline' {
        BeforeAll {
            $getGitHubReleaseParameters = @{
                OwnerName = 'PowerShell'
                RepositoryName = 'PowerShell'
            }
        }

        It 'Should throw non-terminating error but return null' {
            # Find a release with assets so we can create a mock release without assets
            $release = Get-GitHubRelease @getGitHubReleaseParameters |
                Where-Object -FilterScript {
                    $_.prerelease -eq $false -and $_.draft -eq $false
                } |
                Select-Object -First 1

            $release | Should -Not -BeNullOrEmpty

            # Create a clone of the release object but without assets
            $mockReleaseWithoutAssets = $release | Select-Object * -ExcludeProperty assets
            $mockReleaseWithoutAssets | Add-Member -MemberType NoteProperty -Name 'assets' -Value @() -Force

            # Verify the mock is setup correctly
            $mockReleaseWithoutAssets.assets.Count | Should -Be 0

            # Test the behavior with a release that has no assets
            $result = $mockReleaseWithoutAssets | Get-GitHubReleaseAsset -AssetName 'PowerShell-*.zip' -ErrorAction 'SilentlyContinue'
            $result | Should -BeNullOrEmpty
        }

        It 'Should throw terminating error with ErrorAction set to Stop' {
            # Find a release with assets
            $release = Get-GitHubRelease @getGitHubReleaseParameters |
                Where-Object -FilterScript {
                    $_.prerelease -eq $false -and $_.draft -eq $false
                } |
                Select-Object -First 1

            $release | Should -Not -BeNullOrEmpty

            {
                $release | Get-GitHubReleaseAsset -AssetName 'CompletelyNonExistentPattern*.xyz' -ErrorAction 'Stop'
            } | Should -Throw
        }
    }
}
