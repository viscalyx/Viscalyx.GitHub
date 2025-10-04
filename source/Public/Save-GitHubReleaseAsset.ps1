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

    .PARAMETER MaxRetries
        Specifies the maximum number of retry attempts for failed downloads due to
        transient network issues. The default value is 3. Each retry uses exponential
        backoff (2^attempt seconds) before attempting the download again.

    .PARAMETER FileHash
        Specifies the expected SHA256 file hash for verification. Can be either:
        - A hashtable containing expected SHA256 file hashes keyed by asset names (for multiple files)
        - A string containing the expected SHA256 hash (for single file downloads)
        After each successful download, the actual file hash is computed and compared to
        the expected hash. If they differ, the downloaded file is deleted and an error
        is written. This parameter enables file integrity validation during the download
        process.

    .PARAMETER Force
        Forces the download even if the file already exists at the specified output path.
        Without this parameter, the command will skip downloading files that already exist.

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

    .EXAMPLE
        Save-GitHubReleaseAsset -Uri 'https://github.com/PowerShell/PowerShell/releases/download/v7.3.0/PowerShell-7.3.0-win-x64.msi' -Path 'C:\Downloads' -FileHash 'A1B2C3D4E5F6...'

        Downloads a PowerShell MSI and verifies its SHA256 hash matches the expected value. If the hash doesn't match, the downloaded file is deleted and an error is written.

    .EXAMPLE
        $fileHashes = @{ 'PowerShell-7.3.0-win-x64.msi' = 'A1B2C3D4E5F6...'; 'PowerShell-7.3.0-win-x86.msi' = 'F6E5D4C3B2A1...' }
        $inputObject = Get-GitHubReleaseAsset -Owner 'PowerShell' -Repository 'PowerShell' -Tag 'v7.3.0' ; Save-GitHubReleaseAsset -InputObject $inputObject -Path 'C:\Downloads' -AssetName '*win*.msi' -FileHash $fileHashes

        Downloads multiple PowerShell MSI files and verifies each file's SHA256 hash against the corresponding value in the hashtable. Files with mismatched hashes are deleted and errors are written.

    .EXAMPLE
        $inputObject = Get-GitHubReleaseAsset -Owner 'PowerShell' -Repository 'PowerShell' -Tag 'v7.3.0' ; Save-GitHubReleaseAsset -InputObject $inputObject -Path 'C:\Downloads' -Force

        Downloads all assets from PowerShell v7.3.0 release to the C:\Downloads directory, overwriting any existing files.

    .INPUTS
        System.Management.Automation.PSObject

        Accepts GitHub release asset objects with 'name' and 'browser_download_url' properties.

    .OUTPUTS
        None

        This command does not generate output.
