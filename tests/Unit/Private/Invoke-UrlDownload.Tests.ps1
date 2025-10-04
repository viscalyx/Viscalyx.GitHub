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
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    $PSDefaultParameterValues.Remove('Mock:ModuleName')
    $PSDefaultParameterValues.Remove('Should:ModuleName')

    # Unload the module being tested so that it doesn't impact any other tests.
    Get-Module -Name $script:moduleName -All | Remove-Module -Force
}

Describe 'Invoke-UrlDownload' {
    Context 'When validating output directory' {
        BeforeAll {
            Mock -CommandName Invoke-WebRequest
            Mock -CommandName New-Item
        }

        It 'Should create the directory when it does not exist' {
            # Arrange
            $testUri = 'https://example.com/file.zip'
            $testOutputPath = Join-Path -Path 'TestDrive:' -ChildPath 'Downloads' | Join-Path -ChildPath 'NewFolder' | Join-Path -ChildPath 'file.zip'
            $expectedDirectory = Split-Path -Path $testOutputPath -Parent

            Mock -CommandName Test-Path -MockWith { $false }

            # Act
            $result = InModuleScope -ScriptBlock {
                param($Uri, $Path)
                Invoke-UrlDownload -Uri $Uri -OutputPath $Path
            } -Parameters @{
                Uri = $testUri
                Path = $testOutputPath
            }

            # Assert
            $result | Should -BeTrue
            Should -Invoke -CommandName New-Item -ParameterFilter {
                $ItemType -eq 'Directory' -and
                $Force -eq $true
            } -Exactly -Times 1 -Scope It
        }

        It 'Should not create the directory when it already exists' {
            # Arrange
            $testUri = 'https://example.com/file.zip'
            $testOutputPath = Join-Path -Path 'TestDrive:' -ChildPath 'Downloads' | Join-Path -ChildPath 'ExistingFolder' | Join-Path -ChildPath 'file.zip'
            $expectedDirectory = Split-Path -Path $testOutputPath -Parent

            Mock -CommandName Test-Path -MockWith {
                param($Path)
                # Return true for directory, false for file
                $Path -eq $expectedDirectory
            }

            # Act
            $result = InModuleScope -ScriptBlock {
                param($Uri, $Path)
                Invoke-UrlDownload -Uri $Uri -OutputPath $Path
            } -Parameters @{
                Uri = $testUri
                Path = $testOutputPath
            }

            # Assert
            $result | Should -BeTrue
            Should -Invoke -CommandName New-Item -Exactly -Times 0 -Scope It
        }

        It 'Should throw a terminating error when directory creation fails' {
            # Arrange
            $testUri = 'https://example.com/file.zip'
            $testOutputPath = Join-Path -Path 'TestDrive:' -ChildPath 'InvalidPath' | Join-Path -ChildPath 'file.zip'
            $expectedDirectory = Split-Path -Path $testOutputPath -Parent
            $mockErrorMessage = 'Access denied'

            Mock -CommandName Test-Path -MockWith { $false }
            Mock -CommandName New-Item -MockWith {
                throw [System.UnauthorizedAccessException]::new($mockErrorMessage)
            }

            $mockLocalizedError = InModuleScope -ScriptBlock { $script:localizedData.Invoke_UrlDownload_DirectoryCreationError }

            # Act & Assert
            {
                InModuleScope -ScriptBlock {
                    param($Uri, $Path)
                    Invoke-UrlDownload -Uri $Uri -OutputPath $Path
                } -Parameters @{
                    Uri = $testUri
                    Path = $testOutputPath
                }
            } | Should -Throw -ExpectedMessage ($mockLocalizedError -f $expectedDirectory, $mockErrorMessage)

            Should -Invoke -CommandName New-Item -Exactly -Times 1 -Scope It
        }
    }

    Context 'When downloading a file successfully' {
        BeforeAll {
            # Mock Invoke-WebRequest to simulate successful download
            Mock -CommandName Invoke-WebRequest
            Mock -CommandName Test-Path -MockWith { $false }
        }

        It 'Should return true when the download completes successfully' {
            # Arrange
            $testUri = 'https://example.com/file.zip'
            $testOutputPath = Join-Path -Path 'TestDrive:' -ChildPath 'Downloads' | Join-Path -ChildPath 'file.zip'

            # Act
            $result = InModuleScope -ScriptBlock {
                param($Uri, $Path)
                Invoke-UrlDownload -Uri $Uri -OutputPath $Path
            } -Parameters @{
                Uri = $testUri
                Path = $testOutputPath
            }

            # Assert
            $result | Should -BeTrue

            # UseBasicParsing only exists on Desktop edition (PS 5.1)
            if ($PSVersionTable.PSEdition -eq 'Desktop')
            {
                Should -Invoke -CommandName Invoke-WebRequest -ParameterFilter {
                    $Uri -eq $testUri -and
                    $OutFile -eq $testOutputPath -and
                    $UserAgent -eq 'Viscalyx.GitHub' -and
                    $UseBasicParsing -eq $true
                } -Exactly -Times 1 -Scope It
            }
            else
            {
                Should -Invoke -CommandName Invoke-WebRequest -ParameterFilter {
                    $Uri -eq $testUri -and
                    $OutFile -eq $testOutputPath -and
                    $UserAgent -eq 'Viscalyx.GitHub'
                } -Exactly -Times 1 -Scope It
            }
        }

        It 'Should use the provided user agent' {
            # Arrange
            $testUri = 'https://example.com/file.zip'
            $testOutputPath = Join-Path -Path 'TestDrive:' -ChildPath 'Downloads' | Join-Path -ChildPath 'file.zip'
            $testUserAgent = 'CustomAgent'

            # Act
            $result = InModuleScope -ScriptBlock {
                param($Uri, $Path, $Agent)
                Invoke-UrlDownload -Uri $Uri -OutputPath $Path -UserAgent $Agent
            } -Parameters @{
                Uri = $testUri
                Path = $testOutputPath
                Agent = $testUserAgent
            }

            # Assert
            $result | Should -BeTrue

            # UseBasicParsing only exists on Desktop edition (PS 5.1)
            if ($PSVersionTable.PSEdition -eq 'Desktop')
            {
                Should -Invoke -CommandName Invoke-WebRequest -ParameterFilter {
                    $Uri -eq $testUri -and
                    $OutFile -eq $testOutputPath -and
                    $UserAgent -eq $testUserAgent -and
                    $UseBasicParsing -eq $true
                } -Exactly -Times 1 -Scope It
            }
            else
            {
                Should -Invoke -CommandName Invoke-WebRequest -ParameterFilter {
                    $Uri -eq $testUri -and
                    $OutFile -eq $testOutputPath -and
                    $UserAgent -eq $testUserAgent
                } -Exactly -Times 1 -Scope It
            }
        }
    }

    Context 'When the file already exists' {
        BeforeAll {
            Mock -CommandName Invoke-WebRequest
        }

        It 'Should skip download and return true when file exists and Force is not specified' {
            # Arrange
            $testUri = 'https://example.com/file.zip'
            $testOutputPath = Join-Path -Path 'TestDrive:' -ChildPath 'Downloads' | Join-Path -ChildPath 'file.zip'

            Mock -CommandName Test-Path -MockWith { $true }

            # Act
            $result = InModuleScope -ScriptBlock {
                param($Uri, $Path)
                Invoke-UrlDownload -Uri $Uri -OutputPath $Path
            } -Parameters @{
                Uri = $testUri
                Path = $testOutputPath
            }

            # Assert
            $result | Should -BeTrue
            Should -Invoke -CommandName Invoke-WebRequest -Exactly -Times 0 -Scope It
        }

        It 'Should download file when file exists and Force is specified' {
            # Arrange
            $testUri = 'https://example.com/file.zip'
            $testOutputPath = Join-Path -Path 'TestDrive:' -ChildPath 'Downloads' | Join-Path -ChildPath 'file.zip'

            Mock -CommandName Test-Path -MockWith { $true }

            # Act
            $result = InModuleScope -ScriptBlock {
                param($Uri, $Path)
                Invoke-UrlDownload -Uri $Uri -OutputPath $Path -Force
            } -Parameters @{
                Uri = $testUri
                Path = $testOutputPath
            }

            # Assert
            $result | Should -BeTrue
            Should -Invoke -CommandName Invoke-WebRequest -Exactly -Times 1 -Scope It
        }
    }

    Context 'When a download fails with network errors' {
        BeforeAll {
            $mockLocalizedNetworkError = InModuleScope -ScriptBlock { $script:localizedData.Invoke_UrlDownload_NetworkError }
        }

        It 'Should return false and write a network error when download fails with WebException' {
            # Arrange
            $testUri = 'https://example.com/file.zip'
            $testOutputPath = Join-Path -Path 'TestDrive:' -ChildPath 'Downloads' | Join-Path -ChildPath 'file.zip'

            Mock -CommandName Test-Path -MockWith { $false }

            # Mock Invoke-WebRequest to throw a WebException
            Mock -CommandName Invoke-WebRequest -MockWith {
                $webException = [System.Net.WebException]::new('Network error')
                throw $webException
            }

            # Act
            {
                InModuleScope -ScriptBlock {
                    param($Uri, $Path)
                    Invoke-UrlDownload -Uri $Uri -OutputPath $Path -ErrorAction 'Stop'
                } -Parameters @{
                    Uri = $testUri
                    Path = $testOutputPath
                }
            } | Should -Throw -ExpectedMessage ($mockLocalizedNetworkError -f $testUri, 'Network error')
        }

        It 'Should return false and write a not found error when download fails with 404' {
            # Arrange
            $testUri = 'https://example.com/file.zip'
            $testOutputPath = Join-Path -Path 'TestDrive:' -ChildPath 'Downloads' | Join-Path -ChildPath 'file.zip'

            Mock -CommandName Test-Path -MockWith { $false }

            $mockLocalizedNotFoundError = InModuleScope -ScriptBlock { $script:localizedData.Invoke_UrlDownload_NotFoundError }

            # Mock Invoke-WebRequest to throw a 404 WebException
            Mock -CommandName Invoke-WebRequest -MockWith {
                $response = [PSCustomObject]@{
                    StatusCode = [PSCustomObject]@{ value__ = 404 }
                }

                # Add the type name manually
                $response.PSObject.TypeNames.Insert(0, 'System.Net.HttpWebResponse')

                $webException = [System.Net.WebException]::new('The remote server returned an error: (404) Not Found.')
                $webException | Add-Member -MemberType NoteProperty -Name 'Response' -Value $response -Force

                throw $webException
            }

            # Act
            {
                InModuleScope -ScriptBlock {
                    param($Uri, $Path)
                    Invoke-UrlDownload -Uri $Uri -OutputPath $Path -ErrorAction 'Stop'
                } -Parameters @{
                    Uri = $testUri
                    Path = $testOutputPath
                }
            } | Should -Throw -ExpectedMessage ($mockLocalizedNotFoundError -f $testUri, 'The remote server returned an error: (404) Not Found.')
        }

        It 'Should return false and write an unauthorized error when download fails with 401' {
            # Arrange
            $testUri = 'https://example.com/file.zip'
            $testOutputPath = Join-Path -Path 'TestDrive:' -ChildPath 'Downloads' | Join-Path -ChildPath 'file.zip'

            Mock -CommandName Test-Path -MockWith { $false }

            $mockLocalizedUnauthorizedError = InModuleScope -ScriptBlock { $script:localizedData.Invoke_UrlDownload_UnauthorizedError }

            # Mock Invoke-WebRequest to throw a 401 WebException
            Mock -CommandName Invoke-WebRequest -MockWith {
                $response = [PSCustomObject]@{
                    StatusCode = [PSCustomObject]@{ value__ = 401 }
                }

                # Add the type name manually
                $response.PSObject.TypeNames.Insert(0, 'System.Net.HttpWebResponse')

                $webException = [System.Net.WebException]::new('The remote server returned an error: (401) Unauthorized.')
                $webException | Add-Member -MemberType NoteProperty -Name 'Response' -Value $response -Force

                throw $webException
            }

            # Act
            {
                InModuleScope -ScriptBlock {
                    param($Uri, $Path)
                    Invoke-UrlDownload -Uri $Uri -OutputPath $Path -ErrorAction 'Stop'
                } -Parameters @{
                    Uri = $testUri
                    Path = $testOutputPath
                }
            } | Should -Throw -ExpectedMessage ($mockLocalizedUnauthorizedError -f $testUri, 'The remote server returned an error: (401) Unauthorized.')
        }
    }

    Context 'When a download fails with permission errors' {
        BeforeAll {
            $mockLocalizedPermissionError = InModuleScope -ScriptBlock { $script:localizedData.Invoke_UrlDownload_PermissionError }
        }

        It 'Should return false and write a permission error when download fails with UnauthorizedAccessException' {
            # Arrange
            $testUri = 'https://example.com/file.zip'
            $testOutputPath = Join-Path -Path 'TestDrive:' -ChildPath 'Downloads' | Join-Path -ChildPath 'file.zip'

            Mock -CommandName Test-Path -MockWith { $false }

            # Mock Invoke-WebRequest to throw an UnauthorizedAccessException
            Mock -CommandName Invoke-WebRequest -MockWith {
                throw [System.UnauthorizedAccessException]::new('Access to the path is denied.')
            }

            # Act
            {
                InModuleScope -ScriptBlock {
                    param($Uri, $Path)
                    Invoke-UrlDownload -Uri $Uri -OutputPath $Path -ErrorAction 'Stop'
                } -Parameters @{
                    Uri = $testUri
                    Path = $testOutputPath
                }
            } | Should -Throw -ExpectedMessage ($mockLocalizedPermissionError -f $testOutputPath, 'Access to the path is denied.')
        }
    }

    Context 'When a download fails with unknown errors' {
        BeforeAll {
            $mockLocalizedUnknownError = InModuleScope -ScriptBlock { $script:localizedData.Invoke_UrlDownload_UnknownError }
        }

        It 'Should return false and write an unknown error when download fails with generic exception' {
            # Arrange
            $testUri = 'https://example.com/file.zip'
            $testOutputPath = Join-Path -Path 'TestDrive:' -ChildPath 'Downloads' | Join-Path -ChildPath 'file.zip'

            Mock -CommandName Test-Path -MockWith { $false }

            # Mock Invoke-WebRequest to throw a generic exception
            Mock -CommandName Invoke-WebRequest -MockWith {
                throw 'An unexpected error occurred'
            }

            # Act
            {
                InModuleScope -ScriptBlock {
                    param($Uri, $Path)
                    Invoke-UrlDownload -Uri $Uri -OutputPath $Path -ErrorAction 'Stop'
                } -Parameters @{
                    Uri = $testUri
                    Path = $testOutputPath
                }
            } | Should -Throw -ExpectedMessage ($mockLocalizedUnknownError -f $testUri, 'An unexpected error occurred')
        }
    }
}
