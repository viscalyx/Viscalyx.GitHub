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

    Import-Module -Name $script:moduleName

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
            Mock -CommandName Write-Warning -MockWith { }

            # Mock Write-Error
            Mock -CommandName Write-Error -MockWith { }
        }

        It 'Should create the download directory if it does not exist' {
            # Act
            $mockAssets | Save-GitHubReleaseAsset -Path 'TestDrive:\Downloads'

            # Assert
            Should -Invoke -CommandName Test-Path -ParameterFilter {
                $Path -eq 'TestDrive:\Downloads'
            } -Exactly -Times 1

            Should -Invoke -CommandName New-Item -ParameterFilter {
                $Path -eq 'TestDrive:\Downloads' -and $ItemType -eq 'Directory'
            } -Exactly -Times 1
        }

        It 'Should download all assets when no filter is specified' {
            # Act
            $mockAssets | Save-GitHubReleaseAsset -Path 'TestDrive:\Downloads'

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
            Mock -CommandName Write-Warning -MockWith { }
        }

        It 'Should download only assets matching the AssetName filter' {
            # Act
            $mockAssets | Save-GitHubReleaseAsset -Path 'TestDrive:\Downloads' -AssetName '*zip'

            # Assert
            Should -Invoke -CommandName Invoke-UrlDownload -Exactly -Times 2
            Should -Not -Invoke -CommandName Invoke-UrlDownload -ParameterFilter {
                $OutputPath -eq 'TestDrive:\Downloads\different-file.txt'
            }
        }

        It 'Should show warning when no assets match the filter' {
            # Act
            $mockAssets | Save-GitHubReleaseAsset -Path 'TestDrive:\Downloads' -AssetName 'nonexistent*'

            # Assert
            Should -Invoke -CommandName Write-Warning -ParameterFilter {
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

            # Mock Write-Error
            Mock -CommandName Write-Error -MockWith { }
        }

        It 'Should report errors for failed downloads' {
            # Act
            $mockAssets | Save-GitHubReleaseAsset -Path 'TestDrive:\Downloads'

            # Assert
            Should -Invoke -CommandName Invoke-UrlDownload -ParameterFilter {
                $Uri -eq 'https://example.com/asset1.zip'
            } -Exactly -Times 1

            Should -Invoke -CommandName Invoke-UrlDownload -ParameterFilter {
                $Uri -eq 'https://example.com/asset2.zip'
            } -Exactly -Times 1

            Should -Invoke -CommandName Write-Error -ParameterFilter {
                $Message -eq ($mockLocalizedDownloadFailed -f 'asset2.zip')
            } -Exactly -Times 1
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

            # Mock Write-Warning
            Mock -CommandName Write-Warning -MockWith { }

            # Mock Write-Error
            Mock -CommandName Write-Error -MockWith { }
        }

        It 'Should show warning when empty asset list is provided and not attempt downloads' {
            # Arrange
            $emptyAssets = @()

            # Act
            Save-GitHubReleaseAsset -InputObject $emptyAssets -Path 'TestDrive:\Downloads'

            # Assert
            Should -Invoke -CommandName Write-Warning -ParameterFilter {
                $Message -eq $mockLocalizedNoAssetsToDownload
            } -Exactly -Times 1

            Should -Not -Invoke -CommandName Invoke-UrlDownload
        }

        It 'Should handle null asset input without throwing errors or invoking downloads' {
            # Act & Assert - Should not throw
            { Save-GitHubReleaseAsset -InputObject $null -Path 'TestDrive:\Downloads' } | Should -Not -Throw

            # Assert
            Should -Not -Invoke -CommandName Invoke-UrlDownload
            Should -Invoke -CommandName Write-Warning -Exactly -Times 1 -Scope It
            Should -Not -Invoke -CommandName Write-Error
        }
    }
}
