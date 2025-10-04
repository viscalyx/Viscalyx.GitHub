<#
    .SYNOPSIS
        Downloads a file from a URL with progress indication.

    .DESCRIPTION
        The Invoke-UrlDownload function downloads a file from a specified URL to a
        local destination path. It displays download progress using Write-Progress
        and handles download completion events. This function supports user agent
        configuration and proper error handling for failed downloads.

    .PARAMETER Uri
        Specifies the URL from which to download the file.

    .PARAMETER OutputPath
        Specifies the local file path where the downloaded file will be saved.

    .PARAMETER UserAgent
        Specifies the User-Agent header to be used in the HTTP request.
        Defaults to 'Viscalyx.GitHub'.

    .PARAMETER Force
        Forces the download even if the file already exists at the specified output path.
        Without this parameter, the function will skip the download if the file exists.

    .EXAMPLE
        Invoke-UrlDownload -Uri 'https://example.com/file.zip' -OutputPath 'C:\Downloads\file.zip'

        Downloads a file from example.com and saves it to the specified path.

    .EXAMPLE
        Invoke-UrlDownload -Uri 'https://example.com/file.zip' -OutputPath 'C:\Downloads\file.zip' -Force

        Downloads a file from example.com and overwrites any existing file at the specified path.

    .INPUTS
        None. This function does not accept pipeline input.

    .OUTPUTS
        System.Boolean

        Returns $true when the download succeeds or when the download is skipped because
        the file already exists (when -Force is not specified). Returns $false when a
        non-terminating error occurs. A terminating error will throw and produce no
        return value.

    .NOTES
        This function is designed to be used internally by other commands within the module.
