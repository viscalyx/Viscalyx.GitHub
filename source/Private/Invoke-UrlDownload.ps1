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

    .EXAMPLE
        Invoke-UrlDownload -Uri 'https://example.com/file.zip' -OutputPath 'C:\Downloads\file.zip'

        Downloads a file from example.com and saves it to the specified path.

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
        $UserAgent = 'Viscalyx.GitHub'
    )

    Write-Verbose -Message ($script:localizedData.Invoke_UrlDownload_DownloadingFile -f $Uri, $OutputPath)

    try
    {
        # Create WebRequest parameters
        $webRequestParams = @{
            Uri             = $Uri
            OutFile         = $OutputPath
            UserAgent       = $UserAgent
            UseBasicParsing = $true
            ErrorAction     = $ErrorActionPreference
        }

        # Download the file using Invoke-WebRequest
        # This will handle the download and progress reporting automatically
        Invoke-WebRequest @webRequestParams

        Write-Verbose -Message ($script:localizedData.Invoke_UrlDownload_DownloadCompleted -f $OutputPath)

        return $true
    }
    catch
    {
        Write-Error -Message ($script:localizedData.Invoke_UrlDownload_DownloadFailed -f $Uri, $_.Exception.Message)

        return $false
    }
}
