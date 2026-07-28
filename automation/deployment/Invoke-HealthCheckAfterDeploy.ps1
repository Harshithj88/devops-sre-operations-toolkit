<#
.SYNOPSIS
    Post-deployment HTTP smoke tests with retry logic.

.DESCRIPTION
    Validates one or more endpoints after a deployment by checking HTTP status codes
    and optional response body content. Supports configurable retries and delay.

.PARAMETER Endpoints
    Array of hashtables with Url and optional ExpectedContent keys.

.PARAMETER MaxRetries
    Maximum retry attempts per endpoint. Defaults to 5.

.PARAMETER RetryDelaySeconds
    Seconds between retries. Defaults to 10.

.EXAMPLE
    $endpoints = @(
        @{ Url = "https://myapp.com/health"; ExpectedContent = "Healthy" },
        @{ Url = "https://myapp.com/api/status" }
    )
    .\Invoke-HealthCheckAfterDeploy.ps1 -Endpoints $endpoints
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [hashtable[]]$Endpoints,

    [Parameter()]
    [int]$MaxRetries = 5,

    [Parameter()]
    [int]$RetryDelaySeconds = 10
)

$results = @()

foreach ($ep in $Endpoints) {
    $url = $ep.Url
    $expectedContent = $ep.ExpectedContent
    $passed = $false

    Write-Host "Checking $url..." -ForegroundColor Cyan

    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
            $stopwatch.Stop()

            $statusOk = $response.StatusCode -eq 200
            $contentOk = if ($expectedContent) {
                $response.Content -match [regex]::Escape($expectedContent)
            } else { $true }

            if ($statusOk -and $contentOk) {
                Write-Host "  PASS (attempt $i, ${$stopwatch.ElapsedMilliseconds}ms)" -ForegroundColor Green
                $passed = $true
                $results += [PSCustomObject]@{
                    Url        = $url
                    Status     = 'Pass'
                    StatusCode = $response.StatusCode
                    ResponseMs = $stopwatch.ElapsedMilliseconds
                    Attempt    = $i
                }
                break
            }
        } catch {
            Write-Host "  Attempt $i/$MaxRetries failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        if ($i -lt $MaxRetries) {
            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }

    if (-not $passed) {
        Write-Host "  FAIL after $MaxRetries attempts" -ForegroundColor Red
        $results += [PSCustomObject]@{
            Url        = $url
            Status     = 'Fail'
            StatusCode = 'N/A'
            ResponseMs = 'N/A'
            Attempt    = $MaxRetries
        }
    }
}

Write-Host "`nHealth Check Summary:" -ForegroundColor Cyan
$results | Format-Table Url, Status, StatusCode, ResponseMs, Attempt -AutoSize

$failCount = ($results | Where-Object Status -eq 'Fail').Count
if ($failCount -gt 0) {
    Write-Warning "$failCount endpoint(s) failed health checks."
    exit 1
}
