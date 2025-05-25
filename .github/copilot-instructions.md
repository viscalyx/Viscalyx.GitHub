# Specific instructions for the PowerShell module project Viscalyx.GitHub

Assume that the word "command" references to a public command, and the word
"function" references to a private function.

## Public commands

PowerShell commands that should be public should always have its separate
script file and the command name as the file name with the .ps1 extension,
these files shall always be placed in the folder source/Public.

Public commands may use private functions to move out logic that can be
reused by other public commands, so move out any logic that can be deemed
reusable.

## Private functions

Private functions (also known as helper functions) should always have its
separate script file and the function name as the file name with the .ps1
extension. These files shall always be placed in the folder source/Private.
This also applies to functions that are only used within a single public
command.

## Comment-based help

Comment-based help should always be before the function-statement for each
public command and private function. Comment-based help should always be in the
format of a comment block and at least use the keywords: .SYNOPSIS, .DESCRIPTION,
.PARAMETER, .EXAMPLE, and .NOTES.

Each comment-based help keyword should be indented with 4 spaces and each
keyword's text should be indented 8 spaces.

The text for keyword .DESCRIPTION should be descriptive and must have a
length greater than 40 characters. The .SYNOPSIS keyword text should be
a short description of the public command or private function.

A comment-based help must have at least one example, but preferably more
examples to showcase all possible parameter sets and different parameter
combinations.

## Localization

All message strings for Write-Debug, Write-Verbose, Write-Error, Write-Warning
and other error messages in public commands and private functions should be
localized using localized string keys.

For public commands and private functions you should always add all localized
strings for in the source/en-US/Viscalyx.GitHub.strings.psd1 file, re-use the
same pattern for new string keys. Localized string key names should always
be prefixed with the function name but use underscore as word separator.
Always assume that all localized string keys have already been assigned to
the variable $script:localizedData.

## Tests

All tests should use the Pester framework and use Pester v5.0 syntax.
Parameter validation should never be tested.

Test code should never be added outside of the `Describe` block.

There should only be one Pester `Describe` block per test file, and the name of
the `Describe` block should be the same as the name of the public command or
private function being tested. Each scenario or code path being tested should have
its own Pester `Context` block that starts with the phrase 'When'. Use nested
`Context` blocks to split up test cases and improve tests readability. Pester `It`
block descriptions should start with the phrase 'Should'. `It` blocks must always
call the command or function being tested and result and outcomes should be kept
in the same `It` block. `BeforeAll` and `BeforeEach` blocks should never call the
command or function being tested.

The `BeforeAll`, `BeforeEach`, `AfterAll` and `AfterEach` blocks should be
used inside the `Context` block as near as possible to the `It` block that
will use the test data, test setup and teardown. The `AfterAll` block can
be used to clean up any test data. The `BeforeEach` and `AfterEach`
blocks should be used sparingly. It is okay to duplicated code in `BeforeAll`
and `BeforeEach` blocks that are used inside different `Context` blocks.
The duplication helps with readability and understanding of the test cases,
and to be able to keep the test setup and teardown as close to the test
case (`It`-block) as possible.

### Unit tests

Never test, mock or use `Should -Invoke` for `Write-Verbose` and `Write-Debug`
regardless of other instructions.

Unit tests should be added for all public commands and private functions. The unit
tests for public command should be placed in the folder tests/Unit/Public and the
unit tests for private functions should be placed in the folder tests/Unit/Private.
The unit tests should be named after the public command or private function
they are testing, but should have the suffix .Tests.ps1. The unit tests
should be written to cover all possible scenarios and code paths, ensuring
that both edge cases and common use cases are tested.

The `BeforeAll` block should be used to set up any necessary test data or mocking

Use localized strings in the tests only when necessary. You can assign the
localized string to a mock variable by and get the localized string key
from the $script:localizedData variable inside a `InModuleScope` block.
An example to get a localized string key from the $script:localizedData variable:

```powershell
$mockLocalizedStringText = InModuleScope -ScriptBlock { $script:localizedData.LocalizedStringKey }
```

