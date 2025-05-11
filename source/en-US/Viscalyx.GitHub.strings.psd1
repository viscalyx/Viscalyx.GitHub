<#
    .SYNOPSIS
        The localized resource strings in English (en-US). This file should only
        contain localized strings for private functions, public command, and
        classes (that are not a DSC resource).
#>

ConvertFrom-StringData @'
    # Get-GitHubReleaseAsset command strings
    Get_GitHubReleaseAsset_MissingAssetName = The specified asset name was not found in the repository releases.
    Get_GitHubReleaseAsset_FoundRelease = Found release {0}.
    Get_GitHubReleaseAsset_FoundAsset = Found asset(s) {0}.

    # Get-GitHubRelease function strings
    Get_GitHubRelease_ProcessingRepository = Processing repository {0}/{1}.
    Get_GitHubRelease_NoReleasesFound = No releases were found in repository {0}/{1}.
    Get_GitHubRelease_FilteringPrerelease = Filtering out prerelease versions.
    Get_GitHubRelease_FilteringDraft = Filtering out draft versions.
    Get_GitHubRelease_Error_ApiRequest = Failed to retrieve GitHub API data: {0}

    # Convert-SecureStringAsPlainText function strings
    Convert_SecureStringAsPlainText_Converting = 'Converting SecureString to plain text.'
'@
