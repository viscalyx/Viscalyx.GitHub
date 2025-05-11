<#
    .SYNOPSIS
        Gets releases from a GitHub repository.

    .DESCRIPTION
        Gets releases from a GitHub repository. By default, it returns all non-prerelease
        and non-draft releases. Use the Latest parameter to return only the most
        recent release. Use the IncludePrerelease parameter to include prerelease
        versions, and the IncludeDraft parameter to include draft releases in the
        results.

    .PARAMETER OwnerName
        The name of the repository owner.

    .PARAMETER RepositoryName
        The name of the repository.

    .PARAMETER Latest
        If specified, only returns the most recent release that matches other filter
        criteria.

    .PARAMETER IncludePrerelease
        If specified, prerelease versions will be included in the results.

    .PARAMETER IncludeDraft
        If specified, draft releases will be included in the results.

    .PARAMETER Token
        The GitHub personal access token to use for authentication. If not specified,
        the function will use anonymous access which has rate limits.

    .EXAMPLE
        Get-GitHubRelease -OwnerName 'PowerShell' -RepositoryName 'PowerShell'

        Gets all non-prerelease, non-draft releases from the PowerShell/PowerShell repository.

    .EXAMPLE
        Get-GitHubRelease -OwnerName 'PowerShell' -RepositoryName 'PowerShell' -Latest

        Gets the latest non-prerelease, non-draft release from the PowerShell/PowerShell repository.

    .EXAMPLE
        Get-GitHubRelease -OwnerName 'PowerShell' -RepositoryName 'PowerShell' -IncludePrerelease

        Gets all releases including prereleases (but excluding drafts) from the PowerShell/PowerShell repository.

    .EXAMPLE
        Get-GitHubRelease -OwnerName 'PowerShell' -RepositoryName 'PowerShell' -IncludePrerelease -IncludeDraft

        Gets all releases including prereleases and drafts from the PowerShell/PowerShell repository.

    .NOTES
        For more information about GitHub releases, see the GitHub REST API documentation:
        https://docs.github.com/en/rest/releases/releases
#>
function Get-GitHubRelease
{
    [CmdletBinding()]
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
        [System.Security.SecureString]
        $Token
    )

    Write-Verbose -Message ($script:localizedData.Get_GitHubRelease_ProcessingRepository -f $OwnerName, $RepositoryName)

    $apiBaseUrl = 'https://api.github.com/repos/{0}/{1}/releases' -f $OwnerName, $RepositoryName

    $headers = @{
        Accept = 'application/vnd.github.v3+json'
    }

    if ($Token)
    {
        # Convert SecureString to plain text for the authorization header
        $plainTextToken = Convert-SecureStringAsPlainText -SecureString $Token

        $headers.Authorization = "Bearer $plainTextToken"
    }

    try
    {
        $releases = Invoke-RestMethod -Uri $apiBaseUrl -Headers $headers -Method 'Get' -ErrorAction 'Stop'
    }
    catch
    {
        $writeErrorParameters = @{
            Message      = $script:localizedData.Get_GitHubRelease_Error_ApiRequest -f $_.Exception.Message
            Category     = 'ObjectNotFound'
            ErrorId      = 'GGHR0001' # cSpell: disable-line
            TargetObject = '{0}/{1}' -f $OwnerName, $RepositoryName
        }

        Write-Error @writeErrorParameters

        return $null
    }

    if (-not $releases -or $releases.Count -eq 0)
    {
        Write-Verbose -Message ($script:localizedData.Get_GitHubRelease_NoReleasesFound -f $OwnerName, $RepositoryName)

        return $null
    }

    if (-not $IncludePrerelease)
    {
        Write-Verbose -Message $script:localizedData.Get_GitHubRelease_FilteringPrerelease

        $releases = $releases |
            Where-Object -FilterScript { -not $_.prerelease }
    }

    if (-not $IncludeDraft)
    {
        Write-Verbose -Message $script:localizedData.Get_GitHubRelease_FilteringDraft

        $releases = $releases |
            Where-Object -FilterScript { -not $_.draft }
    }

    if ($Latest)
    {
        # Sort by created_at descending to get the most recent release
        $latestRelease = $releases |
            Sort-Object -Property 'created_at' -Descending |
            Select-Object -First 1

        return $latestRelease
    }

    return $releases
}
