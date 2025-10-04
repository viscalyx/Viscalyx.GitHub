# Project Instructions

## Requirements
- Always follow the instructions in this repository.

## Build & Test Workflow Requirements
- Never use VS Code tasks, always use PowerShell scripts via terminal, from repository root
- Run PowerShell script files from repository root
- Setup build and test environment (once per `pwsh` session): `./build.ps1 -Tasks noop`
- Build project before running tests: `./build.ps1 -Tasks build`
- Run tests without coverage (wildcards allowed): `Invoke-PesterJob -Path '{tests filepath}' -SkipCodeCoverage`
  - Run a specific test name, add parameter: `-TestNameFilter '*{test name}*'`
- Run tests with coverage (wildcards allowed): `Invoke-PesterJob -Output minimal -Path '{tests filepath}' -EnableSourceLineMapping -FilterCodeCoverageResult '{name pattern}'`
- Run QA tests: `Invoke-PesterJob -Path 'tests/QA' -SkipCodeCoverage`
- Never run integration tests locally
