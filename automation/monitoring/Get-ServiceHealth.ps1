<#
.SYNOPSIS
    Checks Windows service status on one or more servers.

.DESCRIPTION
    Queries specified Windows services on remote servers, reports their status,
    start type, and process ID. Flags stopped services that should be running
    and provides a structured report for alerting or dashboards.

.PARAMETER ComputerName
    One or more server names to check.

.PARAMETER ServiceName
    One or more Windows service names to check. Supports wildcards.
    Defaults to common infrastructure services.

.PARAMETER IncludeDisabled
    Include disabled services in the output.

.PARAMETER OutputJson
    If specified, writes results to a JSON file at the given path.

.EXAMPLE
    .\Get-ServiceHealth.ps1 -ComputerName "WEB-01" -ServiceName "W3SVC","WAS"

.EXAMPLE
    .\Get-ServiceHealth.ps1 -ComputerName "APP-01","APP-02" -OutputJson "C:\logs\services.json"

.EXAMPLE
    "WEB-01","WEB-02" | .\Get-ServiceHealth.ps1 -ServiceName "W3SVC"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string[]]$ComputerName,

    [Parameter(Position = 1)]
    [string[]]$ServiceName = @('W3SVC', 'WAS', 'MSMQ', 'Winmgmt', 'WinRM', 'EventLog'),

    [Parameter()]
    [switch]$IncludeDisabled,

    [Parameter()]
    [string]$OutputJson
)

begin {
    $results = @()
}

process {
    foreach ($server in $ComputerName) {
        Write-Host "Checking services on $server..." -ForegroundColor Cyan

        try {
            $services = Invoke-Command -ComputerName $server -ScriptBlock {
                param($names, $includeDisabled)
                $allSvc = @()
                foreach ($name in $names) {
                    $svcs = Get-Service -Name $name -ErrorAction SilentlyContinue
                    if ($svcs) { $allSvc += $svcs }
                }
                $allSvc | Where-Object {
                    $includeDisabled -or $_.StartType -ne 'Disabled'
                } | Select-Object Name, DisplayName, Status,
                    StartType,
                    @{N='ProcessId'; E={
                        try { (Get-CimInstance Win32_Service -Filter "Name='$($_.Name)'" -ErrorAction Stop).ProcessId }
                        catch { 0 }
                    }}
            } -ArgumentList (, $ServiceName), $IncludeDisabled.IsPresent -ErrorAction Stop

            foreach ($svc in $services) {
                $healthy = ($svc.Status -eq 'Running') -or ($svc.StartType -eq 'Manual' -and $svc.Status -eq 'Stopped')

                $results += [PSCustomObject]@{
                    ComputerName = $server
                    ServiceName  = $svc.Name
                    DisplayName  = $svc.DisplayName
                    Status       = $svc.Status.ToString()
                    StartType    = $svc.StartType.ToString()
                    ProcessId    = $svc.ProcessId
                    Healthy      = $healthy
                    CheckedAt    = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                }

                $color = if ($healthy) { 'Green' } else { 'Red' }
                Write-Host "  $($svc.Name): $($svc.Status)" -ForegroundColor $color
            }

            if (-not $services) {
                Write-Host "  No matching services found" -ForegroundColor Yellow
            }
        } catch {
            Write-Warning "  Failed to query $server : $_"
            $results += [PSCustomObject]@{
                ComputerName = $server
                ServiceName  = 'N/A'
                DisplayName  = 'N/A'
                Status       = 'Error'
                StartType    = 'N/A'
                ProcessId    = 0
                Healthy      = $false
                CheckedAt    = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            }
        }
    }
}

end {
    Write-Host "`nService Health Summary:" -ForegroundColor Cyan
    $results | Format-Table ComputerName, ServiceName, Status, StartType, Healthy -AutoSize

    $unhealthy = ($results | Where-Object { -not $_.Healthy }).Count
    if ($unhealthy -gt 0) {
        Write-Warning "$unhealthy service(s) are unhealthy."
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
