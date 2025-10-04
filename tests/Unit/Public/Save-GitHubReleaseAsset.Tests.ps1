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

    $PSDefaultParameterValues['InModuleScope:ModuleName'] = $script:moduleName
    $PSDefaultParameterValues['Mock:ModuleName'] = $script:moduleName
    $PSDefaultParameterValues['Should:ModuleName'] = $script:moduleName

    # Get localized error messages
    $mockLocalizedCreatingDirectory = InModuleScope -ScriptBlock { $script:localizedData.Save_GitHubReleaseAsset_CreatingDirectory }
    $mockLocalizedAssetFiltered = InModuleScope -ScriptBlock { $script:localizedData.Save_GitHubReleaseAsset_AssetFiltered }
    $mockLocalizedNoAssetsToDownload = InModuleScope -ScriptBlock { $script:localizedData.Save_GitHubReleaseAsset_NoAssetsToDownload }
    $mockLocalizedDownloadingAssets = InModuleScope -ScriptBlock { $script:localizedData.Save_GitHubReleaseAsset_DownloadingAssets }
    $mockLocalizedDownloadingAsset = InModuleScope -ScriptBlock { $script:localizedData.Save_GitHubReleaseAsset_DownloadingAsset }
    $mockLocalizedDownloadFailed = InModuleScope -ScriptBlock { $script:localizedData.Save_GitHubReleaseAsset_DownloadFailed }
    $mockLocalizedDownloadsCompleted = InModuleScope -ScriptBlock { $script:localizedData.Save_GitHubReleaseAsset_DownloadsCompleted }
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    $PSDefaultParameterValues.Remove('Mock:ModuleName')
    $PSDefaultParameterValues.Remove('Should:ModuleName')

    # Unload the module being tested so that it doesn't impact any other tests.
    Get-Module -Name $script:moduleName -All | Remove-Module -Force
}

