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

.PARAMETER RetryCount
    Number of retry attempts for failed requests. Defaults to 1 (no retry).

.PARAMETER RetryDelaySeconds
    Seconds to wait between retries. Defaults to 2.

.PARAMETER OutputJson
    If specified, writes results to a JSON file at the given path.

.EXAMPLE
    .\Test-EndpointHealth.ps1 -Url "https://myapp.com/health","https://myapp.com/api/status"

.EXAMPLE
    .\Test-EndpointHealth.ps1 -Url "https://myapp.com/health" -TimeoutSeconds 30

.EXAMPLE
    .\Test-EndpointHealth.ps1 -Url "https://myapp.com/health" -RetryCount 3 -OutputJson "C:\logs\health.json"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
    [string[]]$Url,

    [Parameter()]
    [int]$TimeoutSeconds = 10,

    [Parameter()]
    [int]$ExpectedStatusCode = 200,

    [Parameter()]
    [ValidateRange(1, 5)]
    [int]$RetryCount = 1,

    [Parameter()]
    [int]$RetryDelaySeconds = 2,

    [Parameter()]
    [string]$OutputJson
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
            Attempts     = 0
            Error        = ''
            CheckedAt    = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        }

        for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
            try {
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec $TimeoutSeconds -ErrorAction Stop
                $stopwatch.Stop()

                $result.StatusCode = $response.StatusCode
                $result.ResponseMs = $stopwatch.ElapsedMilliseconds
                $result.Attempts = $attempt

                if ($response.StatusCode -eq $ExpectedStatusCode) {
                    $result.Status = 'Healthy'
                    Write-Host "  Healthy ($($result.ResponseMs)ms)" -ForegroundColor Green
                } else {
                    $result.Status = 'Unexpected'
                    Write-Host "  Unexpected status: $($response.StatusCode)" -ForegroundColor Yellow
                }
                break
            } catch {
                $stopwatch.Stop()
                $result.ResponseMs = $stopwatch.ElapsedMilliseconds
                $result.Attempts = $attempt
                $result.Status = 'Down'
                $result.Error = $_.Exception.Message

                if ($attempt -lt $RetryCount) {
                    Write-Host "  Attempt $attempt failed, retrying in ${RetryDelaySeconds}s..." -ForegroundColor Yellow
                    Start-Sleep -Seconds $RetryDelaySeconds
                } else {
                    Write-Host "  Down after $attempt attempt(s): $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }

        $results += $result
    }
}

end {
    Write-Host "`nEndpoint Health Summary:" -ForegroundColor Cyan
    $results | Format-Table Url, Status, StatusCode, ResponseMs, Attempts, CheckedAt -AutoSize

    $downCount = ($results | Where-Object Status -eq 'Down').Count
    if ($downCount -gt 0) {
        Write-Warning "$downCount endpoint(s) are down."
    }

    if ($OutputJson) {
        $jsonDir = Split-Path $OutputJson -Parent
        if ($jsonDir -and -not (Test-Path $jsonDir)) {
            New-Item -ItemType Directory -Path $jsonDir -Force | Out-Null
        }
        $results | ConvertTo-Json -Depth 3 | Set-Content -Path $OutputJson -Encoding UTF8
        Write-Host "Results exported to: $OutputJson" -ForegroundColor Green
    }

    return $results
}
