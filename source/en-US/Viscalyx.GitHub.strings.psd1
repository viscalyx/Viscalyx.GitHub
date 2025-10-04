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
    Save_GitHubReleaseAsset_CreatingDirectory = Creating download directory '{0}'. (SGRA0001)
    Save_GitHubReleaseAsset_AssetFiltered = Asset '{0}' does not match the filter '{1}', skipping. (SGRA0002)
    Save_GitHubReleaseAsset_NoAssetsToDownload = No assets were found to download. (SGRA0003)
    Save_GitHubReleaseAsset_DownloadingAssets = Downloading {0} GitHub release assets. (SGRA0004)
    Save_GitHubReleaseAsset_DownloadingAsset = Downloading asset '{0}' to '{1}'. (SGRA0005)
    Save_GitHubReleaseAsset_DownloadFailed = Failed to download asset '{0}'. (SGRA0006)
    Save_GitHubReleaseAsset_DownloadsCompleted = All downloads completed. (SGRA0007)
    Save_GitHubReleaseAsset_UsingDirectUri = Using direct URI '{0}' for asset '{1}'. (SGRA0008)
    Save_GitHubReleaseAsset_RetryingDownload = Download failed for asset '{0}'. Retrying attempt {1}/{2} after waiting {3} seconds. (SGRA0009)
    Save_GitHubReleaseAsset_VerifyingHash = Verifying file hash for asset '{0}'. (SGRA0010)
    Save_GitHubReleaseAsset_HashMismatch = File hash mismatch for asset '{0}'. Expected: {1}, Actual: {2}. The downloaded file has been deleted. (SGRA0011)
    Save_GitHubReleaseAsset_HashVerified = File hash verified successfully for asset '{0}'. (SGRA0012)

    ## Invoke-UrlDownload
    Invoke_UrlDownload_DownloadingFile = Downloading file from {0} to {1}.
    Invoke_UrlDownload_DownloadCompleted = Download completed successfully to {0}.
    Invoke_UrlDownload_DownloadFailed = Failed to download file from {0}: {1}
    Invoke_UrlDownload_FileExists = File already exists at '{0}'. Use -Force to overwrite.
    Invoke_UrlDownload_SkippingDownload = Skipping download as file already exists at '{0}'.
    Invoke_UrlDownload_NetworkError = Network error occurred while downloading from {0}: {1}
    Invoke_UrlDownload_PermissionError = Permission denied when writing to '{0}': {1}
    Invoke_UrlDownload_UnauthorizedError = Unauthorized access to {0}. Check authentication credentials: {1}
    Invoke_UrlDownload_NotFoundError = The requested resource was not found at {0}: {1}
    Invoke_UrlDownload_UnknownError = An unexpected error occurred during download from {0}: {1}
'@