#>
function Save-GitHubReleaseAsset
{
    [CmdletBinding(DefaultParameterSetName = 'ByInputObject', SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    [OutputType()]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'ByInputObject')]
        [AllowEmptyCollection()]
        [AllowNull()]
        [PSObject[]]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [ValidateScript({
            if ((Test-Path -Path $_) -and -not (Test-Path -Path $_ -PathType Container))
            {
                throw ($script:localizedData.Save_GitHubReleaseAsset_PathIsFile -f $_)
            }
            return $true
        })]
        [System.String]
        $Path,

        [Parameter(ParameterSetName = 'ByInputObject')]
        [Parameter(ParameterSetName = 'ByUri')]
        [System.String]
        $AssetName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByUri')]
        [System.Uri]
        $Uri,

        [Parameter()]
        [ValidateRange(0, 10)]
        [System.Int32]
        $MaxRetries = 3,

        [Parameter()]
        [ValidateScript({
            $_ -is [System.Collections.Hashtable] -or $_ -is [System.String]
        })]
        [System.Object]
        $FileHash,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $Force
    )

    begin
    {
        if ($Force.IsPresent -and -not $Confirm)
        {
            $ConfirmPreference = 'None'
        }

        # Create a collection to store assets for processing
        $assetsToDownload = New-Object -TypeName 'System.Collections.Generic.List[PSObject]'

        # Flag to track if we should skip processing
        $skipProcessing = $false

        # Ensure the output directory exists
        if (-not (Test-Path -Path $Path))
        {
            $shouldProcessDescriptionMessage = $script:localizedData.Save_GitHubReleaseAsset_ShouldProcessDescription -f $Path
            $shouldProcessQuestionMessage = $script:localizedData.Save_GitHubReleaseAsset_ShouldProcessQuestion
            $shouldProcessCaptionMessage = $script:localizedData.Save_GitHubReleaseAsset_ShouldProcessCaption

            if ($PSCmdlet.ShouldProcess($shouldProcessDescriptionMessage, $shouldProcessQuestionMessage, $shouldProcessCaptionMessage))
            {
                Write-Verbose -Message ($script:localizedData.Save_GitHubReleaseAsset_CreatingDirectory -f $Path)
                $null = New-Item -Path $Path -ItemType Directory -Force
            }
            else
            {
                # User declined to create the directory, set flag to skip processing
                $skipProcessing = $true
                return
            }
        }

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
        # Skip processing if user declined directory creation
        if ($skipProcessing)
        {
            return
        }

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
        # Skip processing if user declined directory creation
        if ($skipProcessing)
        {
            return
        }

        if ($assetsToDownload.Count -eq 0)
        {
            Write-Error -Message $script:localizedData.Save_GitHubReleaseAsset_NoAssetsToDownload -Category ObjectNotFound -ErrorId 'SGRA0003' -TargetObject $AssetName

            return
        }

        Write-Verbose -Message ($script:localizedData.Save_GitHubReleaseAsset_DownloadingAssets -f $assetsToDownload.Count)

        # Download assets one by one with progress indicator
        for ($i = 0; $i -lt $assetsToDownload.Count; $i++)
        {
            $asset = $assetsToDownload[$i]
            $destination = Join-Path -Path $Path -ChildPath $asset.name
            $activityMessage = $script:localizedData.Save_GitHubReleaseAsset_Progress_DownloadingAssets_Status -f $asset.name, ($i + 1), $assetsToDownload.Count
            $percentComplete = [System.Math]::Round((($i + 1) / $assetsToDownload.Count) * 100)

            # Show progress
            Write-Progress -Activity $script:localizedData.Save_GitHubReleaseAsset_Progress_DownloadingAssets_Activity -Status $activityMessage -PercentComplete $percentComplete

            Write-Verbose -Message ($script:localizedData.Save_GitHubReleaseAsset_DownloadingAsset -f $asset.name, $destination)

            # Check if user approves downloading this asset
            $shouldProcessDescriptionMessage = $script:localizedData.Save_GitHubReleaseAsset_ShouldProcessDownloadDescription -f $asset.name, $destination
            $shouldProcessQuestionMessage = $script:localizedData.Save_GitHubReleaseAsset_ShouldProcessDownloadQuestion
            $shouldProcessCaptionMessage = $script:localizedData.Save_GitHubReleaseAsset_ShouldProcessDownloadCaption

            if (-not $PSCmdlet.ShouldProcess($shouldProcessDescriptionMessage, $shouldProcessQuestionMessage, $shouldProcessCaptionMessage))
            {
                Write-Verbose -Message ($script:localizedData.Save_GitHubReleaseAsset_SkippedByUser -f $asset.name)
                continue
            }

            # Use the private function to download the file with retry logic
            $attempt = 0
            $downloadSuccessful = $false
            $lastException = $null

            while ($attempt -le $MaxRetries -and -not $downloadSuccessful)
            {
                $attempt++

                try
                {
                    $downloadResult = Invoke-UrlDownload -Uri $asset.browser_download_url -OutputPath $destination -Force:$Force -ErrorAction Stop
                    $downloadSuccessful = $downloadResult
                }
                catch
                {
                    $lastException = $_

                    if ($attempt -le $MaxRetries)
                    {
                        # Calculate exponential backoff: 2^attempt seconds
                        $waitTime = [System.Math]::Pow(2, $attempt)

                        Write-Verbose -Message ($script:localizedData.Save_GitHubReleaseAsset_RetryingDownload -f $asset.name, $attempt, $MaxRetries, $waitTime)

                        Start-Sleep -Seconds $waitTime
                    }
                    else
                    {
                        # Max retries exceeded
                        if ($ErrorActionPreference -eq 'Stop')
                        {
                            throw
                        }
                    }
                }
            }

            if (-not $downloadSuccessful)
            {
                # Download failed after all retries
                if ($ErrorActionPreference -eq 'Stop')
                {
                    throw ($script:localizedData.Save_GitHubReleaseAsset_DownloadFailed -f $asset.name)
                }
                else
                {
                    $errorMessage = $script:localizedData.Save_GitHubReleaseAsset_DownloadFailed -f $asset.name

                    if ($lastException)
                    {
                        # Create an ErrorRecord with full metadata using the captured exception
                        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                            $lastException.Exception,
                            'SGRA0001',
                            [System.Management.Automation.ErrorCategory]::OperationStopped,
                            $asset.name
                        )
                        $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new($errorMessage)
                        Write-Error -ErrorRecord $errorRecord
                    }
                    else
                    {
                        # Fallback if no exception was captured
                        Write-Error -Message $errorMessage -Category OperationStopped -ErrorId 'SGRA0001' -TargetObject $asset.name
                    }
                }
            }

            # Verify file hash if FileHash parameter is provided and download was successful
            if ($downloadSuccessful -and $PSBoundParameters.ContainsKey('FileHash'))
            {
                # Determine the expected hash based on the type of FileHash parameter
                $expectedHash = if ($FileHash -is [System.String])
                {
                    # String type: use the hash for the current asset
                    $FileHash
                }
                elseif ($FileHash -is [System.Collections.Hashtable] -and $FileHash.ContainsKey($asset.name))
                {
                    # Hashtable type: look up the hash for this asset
                    $FileHash[$asset.name]
                }
                else
                {
                    # No hash available for this asset, skip validation
                    $null
                }

                if ($expectedHash)
                {
                    Write-Verbose -Message ($script:localizedData.Save_GitHubReleaseAsset_VerifyingHash -f $asset.name)

                $actualHash = (Get-FileHash -Path $destination -Algorithm SHA256).Hash

                if ($actualHash -ne $expectedHash)
                {
                    # Hash mismatch - delete the file and write error
                    Remove-Item -Path $destination -Force

                    $errorMessage = $script:localizedData.Save_GitHubReleaseAsset_HashMismatch -f $asset.name, $expectedHash, $actualHash

                    if ($ErrorActionPreference -eq 'Stop')
                    {
                        throw $errorMessage
                    }
                    else
                    {
                        Write-Error -Message $errorMessage -Category InvalidData -ErrorId 'SGRA0002' -TargetObject $asset.name
                    }

                    # Skip further processing for this asset
                    continue
                }
                    else
                    {
                        Write-Verbose -Message ($script:localizedData.Save_GitHubReleaseAsset_HashVerified -f $asset.name)
                    }
                }
            }
        }

        # Complete the progress bar
        Write-Progress -Activity $script:localizedData.Save_GitHubReleaseAsset_Progress_DownloadingAssets_Activity -Completed

        Write-Verbose -Message $script:localizedData.Save_GitHubReleaseAsset_DownloadsCompleted
    }
}
