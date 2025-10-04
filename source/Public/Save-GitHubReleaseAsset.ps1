<#
    .SYNOPSIS
        Downloads GitHub release assets to a specified path.

    .DESCRIPTION
        The Save-GitHubReleaseAsset command downloads GitHub release assets
        to a specified local path. It can process multiple assets passed through
        the pipeline from Get-GitHubReleaseAsset and supports filtering by asset name.
        The command displays a progress bar during download to provide visual feedback
        to the user about the download status.

        The command can be used in two ways:
        1. By piping GitHub release asset objects from Get-GitHubReleaseAsset
        2. By directly specifying the download URI for an asset

    .PARAMETER InputObject
        Specifies the GitHub release asset objects to download. These objects
        are typically passed through the pipeline from Get-GitHubReleaseAsset.

    .PARAMETER Path
        Specifies the local path where the assets will be downloaded. If the
        path doesn't exist, it will be created.

    .PARAMETER AssetName
        Specifies a filter to download only assets that match the given name pattern.
        Wildcard characters are supported.

    .PARAMETER Uri
        Specifies the direct URI to a GitHub release asset to download. This parameter
        cannot be used together with InputObject.

    .EXAMPLE
        $inputObject = Get-GitHubReleaseAsset -Owner 'PowerShell' -Repository 'PowerShell' -Tag 'v7.3.0' ; Save-GitHubReleaseAsset  -InputObject $inputObject -Path 'C:\Downloads'

        Downloads all assets from PowerShell v7.3.0 release to the C:\Downloads directory.

    .EXAMPLE
        $inputObject = Get-GitHubReleaseAsset -Owner 'PowerShell' -Repository 'PowerShell' -Tag 'v7.3.0' ; Save-GitHubReleaseAsset -InputObject $inputObject -Path 'C:\Downloads' -AssetName '*win-x64*'

        Downloads only the Windows x64 assets from PowerShell v7.3.0 release to the C:\Downloads directory.

    .EXAMPLE
        Save-GitHubReleaseAsset -Uri 'https://github.com/PowerShell/PowerShell/releases/download/v7.3.0/PowerShell-7.3.0-win-x64.msi' -Path 'C:\Downloads'

        Downloads a specific PowerShell 7.3.0 MSI directly using its URI to the C:\Downloads directory.

    .EXAMPLE
        Save-GitHubReleaseAsset -Uri 'https://github.com/PowerShell/PowerShell/releases/download/v7.3.0/PowerShell-7.3.0-win-x64.msi' -Path 'C:\Downloads' -AssetName 'custom-name.msi'

        Downloads a specific PowerShell MSI and saves it as 'custom-name.msi' in the C:\Downloads directory.

    .INPUTS
        System.Management.Automation.PSObject

        Accepts GitHub release asset objects with 'name' and 'browser_download_url' properties.

    .OUTPUTS
        None

        This command does not generate output.
#>
function Save-GitHubReleaseAsset
{
    [CmdletBinding(DefaultParameterSetName = 'ByInputObject')]
    [OutputType()]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'ByInputObject')]
        [AllowEmptyCollection()]
        [AllowNull()]
        [PSObject[]]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(ParameterSetName = 'ByInputObject')]
        [Parameter(ParameterSetName = 'ByUri')]
        [System.String]
        $AssetName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByUri')]
        [System.Uri]
        $Uri
    )

    begin
    {
        # Ensure the output directory exists
        if (-not (Test-Path -Path $Path))
        {
            Write-Verbose -Message ($script:localizedData.Save_GitHubReleaseAsset_CreatingDirectory -f $Path)
            $null = New-Item -Path $Path -ItemType Directory -Force
        }

        # Create a collection to store assets for processing
        $assetsToDownload = New-Object -TypeName 'System.Collections.Generic.List[PSObject]'

        # If Uri parameter is used, create a custom object to represent the asset
        if ($PSCmdlet.ParameterSetName -eq 'ByUri')
        {
            $uriFileName = [System.IO.Path]::GetFileName($Uri.AbsolutePath)

            # If AssetName is specified, use that as the filename instead
            $fileName = if ($PSBoundParameters.ContainsKey('AssetName'))
            {
                $AssetName
            }
            else
            {
                $uriFileName
            }

            $assetObject = [PSCustomObject]@{
                name                 = $fileName
                browser_download_url = $Uri.AbsoluteUri
            }

            $assetsToDownload.Add($assetObject)

            Write-Verbose -Message ($script:localizedData.Save_GitHubReleaseAsset_UsingDirectUri -f $Uri, $fileName)
        }
    }

    process
    {
        # Only process pipeline input for ByInputObject parameter set
        if ($PSCmdlet.ParameterSetName -eq 'ByInputObject')
        {
            foreach ($asset in $InputObject)
            {
                # Skip assets that don't match the asset name filter if one is provided
                if ($PSBoundParameters.ContainsKey('AssetName'))
                {
                    if (-not ($asset.name -like $AssetName))
                    {
                        Write-Verbose -Message ($script:localizedData.Save_GitHubReleaseAsset_AssetFiltered -f $asset.name, $AssetName)
                        continue
                    }
                }

                # Add asset to the collection
                $assetsToDownload.Add($asset)
            }
        }
    }

    end
    {
        if ($assetsToDownload.Count -eq 0)
        {
            Write-Warning -Message $script:localizedData.Save_GitHubReleaseAsset_NoAssetsToDownload
            return
        }

        Write-Verbose -Message ($script:localizedData.Save_GitHubReleaseAsset_DownloadingAssets -f $assetsToDownload.Count)

        # Download assets one by one with progress indicator
        for ($i = 0; $i -lt $assetsToDownload.Count; $i++)
        {
            $asset = $assetsToDownload[$i]
            $destination = Join-Path -Path $Path -ChildPath $asset.name
            $activityMessage = "Downloading $($asset.name) [$($i+1)/$($assetsToDownload.Count)]"
            $percentComplete = [System.Math]::Round((($i + 1) / $assetsToDownload.Count) * 100)

            # Show progress
            Write-Progress -Activity 'Downloading GitHub Release Assets' -Status $activityMessage -PercentComplete $percentComplete

            Write-Verbose -Message ($script:localizedData.Save_GitHubReleaseAsset_DownloadingAsset -f $asset.name, $destination)

            # Use the private function to download the file
            $downloadResult = Invoke-UrlDownload -Uri $asset.browser_download_url -OutputPath $destination -ErrorAction $ErrorActionPreference

            if (-not $downloadResult)
            {
                # This is only reached if the download fails and the ErrorActionPreference is set to 'Continue' (Invoke-UrlDownload returns $false).
                Write-Error -Message ($script:localizedData.Save_GitHubReleaseAsset_DownloadFailed -f $asset.name)
            }
        }

        # Complete the progress bar
        Write-Progress -Activity 'Downloading GitHub Release Assets' -Completed

        Write-Verbose -Message $script:localizedData.Save_GitHubReleaseAsset_DownloadsCompleted
    }
}
