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

Describe 'Get-GitHubRelease' {
    Context 'When retrieving releases without filters' {
        BeforeAll {
            # Using well-established repo for testing
            $testRepoOwner = 'PowerShell'
            $testRepoName = 'PowerShell'

            $releases = Get-GitHubRelease -OwnerName $testRepoOwner -RepositoryName $testRepoName
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

            $release = Get-GitHubRelease -OwnerName $testRepoOwner -RepositoryName $testRepoName -Latest
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

        It 'Should include prerelease versions if they exist' -Skip:($hasPrerelease -eq 0) {
            $releases = Get-GitHubRelease -OwnerName $testRepoOwner -RepositoryName $testRepoName -IncludePrerelease

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
            {
                Get-GitHubRelease -OwnerName $nonExistentOwner -RepositoryName $nonExistentRepo -ErrorAction 'Stop'
            } | Should -Throw
        }

        It 'Should return $null when ErrorAction is not Stop' {
            $result = Get-GitHubRelease -OwnerName $nonExistentOwner -RepositoryName $nonExistentRepo -ErrorAction 'SilentlyContinue'

            $result | Should -BeNullOrEmpty
        }
    }
}
