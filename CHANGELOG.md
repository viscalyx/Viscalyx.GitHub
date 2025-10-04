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
- New command `Save-GitHubReleaseAsset` to download GitHub release assets to
  a local path with support for multiple download methods, asset name filtering,
  file integrity validation using SHA256 hashes, and progress indication during
  downloads.
- Private function `Convert-SecureStringAsPlainText` to safely handle secure
  string conversions for GitHub authentication tokens.
- Private function `Invoke-UrlDownload` to handle file downloads with proper
  error handling, user agent configuration, and verbose logging.
- Added pipeline input support to `Get-GitHubReleaseAsset` allowing release
  objects from `Get-GitHubRelease` to be piped directly into the command.
- Added additional example to `Get-GitHubReleaseAsset` documentation showing
  how to use the pipeline functionality for efficient workflow.
- Added integration tests for the new pipeline functionality.
- Added comprehensive unit tests for `Save-GitHubReleaseAsset` command covering
  various download scenarios, error handling, and edge cases.
- Added unit tests for `Invoke-UrlDownload` private function to ensure reliable
  file download functionality.
- Added integration tests for `Save-GitHubReleaseAsset` to verify real-world
  download capabilities with public GitHub repositories.
- Added localized string resources for `Save-GitHubReleaseAsset` and
  `Invoke-UrlDownload` functions to support proper error messaging and user feedback.
- Added project documentation improvements including build instructions and
  test execution guidelines for development workflow.

### Changed

- Refactored `Get-GitHubReleaseAsset` to use parameter sets for better
  distinction between direct repository queries and pipeline input scenarios.
- Enhanced `Get-GitHubReleaseAsset` with begin/process/end blocks for proper
  pipeline handling of multiple release objects.
- Bump action Stale to v10.
- Bump action Checkout to v5.
- Enhanced `Invoke-UrlDownload` private function with:
  - Added `-Force` parameter to allow overwriting existing files.
  - Added file existence check that skips download if file already exists
    (unless `-Force` is specified).
  - Enhanced error handling to differentiate between network errors (404, 401,
    general network issues), permission errors, and unknown errors with
    specific localized error messages for better troubleshooting.
- Enhanced `Save-GitHubReleaseAsset` command with:
  - Added `-Force` parameter that is passed through to `Invoke-UrlDownload` to
    allow overwriting existing downloaded files.

### Fixed

- Fixed README badges.
- Fixed error message formatting in `Get-GitHubReleaseAsset` for asset name
  validation errors.
