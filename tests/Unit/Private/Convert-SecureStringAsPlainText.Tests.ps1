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

Describe 'Convert-SecureStringAsPlainText' {
    Context 'When converting a secure string to plain text' {
        BeforeAll {
            # Get the localized string for the verbose message
            $mockLocalizedConvertingMessage = InModuleScope -ScriptBlock {
                $script:localizedData.Convert_SecureStringAsPlainText_Converting
            }

            # Create a test secure string
            $testPlainText = 'P@ssw0rd'
            $testSecureString = ConvertTo-SecureString -String $testPlainText -AsPlainText -Force
        }

        It 'Should convert the secure string correctly' {
            InModuleScope -ScriptBlock {
                $result = Convert-SecureStringAsPlainText -SecureString $SecureString
                $result | Should -Be $ExpectedPlainText
            } -Parameters @{
                SecureString      = $testSecureString
                ExpectedPlainText = $testPlainText
            }
        }

        It 'Should handle empty secure string' {
            InModuleScope -ScriptBlock {
                $emptySecureString = New-Object -TypeName System.Security.SecureString
                $result = Convert-SecureStringAsPlainText -SecureString $emptySecureString
                $result | Should -Be ''
            }
        }
    }
}
