[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Suppressing this rule because Script Analyzer does not understand Pester syntax.')]
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

    # Setup GitHub token for authentication to avoid rate limiting
    $script:gitHubToken = $null
    if ($env:GITHUB_TOKEN)
    {
        $script:gitHubToken = ConvertTo-SecureString -String $env:GITHUB_TOKEN -AsPlainText -Force
    }
}

Describe 'Get-GitHubRelease' {
    Context 'When retrieving releases without filters' {
        BeforeAll {
            # Using well-established repo for testing
            $testRepoOwner = 'PowerShell'
            $testRepoName = 'PowerShell'

            $getReleaseParams = @{
                OwnerName      = $testRepoOwner
                RepositoryName = $testRepoName
            }

            if ($script:gitHubToken)
            {
                $getReleaseParams.Token = $script:gitHubToken
            }

            $releases = Viscalyx.GitHub\Get-GitHubRelease @getReleaseParams
        }

        It 'Should return releases' {
            $releases | Should -Not -BeNullOrEmpty
        }

        It 'Should return multiple releases as an array' {
            $releases.GetType().Name | Should -Be 'Object[]'
        }

        It 'Should not include any prerelease versions' {
            $releases | Where-Object { $_.prerelease -eq $true } | Should -BeNullOrEmpty
        }

        It 'Should not include any draft releases' {
            $releases | Where-Object { $_.draft -eq $true } | Should -BeNullOrEmpty
        }
    }

    Context 'When retrieving only the latest release' {
        BeforeAll {
            # Using well-established repo for testing
            $testRepoOwner = 'PowerShell'
            $testRepoName = 'PowerShell'

            $getReleaseParams = @{
                OwnerName      = $testRepoOwner
                RepositoryName = $testRepoName
                Latest         = $true
            }

            if ($script:gitHubToken)
            {
                $getReleaseParams.Token = $script:gitHubToken
            }

            $release = Viscalyx.GitHub\Get-GitHubRelease @getReleaseParams
        }

        It 'Should return a single release' {
            $release | Should -Not -BeNullOrEmpty
            $release.GetType().Name | Should -Not -Be 'Object[]'
        }

        It 'Should not be a prerelease version' {
            $release.prerelease | Should -Be $false
        }

        It 'Should not be a draft release' {
            $release.draft | Should -Be $false
        }
    }

    Context 'When including prereleases' {
        BeforeAll {
            # Using well-established repo for testing
            $testRepoOwner = 'PowerShell'
            $testRepoName = 'PowerShell'
        }

        It 'Should include prerelease versions if they exist' {
            $getReleaseParams = @{
                OwnerName         = $testRepoOwner
                RepositoryName    = $testRepoName
                IncludePrerelease = $true
            }

            if ($script:gitHubToken)
            {
                $getReleaseParams.Token = $script:gitHubToken
            }

            $releases = Viscalyx.GitHub\Get-GitHubRelease @getReleaseParams

            $prereleases = $releases |
                Where-Object -FilterScript {
                    $_.prerelease -eq $true
                }

            $prereleases | Should -Not -BeNullOrEmpty
        }
    }

    Context 'When repository does not exist' {
        BeforeAll {
            $nonExistentOwner = 'ThisOwnerShouldNotExist12345'
            $nonExistentRepo = 'ThisRepoShouldNotExist12345'
        }

        It 'Should write an error for a non-existent repository' {
            $getReleaseParams = @{
                OwnerName      = $nonExistentOwner
                RepositoryName = $nonExistentRepo
                ErrorAction    = 'Stop'
            }

            if ($script:gitHubToken)
            {
                $getReleaseParams.Token = $script:gitHubToken
            }

            {
                Viscalyx.GitHub\Get-GitHubRelease @getReleaseParams
            } | Should -Throw
        }

        It 'Should return $null when ErrorAction is not Stop' {
            $getReleaseParams = @{
                OwnerName      = $nonExistentOwner
                RepositoryName = $nonExistentRepo
                ErrorAction    = 'SilentlyContinue'
            }

            if ($script:gitHubToken)
            {
                $getReleaseParams.Token = $script:gitHubToken
            }

            $result = Viscalyx.GitHub\Get-GitHubRelease @getReleaseParams

            $result | Should -BeNullOrEmpty
        }
    }
}