Files that need to be mocked should be created in Pesters test drive. The
variable `$TestDrive` holds the path to the test drive. The `$TestDrive` is a
temporary drive that is created for each test run and is automatically
cleaned up after the test run is complete.

All unit tests should should use this code block prior to the `Describe` block
which will set up the test environment and load the correct module being tested:

```powershell
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
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

    $PSDefaultParameterValues['InModuleScope:ModuleName'] = $script:dscModuleName
    $PSDefaultParameterValues['Mock:ModuleName'] = $script:dscModuleName
    $PSDefaultParameterValues['Should:ModuleName'] = $script:dscModuleName
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    $PSDefaultParameterValues.Remove('Mock:ModuleName')
    $PSDefaultParameterValues.Remove('Should:ModuleName')

    # Unload the module being tested so that it doesn't impact any other tests.
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}
```

### Integration tests

Integration tests should be added for all public commands. Integration must
never mock any command but run the command in a real environment. All integration
tests should be placed in the root of the folder "tests/Integration/Commands"
and the integration tests should be named after the public command they are testing,
but should have the suffix .Integration.Tests.ps1. The integration tests should
be written to cover all possible scenarios and code paths, ensuring that both
edge cases and common use cases are tested. The integration tests should
also be written to test the command in a real environment, using real
resources and dependencies.

All integration tests must use the below code block prior to the first
`Describe`-block. The following code will set up the integration test
environment and it will make sure the module being tested is available

```powershell
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
```

The module DscResource.Test is used by the pipeline and its commands
are normally not used when testing public functions or private functions.

## Style guidelines

This project use the style guidelines from the DSC Community: https://dsccommunity.org/styleguidelines

### Markdown files

- Line length should be wrapped after a word when a line exceeds 80 characters
  in length.
- Use 2 spaces for indentation in Markdown files.

### PowerShell files

- All files should use UTF8 without BOM.

### PowerShell code

- Try to limit lines to 120 characters
- Use 4 spaces for indentation, never use tabs.
- Use '#' for single line comments
- Use comment-blocks for multiline comments with the format `<# ... #>`
  where the multiline text is indented 4 spaces.
- Use descriptive, clear, and full names for all variables, parameters, and
  function names. All names must be more than 2 characters. No abbreviations
  should be used.
- Use camelCase for local variable names.
- Use PascalCase for function names and parameters in public commands and private
  functions.
- All public command and private function names must follow the standard
  PowerShell Verb-Noun format.
- All public command and private function names must use PowerShell approved
  verbs.
- All public commands and private functions should always be advanced functions
  and have `[CmdLetBinding()]` attribute.
- Public commands and private functions with no parameters should still have
  an empty parameter block `param ()`.
- Every parameter in public commands and private functions should include the
  `[Parameter()]` attribute.
- A mandatory parameter in public commands and private functions should
  contain the decoration `[Parameter(Mandatory = $true)]`, and non-mandatory
  parameters should not contain the Mandatory decoration.
- Parameters attributes, datatype and its name should be on separate lines.
- Parameters must be separated by a single, blank line.
- Use `Write-Verbose` to output verbose output for actions an public command
  or private function does.
- Use `Write-Debug` for debug output for processes within the script for
  user to see the decisions a command och private function does.
- Use `Write-Error` for error messages.
- Use `Write-Warning` for warning messages.
- Use `Write-Information` for informational messages.
- Never use `Write-Host`.
- Never use backtick as line continuation in code.
- Use splatting for commands to reduce line length.
- PowerShell reserved Keywords should be in all lower case.
- Single quotes should always be used to delimit string literals wherever
  possible. Double quoted string literals may only be used when string
  literals contain ($) expressions that need to be evaluated.
- A hashtable's properties should always be in PascalCase and be on a separate
  line.
- When comparing a value to `$null`, `$null` should be on the left side of
  the comparison.
- When using .NET types, use the full type name, e.g. `[System.String]` or
  `[System.Collections.Generic.List[System.String]]`.


## Project scripts

The build script is located in the root of the repository and is named
`build.ps1`.

### Build

- To run the build script after code changes in ./source, run `.\build.ps1 -Tasks build`.

## Test project
- To run tests, always run `.\build.ps1 -Tasks noop` prior to running `Invoke-Pester`.
