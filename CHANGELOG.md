# Changelog for Viscalyx.GitHub

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial release of the Viscalyx.GitHub PowerShell module
- New command `Get-GitHubRelease` to retrieve releases from a GitHub repository
  with options to filter by latest, prerelease, and draft statuses
- New command `Get-GitHubReleaseAsset` to retrieve metadata information
  about assets from GitHub repository releases
- Private function `Convert-SecureStringAsPlainText` to safely handle secure
  string conversions for GitHub authentication tokens

### Fixed

- Fixed README badges.
