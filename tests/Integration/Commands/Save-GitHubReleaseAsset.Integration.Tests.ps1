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

Describe 'Save-GitHubReleaseAsset' {
    Context 'When downloading GitHub release assets' {
        BeforeAll {
            # We'll use a public GitHub repo that's likely to stay available
            $owner = 'PowerShell'
            $repo = 'PowerShell'

            # Define a small asset to download for testing
            $assetNamePattern = 'hashes.sha256'  # Usually a small file
        }

        It 'Should download assets when filtering by name' {
            # Get release assets that match our pattern
            $asset = Get-GitHubReleaseAsset -Owner $owner -Repository $repo -AssetName $assetNamePattern |
                      Select-Object -First 1

            # Skip the test if no assets are found
            if ($asset.Count -eq 0) {
                Set-ItResult -Skipped -Because "No assets matching '$assetNamePattern' found in the $owner/$repo repository"
                return
            }

            # Act
            $asset | Save-GitHubReleaseAsset -Path $TestDrive

            # Assert - check if files were downloaded
            $downloadedFile = Join-Path -Path $TestDrive -ChildPath $asset.name
            $downloadedFile | Should -Exist

            # Verify the file isn't empty
            (Get-Item -Path $downloadedFile).Length | Should -BeGreaterThan 0
        }
    }
}
