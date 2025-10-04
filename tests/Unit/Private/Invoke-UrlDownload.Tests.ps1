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
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    $PSDefaultParameterValues.Remove('Mock:ModuleName')
    $PSDefaultParameterValues.Remove('Should:ModuleName')

    # Unload the module being tested so that it doesn't impact any other tests.
    Get-Module -Name $script:moduleName -All | Remove-Module -Force
}

Describe 'Invoke-UrlDownload' {
    Context 'When downloading a file successfully' {
        BeforeAll {
            # Mock Invoke-WebRequest to simulate successful download
            Mock -CommandName Invoke-WebRequest -MockWith { }
        }

        It 'Should return true when the download completes successfully' {
            # Arrange
            $testUri = 'https://example.com/file.zip'
            $testOutputPath = 'C:\Downloads\file.zip'

            # Act
            $result = InModuleScope -ScriptBlock {
                Invoke-UrlDownload -Uri 'https://example.com/file.zip' -OutputPath 'C:\Downloads\file.zip'
            }

            # Assert
            $result | Should -BeTrue

            Should -Invoke -CommandName Invoke-WebRequest -ParameterFilter {
                $Uri -eq $testUri -and
                $OutFile -eq $testOutputPath -and
                $UserAgent -eq 'Viscalyx.GitHub' -and
                $UseBasicParsing -eq $true
            } -Exactly -Times 1 -Scope It
        }

        It 'Should use the provided user agent' {
            # Arrange
            $testUri = 'https://example.com/file.zip'
            $testOutputPath = 'C:\Downloads\file.zip'
            $testUserAgent = 'CustomAgent'

            # Act
            $result = InModuleScope -ScriptBlock {
                Invoke-UrlDownload -Uri 'https://example.com/file.zip' -OutputPath 'C:\Downloads\file.zip' -UserAgent 'CustomAgent'
            }

            # Assert
            $result | Should -BeTrue

            Should -Invoke -CommandName Invoke-WebRequest -ParameterFilter {
                $Uri -eq $testUri -and
                $OutFile -eq $testOutputPath -and
                $UserAgent -eq $testUserAgent -and
                $UseBasicParsing -eq $true
            } -Exactly -Times 1 -Scope It
        }
    }

    Context 'When a download fails' {
        BeforeAll {
            # Mock Invoke-WebRequest to throw an exception
            Mock -CommandName Invoke-WebRequest -MockWith {
                throw 'Download failed with status code 404'
            }

            $mockLocalizedDownloadFailed = InModuleScope -ScriptBlock { $script:localizedData.Invoke_UrlDownload_DownloadFailed }
        }

        It 'Should return false and write an error when the download fails' {
            # Arrange
            $testUri = 'https://example.com/file.zip'
            $testOutputPath = 'C:\Downloads\file.zip'

            # Act
            {
                InModuleScope -ScriptBlock {
                    Invoke-UrlDownload -Uri 'https://example.com/file.zip' -OutputPath 'C:\Downloads\file.zip' -ErrorAction 'Stop'
                }
            } | Should -Throw -ExpectedMessage ($mockLocalizedDownloadFailed -f 'https://example.com/file.zip', 'Download failed with status code 404')
        }
    }
}
