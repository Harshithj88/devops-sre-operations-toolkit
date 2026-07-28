<#
.SYNOPSIS
    Performs a rolling IIS restart across a group of servers with health-check gates.

.DESCRIPTION
    Restarts IIS on each server one at a time, waiting for the health endpoint to
    return HTTP 200 before proceeding to the next server. Supports load-balanced
    environments where taking all servers offline simultaneously is not acceptable.

.PARAMETER ComputerName
    Array of server names to restart in order.

.PARAMETER HealthEndpoint
    URL path to check after restart (e.g., /health). Combined with each server name.

.PARAMETER HealthPort
    Port for the health check. Defaults to 443.

.PARAMETER MaxRetries
    Maximum health check attempts per server before marking as failed. Defaults to 10.

.PARAMETER RetryDelaySeconds
    Seconds between health check retries. Defaults to 15.

.PARAMETER WhatIf
    Show what would happen without making changes.

.EXAMPLE
    .\Invoke-RollingRestart.ps1 -ComputerName "WEB-01","WEB-02","WEB-03" -HealthEndpoint "/health"
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, Position = 0)]
    [string[]]$ComputerName,

    [Parameter()]
    [string]$HealthEndpoint = '/health',

    [Parameter()]
    [int]$HealthPort = 443,

    [Parameter()]
    [int]$MaxRetries = 10,

    [Parameter()]
    [int]$RetryDelaySeconds = 15
)

function Test-ServerHealth {
    param([string]$Server, [string]$Path, [int]$Port)

    $uri = "https://${Server}:${Port}${Path}"
    try {
        $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        return $response.StatusCode -eq 200
    } catch {
        return $false
    }
}

$totalServers = $ComputerName.Count
$completed = 0
$failed = @()

Write-Host "Starting rolling restart for $totalServers server(s)..." -ForegroundColor Cyan
Write-Host "Health endpoint: $HealthEndpoint (port $HealthPort)" -ForegroundColor Gray
Write-Host ""

foreach ($server in $ComputerName) {
    $completed++
    Write-Host "[$completed/$totalServers] Processing $server" -ForegroundColor Yellow

    if ($PSCmdlet.ShouldProcess($server, "Restart IIS")) {
        # Restart IIS
        Write-Host "  Restarting IIS on $server..." -ForegroundColor Gray
        try {
            Invoke-Command -ComputerName $server -ScriptBlock {
                iisreset /restart
            } -ErrorAction Stop
            Write-Host "  IIS restarted." -ForegroundColor Green
        } catch {
            Write-Warning "  Failed to restart IIS on $server : $_"
            $failed += $server
            continue
        }

        # Wait for health check to pass
        Write-Host "  Waiting for health check..." -ForegroundColor Gray
        $healthy = $false
        for ($i = 1; $i -le $MaxRetries; $i++) {
            Start-Sleep -Seconds $RetryDelaySeconds
            $healthy = Test-ServerHealth -Server $server -Path $HealthEndpoint -Port $HealthPort
            if ($healthy) {
                Write-Host "  Health check passed (attempt $i/$MaxRetries)" -ForegroundColor Green
                break
            }
            Write-Host "  Attempt $i/$MaxRetries - not healthy yet..." -ForegroundColor Gray
        }

        if (-not $healthy) {
            Write-Warning "  $server did not become healthy after $MaxRetries attempts."
            $failed += $server

            if ($completed -lt $totalServers) {
                Write-Host "  Stopping rolling restart to prevent further impact." -ForegroundColor Red
                break
            }
        }
    }

    Write-Host ""
}

# Summary
Write-Host "Rolling restart complete." -ForegroundColor Cyan
Write-Host "  Succeeded: $($completed - $failed.Count)" -ForegroundColor Green
if ($failed.Count -gt 0) {
    Write-Host "  Failed: $($failed -join ', ')" -ForegroundColor Red
}
