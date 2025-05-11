<#
    .SYNOPSIS
        Gets metadata for a specific asset from a GitHub repository release.

    .DESCRIPTION
        This command retrieves metadata information about assets from releases of
        a GitHub repository.

        You can use the Latest parameter to specifically target the latest release,
        and the IncludePrerelease parameter to include prerelease versions when
        determining the latest release. The IncludeDraft parameter allows including
        draft releases in the results.

        The command returns metadata including the asset name, size, download URL,
        release version, and other relevant information for matching assets.

    .PARAMETER OwnerName
        The name of the repository owner.

    .PARAMETER RepositoryName
        The name of the repository.

    .PARAMETER Latest
        If specified, only returns assets from the latest release based on semantic
        versioning.

    .PARAMETER IncludePrerelease
        If specified, prerelease versions will be included in the release results.

    .PARAMETER IncludeDraft
        If specified, draft releases will be included in the release results.

    .PARAMETER AssetName
        The name of the asset to retrieve metadata for.
        You can use wildcards to match the asset name.
        If not specified, all assets from the matching release will be returned.

    .PARAMETER Token
        The GitHub personal access token to use for authentication.
        If not specified, the command will use anonymous access which has rate limits.

    .EXAMPLE
        Get-GitHubReleaseAssetMetadata -OwnerName 'PowerShell' -RepositoryName 'PowerShell' -AssetName 'PowerShell-*-win-x64.msi'

        This example retrieves metadata for the Windows x64 MSI installer asset from the latest
        full release of the PowerShell/PowerShell repository.

    .EXAMPLE
        Get-GitHubReleaseAssetMetadata -OwnerName 'PowerShell' -RepositoryName 'PowerShell' -AssetName 'PowerShell-*-win-x64.msi' -IncludePrerelease

        This example retrieves metadata for the Windows x64 MSI installer asset from the latest
        release (including prereleases) of the PowerShell/PowerShell repository.

    .EXAMPLE
        Get-GitHubReleaseAssetMetadata -OwnerName 'Microsoft' -RepositoryName 'WSL' -AssetName '*.x64' -Token 'ghp_1234567890abcdef'

        This example retrieves metadata for the AppX bundle asset from the latest release of the
        Microsoft/WSL repository using a GitHub personal access token for authentication.

    .EXAMPLE
        Get-GitHubReleaseAssetMetadata -OwnerName 'PowerShell' -RepositoryName 'PowerShell' -IncludePrerelease -IncludeDraft

        This example retrieves metadata for all assets from all releases, including prereleases and drafts,
        of the PowerShell/PowerShell repository.

    .NOTES
        This command requires internet connectivity to access the GitHub API.
        GitHub API rate limits may apply for unauthenticated requests.
#>
function Get-GitHubReleaseAssetMetadata
{
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $OwnerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $RepositoryName,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $Latest,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $IncludePrerelease,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $IncludeDraft,

        [Parameter()]
        [System.String]
        $AssetName,

        [Parameter()]
        [System.Security.SecureString]
        $Token
    )

    $getGitHubReleaseParameters = @{} + $PSBoundParameters
    $getGitHubReleaseParameters.Remove('AssetName')

    $release = Get-GitHubRelease @getGitHubReleaseParameters

    if (-not $release)
    {
        return $null
    }

    Write-Verbose -Message ($script:localizedData.Get_GitHubReleaseAssetMetadata_FoundRelease -f ($release.name -join ', '))

    if ($AssetName)
    {
        # Find the requested asset using wildcard matching
        $matchingAssets = $release.assets |
            Where-Object -FilterScript {
                $_.name -like $AssetName
            }

        if (-not $matchingAssets -or $matchingAssets.Count -eq 0)
        {
            $writeErrorParameters = @{
                Message      = $script:localizedData.Get_GitHubReleaseAssetMetadata_MissingAssetName -f $_.Exception.Message
                Category     = 'ObjectNotFound'
                ErrorId      = 'GGHRAM0001' # cSpell: disable-line
                TargetObject = $AssetName
            }

            Write-Error @writeErrorParameters

            return $null
        }
    }
    else
    {
        $matchingAssets = $release.assets
    }

    Write-Verbose -Message (
        $script:localizedData.Get_GitHubReleaseAssetMetadata_FoundAsset -f ($matchingAssets.name -join ', ')
    )

    return $matchingAssets
}
