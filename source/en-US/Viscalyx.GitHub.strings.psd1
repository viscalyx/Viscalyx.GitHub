<#
    .SYNOPSIS
        The localized resource strings in English (en-US). This file should only
        contain localized strings for private functions, public command, and
        classes (that are not a DSC resource).
#>

ConvertFrom-StringData @'
    ## Get-GitHubReleaseAsset
    Get_GitHubReleaseAsset_MissingAssetName = The specified asset name was not found in the repository releases.
    Get_GitHubReleaseAsset_FoundRelease = Found release {0}.
    Get_GitHubReleaseAsset_FoundAsset = Found asset(s) {0}.

    ## Get-GitHubRelease
    Get_GitHubRelease_ProcessingRepository = Processing repository {0}/{1}.
    Get_GitHubRelease_NoReleasesFound = No releases were found in repository {0}/{1}.
    Get_GitHubRelease_FilteringPrerelease = Filtering out prerelease versions.
    Get_GitHubRelease_FilteringDraft = Filtering out draft versions.
    Get_GitHubRelease_Error_ApiRequest = Failed to retrieve GitHub API data: {0}

    ## Convert-SecureStringAsPlainText
    Convert_SecureStringAsPlainText_Converting = 'Converting SecureString to plain text.'

    ## Save-GitHubReleaseAsset
    Save_GitHubReleaseAsset_CreatingDirectory = Creating download directory '{0}'.
    Save_GitHubReleaseAsset_AssetFiltered = Asset '{0}' does not match the filter '{1}', skipping.
    Save_GitHubReleaseAsset_NoAssetsToDownload = No assets were found to download.
    Save_GitHubReleaseAsset_DownloadingAssets = Downloading {0} GitHub release assets.
    Save_GitHubReleaseAsset_DownloadingAsset = Downloading asset '{0}' to '{1}'.
    Save_GitHubReleaseAsset_DownloadFailed = Failed to download asset '{0}'.
    Save_GitHubReleaseAsset_DownloadsCompleted = All downloads completed.
    Save_GitHubReleaseAsset_UsingDirectUri = Using direct URI '{0}' for asset '{1}'.

    ## Invoke-UrlDownload
    Invoke_UrlDownload_DownloadingFile = Downloading file from {0} to {1}.
    Invoke_UrlDownload_DownloadCompleted = Download completed successfully to {0}.
    Invoke_UrlDownload_DownloadFailed = Failed to download file from {0}: {1}
'@