#>
function Invoke-UrlDownload
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Uri]
        $Uri,

        [Parameter(Mandatory = $true)]
        [System.String]
        $OutputPath,

        [Parameter()]
        [System.String]
        $UserAgent = 'Viscalyx.GitHub',

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $Force
    )

    # Validate and create output directory if needed
    $outputDirectory = Split-Path -Path $OutputPath -Parent

    if (-not [string]::IsNullOrWhiteSpace($outputDirectory))
    {
        if (-not (Test-Path -Path $outputDirectory))
        {
            try
            {
                Write-Verbose -Message ($script:localizedData.Invoke_UrlDownload_CreatingDirectory -f $outputDirectory)

                $null = New-Item -Path $outputDirectory -ItemType Directory -Force -ErrorAction Stop
            }
            catch
            {
                $errorMessage = $script:localizedData.Invoke_UrlDownload_DirectoryCreationError -f $outputDirectory, $_.Exception.Message

                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::new(
                        ($errorMessage),
                        'IUD0001',
                        [System.Management.Automation.ErrorCategory]::InvalidOperation,
                        $outputDirectory
                    )
                )
            }
        }
    }

    # Check if file already exists
    if (Test-Path -Path $OutputPath)
    {
        if ($Force)
        {
            Write-Verbose -Message ($script:localizedData.Invoke_UrlDownload_DownloadingFile -f $Uri, $OutputPath)
        }
        else
        {
            Write-Verbose -Message ($script:localizedData.Invoke_UrlDownload_SkippingDownload -f $OutputPath)
            return $true
        }
    }
    else
    {
        Write-Verbose -Message ($script:localizedData.Invoke_UrlDownload_DownloadingFile -f $Uri, $OutputPath)
    }

    try
    {
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'

        # Create WebRequest parameters
        $webRequestParams = @{
            Uri         = $Uri
            OutFile     = $OutputPath
            UserAgent   = $UserAgent
            ErrorAction = 'Stop'
        }

        <#
            Add UseBasicParsing parameter only for Windows PowerShell 5.1.
            In PowerShell Core/7+, basic parsing is the default and the parameter
            is deprecated/removed
        #>
        if ($PSVersionTable.PSEdition -eq 'Desktop')
        {
            $webRequestParams.UseBasicParsing = $true
        }

        # Download the file using Invoke-WebRequest
        # This will handle the download and progress reporting automatically
        Invoke-WebRequest @webRequestParams

        $ErrorActionPreference = $previousErrorActionPreference

        Write-Verbose -Message ($script:localizedData.Invoke_UrlDownload_DownloadCompleted -f $OutputPath)

        return $true
    }
    catch
    {
        $ErrorActionPreference = $previousErrorActionPreference

        # Save the error record before entering any switch or other context-changing statements
        $errorRecord = $_

        # Determine the type of error and provide specific error message
        $errorMessage = $errorRecord.Exception.Message

        if ($errorRecord.Exception -is [System.Net.WebException])
        {
            $webException = $errorRecord.Exception -as [System.Net.WebException]

            # Check if there's an HTTP response
            if ($webException.Response)
            {
                $response = $webException.Response

                # Check if we can access StatusCode
                if ($response.StatusCode)
                {
                    $statusCode = $response.StatusCode.value__

                    switch ($statusCode)
                    {
                        401
                        {
                            $exception = New-Exception -Message ($script:localizedData.Invoke_UrlDownload_UnauthorizedError -f $Uri, $errorMessage) -ErrorRecord $errorRecord

                            Write-Error -Message ($script:localizedData.Invoke_UrlDownload_UnauthorizedError -f $Uri, $errorMessage) -Category SecurityError -ErrorId 'Invoke_UrlDownload_Unauthorized' -TargetObject $Uri -Exception $exception
                        }

                        404
                        {
                            $exception = New-Exception -Message ($script:localizedData.Invoke_UrlDownload_NotFoundError -f $Uri, $errorMessage) -ErrorRecord $errorRecord

                            Write-Error -Message ($script:localizedData.Invoke_UrlDownload_NotFoundError -f $Uri, $errorMessage) -Category ResourceUnavailable -ErrorId 'Invoke_UrlDownload_NotFound' -TargetObject $Uri -Exception $exception
                        }

                        default
                        {
                            $exception = New-Exception -Message ($script:localizedData.Invoke_UrlDownload_NetworkError -f $Uri, $errorMessage) -ErrorRecord $errorRecord

                            Write-Error -Message ($script:localizedData.Invoke_UrlDownload_NetworkError -f $Uri, $errorMessage) -Category NotSpecified -ErrorId 'Invoke_UrlDownload_NetworkError' -TargetObject $Uri -Exception $exception
                        }
                    }
                }
                else
                {
                    $exception = New-Exception -Message ($script:localizedData.Invoke_UrlDownload_NetworkError -f $Uri, $errorMessage) -ErrorRecord $errorRecord

                    Write-Error -Message ($script:localizedData.Invoke_UrlDownload_NetworkError -f $Uri, $errorMessage) -Category NotSpecified -ErrorId 'Invoke_UrlDownload_NetworkError' -TargetObject $Uri -Exception $exception
                }
            }
            else
            {
                $exception = New-Exception -Message ($script:localizedData.Invoke_UrlDownload_NetworkError -f $Uri, $errorMessage) -ErrorRecord $errorRecord

                Write-Error -Message ($script:localizedData.Invoke_UrlDownload_NetworkError -f $Uri, $errorMessage) -Category NotSpecified -ErrorId 'Invoke_UrlDownload_NetworkError' -TargetObject $Uri -Exception $exception
            }
        }
        elseif ($errorRecord.Exception -is [System.UnauthorizedAccessException] -or
                ($errorRecord.Exception -is [System.IO.IOException] -and $errorMessage -match 'denied|access'))
        {
            $exception = New-Exception -Message ($script:localizedData.Invoke_UrlDownload_PermissionError -f $OutputPath, $errorMessage) -ErrorRecord $errorRecord

            Write-Error -Message ($script:localizedData.Invoke_UrlDownload_PermissionError -f $OutputPath, $errorMessage) -Category PermissionDenied -ErrorId 'Invoke_UrlDownload_PermissionError' -TargetObject $OutputPath -Exception $exception
        }
        else
        {
            $exception = New-Exception -Message ($script:localizedData.Invoke_UrlDownload_UnknownError -f $Uri, $errorMessage) -ErrorRecord $errorRecord

            Write-Error -Message ($script:localizedData.Invoke_UrlDownload_UnknownError -f $Uri, $errorMessage) -Category NotSpecified -ErrorId 'Invoke_UrlDownload_UnknownError' -TargetObject $Uri -Exception $exception
        }

        return $false
    }
}
