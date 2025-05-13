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

        This command can either fetch releases directly from GitHub or accept
        pre-fetched release objects through the InputObject parameter.

    .PARAMETER InputObject
        One or more release objects from GitHub. These objects should be the output
        from Get-GitHubRelease. This parameter enables piping releases directly into
        this command.

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
        Get-GitHubReleaseAsset -OwnerName 'PowerShell' -RepositoryName 'PowerShell' -AssetName 'PowerShell-*-win-x64.msi'

        This example retrieves metadata for the Windows x64 MSI installer asset from the latest
        full release of the PowerShell/PowerShell repository.

    .EXAMPLE
        Get-GitHubReleaseAsset -OwnerName 'PowerShell' -RepositoryName 'PowerShell' -AssetName 'PowerShell-*-win-x64.msi' -IncludePrerelease

        This example retrieves metadata for the Windows x64 MSI installer asset from the latest
        release (including prereleases) of the PowerShell/PowerShell repository.

    .EXAMPLE
        Get-GitHubReleaseAsset -OwnerName 'Microsoft' -RepositoryName 'WSL' -AssetName '*.x64' -Token 'ghp_1234567890abcdef'

        This example retrieves metadata for the AppX bundle asset from the latest release of the
        Microsoft/WSL repository using a GitHub personal access token for authentication.

    .EXAMPLE
        Get-GitHubReleaseAsset -OwnerName 'PowerShell' -RepositoryName 'PowerShell' -IncludePrerelease -IncludeDraft

        This example retrieves metadata for all assets from all releases, including prereleases and drafts,
        of the PowerShell/PowerShell repository.

    .EXAMPLE
        Get-GitHubRelease -OwnerName 'PowerShell' -RepositoryName 'PowerShell' | Get-GitHubReleaseAsset -AssetName 'PowerShell-*-win-x64.msi'

        This example pipes releases from Get-GitHubRelease and retrieves metadata for the Windows x64 MSI installer assets.

    .NOTES
        This command requires internet connectivity to access the GitHub API when using the ByRepository parameter set.
        GitHub API rate limits may apply for unauthenticated requests.
#>
function Get-GitHubReleaseAsset
{
    [CmdletBinding(DefaultParameterSetName = 'ByRepository')]
    [OutputType([PSCustomObject])]
    param
    (
        [Parameter(Mandatory = $true, ParameterSetName = 'ByInputObject', ValueFromPipeline = $true)]
        [PSCustomObject[]]
        $InputObject,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByRepository')]
        [System.String]
        $OwnerName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByRepository')]
        [System.String]
        $RepositoryName,

        [Parameter(ParameterSetName = 'ByRepository')]
        [System.Management.Automation.SwitchParameter]
        $Latest,

        [Parameter(ParameterSetName = 'ByRepository')]
        [System.Management.Automation.SwitchParameter]
        $IncludePrerelease,

        [Parameter(ParameterSetName = 'ByRepository')]
        [System.Management.Automation.SwitchParameter]
        $IncludeDraft,

        [Parameter(ParameterSetName = 'ByRepository')]
        [System.Security.SecureString]
        $Token,

        [Parameter()]
        [System.String]
        $AssetName
    )

    begin
    {
        $releases = @()
    }

    process
    {
        if ($PSCmdlet.ParameterSetName -eq 'ByRepository')
        {
            $getGitHubReleaseParameters = @{} + $PSBoundParameters
            $getGitHubReleaseParameters.Remove('AssetName')

            $releaseFromRepo = Get-GitHubRelease @getGitHubReleaseParameters

            if (-not $releaseFromRepo)
            {
                return
            }

            $releases += $releaseFromRepo
        }
        else
        {
            $releases += $InputObject
        }
    }

    end
    {
        Write-Verbose -Message ($script:localizedData.Get_GitHubReleaseAsset_FoundRelease -f ($releases.name -join ', '))

        foreach ($release in $releases)
        {
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
                        Message      = $script:localizedData.Get_GitHubReleaseAsset_MissingAssetName
                        Category     = 'ObjectNotFound'
                        ErrorId      = 'GGHRAM0001' # cSpell: disable-line
                        TargetObject = $AssetName
                    }

                    Write-Error @writeErrorParameters

                    continue
                }
            }
            else
            {
                $matchingAssets = $release.assets
            }

            Write-Verbose -Message (
                $script:localizedData.Get_GitHubReleaseAsset_FoundAsset -f ($matchingAssets.name -join ', ')
            )

            $matchingAssets
        }
    }
}
