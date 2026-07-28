<#
.SYNOPSIS
    HTTP(S) endpoint health checker with response time and status tracking.

.DESCRIPTION
    Tests one or more URLs for availability, records response time and status code,
    and outputs a summary report. Useful for scheduled monitoring or post-deploy validation.

.PARAMETER Url
    One or more URLs to check.

.PARAMETER TimeoutSeconds
    HTTP request timeout. Defaults to 10.

.PARAMETER ExpectedStatusCode
    Expected HTTP status code. Defaults to 200.

.EXAMPLE
    .\Test-EndpointHealth.ps1 -Url "https://myapp.com/health","https://myapp.com/api/status"

.EXAMPLE
    .\Test-EndpointHealth.ps1 -Url "https://myapp.com/health" -TimeoutSeconds 30
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
    [string[]]$Url,

    [Parameter()]
    [int]$TimeoutSeconds = 10,

    [Parameter()]
    [int]$ExpectedStatusCode = 200
)

begin {
    $results = @()
}

process {
    foreach ($uri in $Url) {
        Write-Host "Testing $uri..." -ForegroundColor Cyan

        $result = [PSCustomObject]@{
            Url          = $uri
            StatusCode   = 0
            ResponseMs   = 0
            Status       = 'Unknown'
            Error        = ''
            CheckedAt    = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        }

        try {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec $TimeoutSeconds -ErrorAction Stop
            $stopwatch.Stop()

            $result.StatusCode = $response.StatusCode
            $result.ResponseMs = $stopwatch.ElapsedMilliseconds

            if ($response.StatusCode -eq $ExpectedStatusCode) {
                $result.Status = 'Healthy'
                Write-Host "  Healthy ($($result.ResponseMs)ms)" -ForegroundColor Green
            } else {
                $result.Status = 'Unexpected'
                Write-Host "  Unexpected status: $($response.StatusCode)" -ForegroundColor Yellow
            }
        } catch {
            $stopwatch.Stop()
            $result.ResponseMs = $stopwatch.ElapsedMilliseconds
            $result.Status = 'Down'
            $result.Error = $_.Exception.Message
            Write-Host "  Down: $($_.Exception.Message)" -ForegroundColor Red
        }

        $results += $result
    }
}

end {
    Write-Host "`nEndpoint Health Summary:" -ForegroundColor Cyan
    $results | Format-Table Url, Status, StatusCode, ResponseMs, CheckedAt -AutoSize

    $downCount = ($results | Where-Object Status -eq 'Down').Count
    if ($downCount -gt 0) {
        Write-Warning "$downCount endpoint(s) are down."
    }
    return $results
}
