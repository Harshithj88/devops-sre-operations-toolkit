<#
.SYNOPSIS
    Performs multi-point health checks on one or more servers.

.DESCRIPTION
    Validates server health across multiple dimensions: connectivity, disk space,
    critical services, certificate expiry, and IIS status. Returns a structured
    report suitable for dashboards or alerting.

.PARAMETER ComputerName
    One or more server names to check.

.PARAMETER DiskWarningThresholdPercent
    Disk usage percentage to flag as warning. Defaults to 80.

.PARAMETER DiskCriticalThresholdPercent
    Disk usage percentage to flag as critical. Defaults to 90.

.PARAMETER CertExpiryDays
    Flag certificates expiring within this many days. Defaults to 30.

.EXAMPLE
    .\Test-ServerHealth.ps1 -ComputerName "WEB-01","WEB-02"

.EXAMPLE
    .\Test-ServerHealth.ps1 -ComputerName "APP-01" -DiskWarningThresholdPercent 70
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string[]]$ComputerName,

    [Parameter()]
    [int]$DiskWarningThresholdPercent = 80,

    [Parameter()]
    [int]$DiskCriticalThresholdPercent = 90,

    [Parameter()]
    [int]$CertExpiryDays = 30
)

begin {
    $results = @()
}

process {
    foreach ($server in $ComputerName) {
        Write-Host "Checking $server..." -ForegroundColor Cyan

        $health = [PSCustomObject]@{
            ComputerName  = $server
            Reachable     = $false
            Uptime        = ''
            DiskStatus    = ''
            DiskDetail    = ''
            CertStatus    = ''
            CertDetail    = ''
            IISStatus     = ''
            OverallStatus = 'Unknown'
            CheckedAt     = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        }

        # 1. Connectivity
        if (-not (Test-Connection -ComputerName $server -Count 1 -Quiet)) {
            $health.OverallStatus = 'Unreachable'
            $results += $health
            Write-Host "  Unreachable" -ForegroundColor Red
            continue
        }
        $health.Reachable = $true

        try {
            # 2. Uptime
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $server -ErrorAction Stop
            $uptime = (Get-Date) - $os.LastBootUpTime
            $health.Uptime = '{0}d {1}h {2}m' -f $uptime.Days, $uptime.Hours, $uptime.Minutes

            # 3. Disk space
            $disks = Get-CimInstance -ClassName Win32_LogicalDisk -ComputerName $server -Filter "DriveType=3" -ErrorAction Stop
            $diskIssues = @()
            foreach ($disk in $disks) {
                $usedPercent = [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 1)
                $freeGB = [math]::Round($disk.FreeSpace / 1GB, 1)
                if ($usedPercent -ge $DiskCriticalThresholdPercent) {
                    $diskIssues += "$($disk.DeviceID) ${usedPercent}% used (${freeGB}GB free) [CRITICAL]"
                } elseif ($usedPercent -ge $DiskWarningThresholdPercent) {
                    $diskIssues += "$($disk.DeviceID) ${usedPercent}% used (${freeGB}GB free) [WARNING]"
                }
            }
            if ($diskIssues.Count -gt 0) {
                $health.DiskStatus = 'Warning'
                $health.DiskDetail = $diskIssues -join '; '
            } else {
                $health.DiskStatus = 'OK'
            }

            # 4. Certificate expiry
            $certs = Invoke-Command -ComputerName $server -ScriptBlock {
                param($days)
                Get-ChildItem Cert:\LocalMachine\My |
                    Where-Object { $_.NotAfter -lt (Get-Date).AddDays($days) -and $_.NotAfter -gt (Get-Date) } |
                    Select-Object Subject, NotAfter, Thumbprint
            } -ArgumentList $CertExpiryDays -ErrorAction SilentlyContinue

            if ($certs) {
                $health.CertStatus = 'Expiring'
                $health.CertDetail = ($certs | ForEach-Object {
                    "$($_.Subject) expires $($_.NotAfter.ToString('yyyy-MM-dd'))"
                }) -join '; '
            } else {
                $health.CertStatus = 'OK'
            }

            # 5. IIS status
            $iisState = Invoke-Command -ComputerName $server -ScriptBlock {
                $svc = Get-Service W3SVC -ErrorAction SilentlyContinue
                if ($svc) { $svc.Status.ToString() } else { 'NotInstalled' }
            } -ErrorAction SilentlyContinue
            $health.IISStatus = $iisState

            # Overall
            if ($health.DiskStatus -eq 'Warning' -or $health.CertStatus -eq 'Expiring' -or $iisState -ne 'Running') {
                $health.OverallStatus = 'Degraded'
            } else {
                $health.OverallStatus = 'Healthy'
            }

        } catch {
            $health.OverallStatus = 'Error'
            Write-Warning "  Error checking $server : $_"
        }

        $results += $health

        $color = switch ($health.OverallStatus) {
            'Healthy'  { 'Green' }
            'Degraded' { 'Yellow' }
            default    { 'Red' }
        }
        Write-Host "  Status: $($health.OverallStatus)" -ForegroundColor $color
    }
}

end {
    Write-Host ""
    $results | Format-Table ComputerName, OverallStatus, Uptime, DiskStatus, CertStatus, IISStatus -AutoSize
    return $results
}