Describe 'Save-GitHubReleaseAsset' {
    Context 'When validating parameter sets' {
        BeforeDiscovery {
            $testCases = @(
                @{
                    ExpectedParameterSetName = 'ByInputObject'
                    ExpectedParameters = '-InputObject <psobject[]> -Path <string> [-AssetName <string>] [-MaxRetries <int>] [-FileHash <Object>] [-Overwrite] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]'
                }
                @{
                    ExpectedParameterSetName = 'ByUri'
                    ExpectedParameters = '-Path <string> -Uri <uri> [-AssetName <string>] [-MaxRetries <int>] [-FileHash <Object>] [-Overwrite] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]'
                }
            )
        }

        It 'Should have the correct parameters in parameter set <ExpectedParameterSetName>' -ForEach $testCases {
            $result = (Get-Command -Name 'Save-GitHubReleaseAsset').ParameterSets |
                Where-Object -FilterScript { $_.Name -eq $ExpectedParameterSetName } |
                Select-Object -Property @(
                    @{ Name = 'ParameterSetName'; Expression = { $_.Name } },
                    @{ Name = 'ParameterListAsString'; Expression = { $_.ToString() } }
                )

            $result.ParameterSetName | Should -Be $ExpectedParameterSetName
            $result.ParameterListAsString | Should -Be $ExpectedParameters
        }
    }

    Context 'When downloading assets with valid input' {
        BeforeAll {
            # Create mock assets
            $mockAssets = @(
                @{
                    name = 'asset1.zip'
                    browser_download_url = 'https://example.com/asset1.zip'
                },
                @{
                    name = 'asset2.zip'
                    browser_download_url = 'https://example.com/asset2.zip'
                }
            )

            # Mock Test-Path to always return false for the download path
            Mock -CommandName Test-Path -ParameterFilter {
                $Path -eq 'TestDrive:\Downloads'
            } -MockWith {
                return $false
            }

            # Mock New-Item to create the directory
            Mock -CommandName New-Item -MockWith {
                return [PSCustomObject]@{
                    Path = $Path
                }
            }

            # Mock Join-Path to return a predictable path
            Mock -CommandName Join-Path -MockWith {
                return "TestDrive:\Downloads\$ChildPath"
            }

            # Mock Invoke-UrlDownload to return success
            Mock -CommandName Invoke-UrlDownload -MockWith {
                return $true
            }

            # Mock Write-Warning
            Mock -CommandName Write-Warning

            # Mock Write-Error
            Mock -CommandName Write-Error
        }

        It 'Should create the download directory if it does not exist' {

            $null = $mockAssets | Save-GitHubReleaseAsset -Path 'TestDrive:\Downloads' -Confirm:$false

            Should -Invoke -CommandName New-Item -ParameterFilter {
                $Path -eq 'TestDrive:\Downloads' -and $ItemType -eq 'Directory'
            } -Exactly -Times 1
        }

        It 'Should download all assets when no filter is specified' {

            $null = $mockAssets | Save-GitHubReleaseAsset -Path 'TestDrive:\Downloads' -Confirm:$false

            Should -Invoke -CommandName Invoke-UrlDownload -Exactly -Times 2 -Scope It
        }
    }

    Context 'When filtering assets by name' {
        BeforeAll {
            # Create mock assets
            $mockAssets = @(
                @{
                    name = 'asset1.zip'
                    browser_download_url = 'https://example.com/asset1.zip'
                },
                @{
                    name = 'asset2.zip'
                    browser_download_url = 'https://example.com/asset2.zip'
                },
                @{
                    name = 'different-file.txt'
                    browser_download_url = 'https://example.com/different-file.txt'
                }
            )

            # Mock Test-Path to always return true for the download path
            Mock -CommandName Test-Path -ParameterFilter {
                $Path -eq 'TestDrive:\Downloads'
            } -MockWith {
                return $true
            }

            # Mock Join-Path to return a predictable path
            Mock -CommandName Join-Path -MockWith {
                return "TestDrive:\Downloads\$ChildPath"
            }

            # Mock Invoke-UrlDownload to return success
            Mock -CommandName Invoke-UrlDownload -MockWith {
                return $true
            }

            # Mock Write-Warning
            Mock -CommandName Write-Error
        }

        It 'Should download only assets matching the AssetName filter' {

            $null = $mockAssets | Save-GitHubReleaseAsset -Path 'TestDrive:\Downloads' -AssetName '*zip' -Confirm:$false

            Should -Invoke -CommandName Invoke-UrlDownload -Exactly -Times 2
            Should -Not -Invoke -CommandName Invoke-UrlDownload -ParameterFilter {
                $OutputPath -eq 'TestDrive:\Downloads\different-file.txt'
            }
        }

        It 'Should throw non-terminating error when no assets match the filter' {

            $null = $mockAssets | Save-GitHubReleaseAsset -Path 'TestDrive:\Downloads' -AssetName 'nonexistent*' -Confirm:$false

            Should -Invoke -CommandName Write-Error -ParameterFilter {
                $Message -eq $mockLocalizedNoAssetsToDownload
            } -Exactly -Times 1

            Should -Not -Invoke -CommandName Invoke-UrlDownload
        }
    }

    Context 'When a download fails' {
        BeforeAll {
            # Create mock assets
            $mockAssets = @(
                @{
                    name = 'asset1.zip'
                    browser_download_url = 'https://example.com/asset1.zip'
                },
                @{
                    name = 'asset2.zip' # This one will fail
                    browser_download_url = 'https://example.com/asset2.zip'
                }
            )

            # Mock Test-Path to always return true
            Mock -CommandName Test-Path -MockWith {
                return $true
            }

            # Mock Join-Path to return a predictable path
            Mock -CommandName Join-Path -MockWith {
                return "TestDrive:\Downloads\$ChildPath"
            }

            # Mock Invoke-UrlDownload to return success for asset1.zip but fail for asset2.zip
            Mock -CommandName Invoke-UrlDownload -MockWith {
                param ($Uri, $OutputPath)
                return ($Uri -eq 'https://example.com/asset1.zip')
            }
        }

        It 'Should report errors for failed downloads' {
            {
                $mockAssets |
                Save-GitHubReleaseAsset -Path 'TestDrive:\Downloads' -MaxRetries 0 -Confirm:$false -ErrorAction 'Stop'
            } | Should -Throw -ExpectedMessage "*Failed to download asset 'asset2.zip'*"

            Should -Invoke -CommandName Invoke-UrlDownload -ParameterFilter {
                $Uri -eq 'https://example.com/asset1.zip'
            } -Exactly -Times 1

            Should -Invoke -CommandName Invoke-UrlDownload -ParameterFilter {
                $Uri -eq 'https://example.com/asset2.zip'
            } -Exactly -Times 1
        }
    }

    Context 'When testing retry logic' {
        BeforeAll {
            # Mock Test-Path to always return true
            Mock -CommandName Test-Path -MockWith {
                return $true
            }

            # Mock Join-Path to return a predictable path
            Mock -CommandName Join-Path -MockWith {
                return "TestDrive:\Downloads\$ChildPath"
            }

            # Mock Write-Error
            Mock -CommandName Write-Error

            # Mock Start-Sleep to avoid actual delays in tests
            Mock -CommandName Start-Sleep
        }

        It 'Should retry failed download up to MaxRetries times' {
            $mockAsset = @{
                name = 'test-asset.zip'
                browser_download_url = 'https://example.com/test-asset.zip'
            }

            # Mock Invoke-UrlDownload to fail every time
            Mock -CommandName Invoke-UrlDownload -MockWith {
                throw 'Download failed'
            }


            {
                $mockAsset |
                    Save-GitHubReleaseAsset -Path 'TestDrive:\Downloads' -MaxRetries 3 -Confirm:$false -ErrorAction 'Stop'
            } | Should -Throw -ExpectedMessage "*Download failed*"

            # Assert - Should be called 4 times (1 initial + 3 retries)
            Should -Invoke -CommandName Invoke-UrlDownload -Exactly -Times 4 -Scope It

            # Should sleep 3 times (after each retry except the last)
            Should -Invoke -CommandName Start-Sleep -Exactly -Times 3 -Scope It
        }

        It 'Should use exponential backoff for retry delays' {
            $mockAsset = @{
                name = 'test-asset.zip'
                browser_download_url = 'https://example.com/test-asset.zip'
            }

            # Mock Invoke-UrlDownload to fail every time
            Mock -CommandName Invoke-UrlDownload -MockWith {
                throw 'Download failed'
            }


            {
                $mockAsset |
                    Save-GitHubReleaseAsset -Path 'TestDrive:\Downloads' -MaxRetries 3 -Confirm:$false -ErrorAction 'Stop'
            } | Should -Throw -ExpectedMessage "*Download failed*"

            # Assert - Should sleep with exponential backoff (2^1, 2^2, 2^3)
            Should -Invoke -CommandName Start-Sleep -ParameterFilter {
                $Seconds -eq 2
            } -Exactly -Times 1 -Scope It

            Should -Invoke -CommandName Start-Sleep -ParameterFilter {
                $Seconds -eq 4
            } -Exactly -Times 1 -Scope It

            Should -Invoke -CommandName Start-Sleep -ParameterFilter {
                $Seconds -eq 8
            } -Exactly -Times 1 -Scope It
        }

        It 'Should stop retrying once download succeeds' {
            $mockAsset = @{
                name = 'test-asset.zip'
                browser_download_url = 'https://example.com/test-asset.zip'
            }

            $script:attemptCount = 0

            # Mock Invoke-UrlDownload to succeed on the 2nd attempt
            Mock -CommandName Invoke-UrlDownload -MockWith {
                $script:attemptCount++
                if ($script:attemptCount -eq 2)
                {
                    return $true
                }
                throw 'Download failed'
            }


            $null = $mockAsset | Save-GitHubReleaseAsset -Path 'TestDrive:\Downloads' -MaxRetries 3 -Confirm:$false

            # Assert - Should be called only 2 times (1 initial fail + 1 successful retry)
            Should -Invoke -CommandName Invoke-UrlDownload -Exactly -Times 2 -Scope It

            # Should sleep only once (after first failure)
            Should -Invoke -CommandName Start-Sleep -Exactly -Times 1 -Scope It

            # Should not write error since it eventually succeeded
            Should -Not -Invoke -CommandName Write-Error -Scope It
        }

        It 'Should respect MaxRetries parameter when set to 0' {
            $mockAsset = @{
                name = 'test-asset.zip'
                browser_download_url = 'https://example.com/test-asset.zip'
            }

            # Mock Invoke-UrlDownload to fail
            Mock -CommandName Invoke-UrlDownload -MockWith {
                throw 'Download failed'
            }


            {
                $mockAsset |
                    Save-GitHubReleaseAsset -Path 'TestDrive:\Downloads' -MaxRetries 0 -Confirm:$false -ErrorAction 'Stop'
            } | Should -Throw -ExpectedMessage "*Download failed*"

            # Assert - Should be called only 1 time (no retries)
            Should -Invoke -CommandName Invoke-UrlDownload -Exactly -Times 1 -Scope It

            # Should not sleep at all
            Should -Not -Invoke -CommandName Start-Sleep -Scope It
        }

        It 'Should write error message when all retries are exhausted' {
            $mockAsset = @{
                name = 'test-asset.zip'
                browser_download_url = 'https://example.com/test-asset.zip'
            }

            # Mock Invoke-UrlDownload to fail every time
            Mock -CommandName Invoke-UrlDownload -MockWith {
                throw 'Download failed'
            }

            {
                $mockAsset |
                    Save-GitHubReleaseAsset -Path 'TestDrive:\Downloads' -MaxRetries 2 -Confirm:$false -ErrorAction 'Stop'
            } | Should -Throw -ExpectedMessage "*Download failed*"
        }

        It 'Should handle multiple assets with mixed success and retry patterns' {
            $mockAssets = @(
                @{
                    name = 'asset1.zip'
                    browser_download_url = 'https://example.com/asset1.zip'
                },
                @{
                    name = 'asset2.zip'
                    browser_download_url = 'https://example.com/asset2.zip'
                }
            )

            $script:asset1Attempts = 0
            $script:asset2Attempts = 0

            # Mock Invoke-UrlDownload with different behaviors per asset
            Mock -CommandName Invoke-UrlDownload -MockWith {
                param($Uri)

                if ($Uri -eq 'https://example.com/asset1.zip')
                {
                    # Succeeds immediately
                    return $true
                }
                elseif ($Uri -eq 'https://example.com/asset2.zip')
                {
                    # Fails once, then succeeds
                    $script:asset2Attempts++
                    if ($script:asset2Attempts -eq 2)
                    {
                        return $true
                    }
                    throw 'Download failed'
                }
                else
                {
                    # Always fails
                    throw 'Download failed'
                }
            }


            $null = $mockAssets | Save-GitHubReleaseAsset -Path 'TestDrive:\Downloads' -MaxRetries 2 -Confirm:$false

            # asset1: 1 call (success)
            # asset2: 2 calls (1 fail + 1 success)
            # Total: 3 calls
            Should -Invoke -CommandName Invoke-UrlDownload -Exactly -Times 3 -Scope It

            # asset2: 1 sleep (after first failure)
            # Total: 1 sleeps
            Should -Invoke -CommandName Start-Sleep -Exactly -Times 1 -Scope It
        }
    }

    Context 'When handling edge cases' {
        BeforeAll {
            # Mock Test-Path to always return true for the download path
            Mock -CommandName Test-Path -ParameterFilter {
                $Path -eq 'TestDrive:\Downloads'
            } -MockWith {
                return $true
            }

            # Mock Join-Path to return a predictable path
            Mock -CommandName Join-Path -MockWith {
                return "TestDrive:\Downloads\$ChildPath"
            }

            # Mock Invoke-UrlDownload to return success
            Mock -CommandName Invoke-UrlDownload -MockWith {
                return $true
            }

            # Mock Write-Error
            Mock -CommandName Write-Error
        }

        It 'Should show warning when empty asset list is provided and not attempt downloads' {
            $emptyAssets = @()


            $null = Save-GitHubReleaseAsset -InputObject $emptyAssets -Path 'TestDrive:\Downloads' -Confirm:$false

            Should -Invoke -CommandName Write-Error -ParameterFilter {
                $Message -eq $mockLocalizedNoAssetsToDownload
            } -Exactly -Times 1

            Should -Not -Invoke -CommandName Invoke-UrlDownload
        }

        It 'Should handle null asset input without throwing errors or invoking downloads' {
            $null = Save-GitHubReleaseAsset -InputObject $null -Path 'TestDrive:\Downloads' -Confirm:$false

            Should -Not -Invoke -CommandName Invoke-UrlDownload
            Should -Invoke -CommandName Write-Error
        }
    }

    Context 'When using the Overwrite parameter' {
        BeforeAll {
            # Create mock assets
            $mockAssets = @(
                @{
                    name = 'asset1.zip'
                    browser_download_url = 'https://example.com/asset1.zip'
                }
            )

            # Mock Test-Path to always return true for the download path
            Mock -CommandName Test-Path -ParameterFilter {
                $Path -eq 'TestDrive:\Downloads'
            } -MockWith {
                return $true
            }

            # Mock Join-Path to return a predictable path
            Mock -CommandName Join-Path -MockWith {
                return "TestDrive:\Downloads\$ChildPath"
            }

            # Mock Invoke-UrlDownload to return success
            Mock -CommandName Invoke-UrlDownload -MockWith {
                return $true
            }
        }

        It 'Should pass Force parameter to Invoke-UrlDownload when Overwrite is specified' {

            $null = $mockAssets | Save-GitHubReleaseAsset -Path 'TestDrive:\Downloads' -Overwrite -Confirm:$false

            Should -Invoke -CommandName Invoke-UrlDownload -ParameterFilter {
                $Force -eq $true
            } -Exactly -Times 1
        }

        It 'Should not pass Force parameter to Invoke-UrlDownload when Overwrite is not specified' {

            $null = $mockAssets | Save-GitHubReleaseAsset -Path 'TestDrive:\Downloads' -Confirm:$false

            Should -Invoke -CommandName Invoke-UrlDownload -ParameterFilter {
                $Force -eq $false
            } -Exactly -Times 1
        }
    }

    Context 'When using ShouldProcess' {
        BeforeAll {
            # Create mock asset
            $mockAsset = @{
                name = 'asset1.zip'
                browser_download_url = 'https://example.com/asset1.zip'
            }

            # Mock Test-Path to return false for the download path (directory doesn't exist)
            Mock -CommandName Test-Path -ParameterFilter {
                $Path -eq 'TestDrive:\Downloads'
            } -MockWith {
                return $false
            }

            # Mock New-Item to create the directory
            Mock -CommandName New-Item -MockWith {
                return [PSCustomObject]@{
                    Path = $Path
                }
            }

            # Mock Join-Path to return a predictable path
            Mock -CommandName Join-Path -MockWith {
                return "TestDrive:\Downloads\$ChildPath"
            }

            # Mock Invoke-UrlDownload to return success
            Mock -CommandName Invoke-UrlDownload -MockWith {
                return $true
            }
        }

        It 'Should support WhatIf and not create directory or download files' {

            $mockAsset | Save-GitHubReleaseAsset -Path 'TestDrive:\Downloads' -WhatIf

            # Assert - directory creation should not be called
            Should -Invoke -CommandName New-Item -Exactly -Times 0

            # Assert - download should not be called
            Should -Invoke -CommandName Invoke-UrlDownload -Exactly -Times 0
        }

        It 'Should create directory and download files when Confirm is suppressed' {

            $null = $mockAsset | Save-GitHubReleaseAsset -Path 'TestDrive:\Downloads' -Confirm:$false

            # Assert - directory creation should be called
            Should -Invoke -CommandName New-Item -Exactly -Times 1

            # Assert - download should be called
            Should -Invoke -CommandName Invoke-UrlDownload -Exactly -Times 1
        }

        It 'Should skip download when user declines ShouldProcess for individual asset' {
            # Mock Test-Path to return true (directory exists)
            Mock -CommandName Test-Path -ParameterFilter {
                $Path -eq 'TestDrive:\Downloads'
            } -MockWith {
                return $true
            }

            $mockAsset | Save-GitHubReleaseAsset -Path 'TestDrive:\Downloads' -WhatIf

            # Assert - download should not be called
            Should -Invoke -CommandName Invoke-UrlDownload -Exactly -Times 0
        }
    }
}
