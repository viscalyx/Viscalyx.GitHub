# Changelog for Viscalyx.GitHub

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial release of the Viscalyx.GitHub PowerShell module.
- New command `Get-GitHubRelease` to retrieve releases from a GitHub repository
  with options to filter by latest, prerelease, and draft statuses.
- New command `Get-GitHubReleaseAsset` to retrieve metadata information
  about assets from GitHub repository releases.
- Private function `Convert-SecureStringAsPlainText` to safely handle secure
  string conversions for GitHub authentication tokens.
- Added pipeline input support to `Get-GitHubReleaseAsset` allowing release
  objects from `Get-GitHubRelease` to be piped directly into the command.
- Added additional example to `Get-GitHubReleaseAsset` documentation showing
  how to use the pipeline functionality for efficient workflow.
- Added integration tests for the new pipeline functionality.

### Changed

- Refactored `Get-GitHubReleaseAsset` to use parameter sets for better
  distinction between direct repository queries and pipeline input scenarios.
- Enhanced `Get-GitHubReleaseAsset` with begin/process/end blocks for proper
  pipeline handling of multiple release objects.
- Bump action Stale to v10.

### Fixed

- Fixed README badges.
- Fixed error message formatting in `Get-GitHubReleaseAsset` for asset name
  validation errors.
