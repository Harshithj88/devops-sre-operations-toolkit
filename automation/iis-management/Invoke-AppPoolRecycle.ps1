<#
.SYNOPSIS
    Recycles IIS application pools with connection drain and health verification.

.DESCRIPTION
    Safely recycles app pools by stopping them (allowing active requests to drain),
    then starting them and verifying health via a configurable endpoint.

.PARAMETER ComputerName
    One or more server names.

.PARAMETER AppPoolName
    Name of the application pool to recycle.

.PARAMETER DrainTimeoutSeconds
    Seconds to wait for connections to drain before forcing stop. Defaults to 30.

.PARAMETER HealthUrl
    Optional URL to verify after recycle.

.EXAMPLE
    .\Invoke-AppPoolRecycle.ps1 -ComputerName "WEB-01","WEB-02" -AppPoolName "MyAppPool" -HealthUrl "https://WEB-01/health"
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, Position = 0)]
    [string[]]$ComputerName,

    [Parameter(Mandatory)]
    [string]$AppPoolName,

    [Parameter()]
    [int]$DrainTimeoutSeconds = 30,

    [Parameter()]
    [string]$HealthUrl
)

foreach ($server in $ComputerName) {
    if ($PSCmdlet.ShouldProcess("$server\$AppPoolName", "Recycle app pool")) {
        Write-Host "[$server] Recycling app pool '$AppPoolName'..." -ForegroundColor Cyan

        try {
            Invoke-Command -ComputerName $server -ScriptBlock {
                param($poolName, $drainTimeout)
                Import-Module WebAdministration

                $pool = Get-Item "IIS:\AppPools\$poolName" -ErrorAction Stop

                if ($pool.State -eq 'Started') {
                    Write-Host "  Stopping (drain timeout: ${drainTimeout}s)..."
                    $pool.Stop()
                    $elapsed = 0
                    while ($pool.State -ne 'Stopped' -and $elapsed -lt $drainTimeout) {
                        Start-Sleep -Seconds 2
                        $elapsed += 2
                        $pool = Get-Item "IIS:\AppPools\$poolName"
                    }
                    if ($pool.State -ne 'Stopped') {
                        Write-Warning "  Force stopping after drain timeout."
                        $pool.Stop()
                        Start-Sleep -Seconds 2
                    }
                }

                Write-Host "  Starting..."
                $pool = Get-Item "IIS:\AppPools\$poolName"
                $pool.Start()
                Write-Host "  App pool started."
            } -ArgumentList $AppPoolName, $DrainTimeoutSeconds -ErrorAction Stop

            Write-Host "[$server] Recycle complete." -ForegroundColor Green

            if ($HealthUrl) {
                $healthUri = $HealthUrl -replace 'WEB-\d+', $server
                Write-Host "[$server] Verifying health at $healthUri..." -ForegroundColor Gray
                Start-Sleep -Seconds 5
                try {
                    $resp = Invoke-WebRequest -Uri $healthUri -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
                    if ($resp.StatusCode -eq 200) {
                        Write-Host "[$server] Health check passed." -ForegroundColor Green
                    } else {
                        Write-Warning "[$server] Health returned $($resp.StatusCode)"
                    }
                } catch {
                    Write-Warning "[$server] Health check failed: $_"
                }
            }
        } catch {
            Write-Warning "[$server] Failed: $_"
        }
    }
}
