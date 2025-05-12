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
            $testParams = @{
                OwnerName = 'PowerShell'
                RepositoryName = 'PowerShell'
                AssetName = 'PowerShell-*.zip'
            }
        }

        It 'Should not throw when retrieving the latest release asset' {
            { Get-GitHubReleaseAsset @testParams } | Should -Not -Throw
        }

        It 'Should return the correct metadata format' {
            $result = Get-GitHubReleaseAsset @testParams

            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Match 'PowerShell-.*\.zip$'
            $result.Size | Should -BeGreaterThan 0
            $result.browser_download_url | Should -Match 'https://github.com/PowerShell/PowerShell/releases/download/.*'
        }
    }

    Context 'When retrieving release asset with IncludePrerelease' {
        BeforeAll {
            $testParams = @{
                OwnerName = 'PowerShell'
                RepositoryName = 'PowerShell'
                AssetName = 'PowerShell-*.zip'
                IncludePrerelease = $true
            }
        }

        It 'Should not throw when retrieving the latest release asset including prereleases' {
            { Get-GitHubReleaseAsset @testParams } | Should -Not -Throw
        }
    }

    Context 'When repository does not exist' {
        BeforeAll {
            $testParams = @{
                OwnerName = 'PowerShell'
                RepositoryName = 'NonExistentRepository9876543210'
                AssetName = 'test.zip'
            }
        }

        It 'Should throw when accessing a nonexistent repository' {
            { Get-GitHubReleaseAsset @testParams -ErrorAction 'Stop' } | Should -Throw
        }
    }

    Context 'When asset does not exist' {
        BeforeAll {
            $testParams = @{
                OwnerName = 'PowerShell'
                RepositoryName = 'PowerShell'
                AssetName = 'NonExistentAsset9876543210.zip'
            }
        }

        It 'Should not throw but return null when the asset is not found' {
            {
                $result = Get-GitHubReleaseAsset @testParams -ErrorAction 'Stop'
            } |  Should -Throw
        }
    }

    Context 'When passing release through pipeline' {
        BeforeAll {
            $testParams = @{
                OwnerName = 'PowerShell'
                RepositoryName = 'PowerShell'
                IncludePrerelease = $true
            }
        }

        It 'Should not throw when retrieving the latest release asset including prereleases' {
            $release = Get-GitHubRelease @testParams
            $release | Should -Not -BeNullOrEmpty

            $result = $release | Get-GitHubReleaseAsset -AssetName 'PowerShell-*.zip'

            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Match 'PowerShell-.*\.zip$'
            $result.Size | Should -BeGreaterThan 0
            $result.browser_download_url | Should -Match 'https://github.com/PowerShell/PowerShell/releases/download/.*'
        }
    }
}
