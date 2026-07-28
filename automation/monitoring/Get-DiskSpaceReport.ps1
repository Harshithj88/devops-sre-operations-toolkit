<#
.SYNOPSIS
    Disk utilization report with configurable warning and critical thresholds.

.DESCRIPTION
    Queries disk space on remote servers and reports usage with color-coded status.
    Suitable for scheduled monitoring or capacity planning.

.PARAMETER ComputerName
    One or more server names to check.

.PARAMETER WarningPercent
    Disk usage percentage to flag as warning. Defaults to 80.

.PARAMETER CriticalPercent
    Disk usage percentage to flag as critical. Defaults to 90.

.EXAMPLE
    .\Get-DiskSpaceReport.ps1 -ComputerName "WEB-01","WEB-02","DB-01"

.EXAMPLE
    .\Get-DiskSpaceReport.ps1 -ComputerName "APP-01" -WarningPercent 70 -CriticalPercent 85
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string[]]$ComputerName,

    [Parameter()]
    [int]$WarningPercent = 80,

    [Parameter()]
    [int]$CriticalPercent = 90
)

begin {
    $results = @()
}

process {
    foreach ($server in $ComputerName) {
        try {
            $disks = Get-CimInstance -ClassName Win32_LogicalDisk -ComputerName $server `
                -Filter "DriveType=3" -ErrorAction Stop

            foreach ($disk in $disks) {
                $totalGB = [math]::Round($disk.Size / 1GB, 2)
                $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
                $usedGB = [math]::Round(($disk.Size - $disk.FreeSpace) / 1GB, 2)
                $usedPercent = [math]::Round(($usedGB / $totalGB) * 100, 1)

                $status = if ($usedPercent -ge $CriticalPercent) { 'Critical' }
                          elseif ($usedPercent -ge $WarningPercent) { 'Warning' }
                          else { 'OK' }

                $results += [PSCustomObject]@{
                    ComputerName = $server
                    Drive        = $disk.DeviceID
                    TotalGB      = $totalGB
                    UsedGB       = $usedGB
                    FreeGB       = $freeGB
                    UsedPercent  = $usedPercent
                    Status       = $status
                }
            }
        } catch {
            Write-Warning "Failed to query $server : $_"
            $results += [PSCustomObject]@{
                ComputerName = $server
                Drive        = 'N/A'
                TotalGB      = 0
                UsedGB       = 0
                FreeGB       = 0
                UsedPercent  = 0
                Status       = 'Unreachable'
            }
        }
    }
}

end {
    $results | Format-Table ComputerName, Drive, TotalGB, UsedGB, FreeGB,
        @{N='Used%'; E={$_.UsedPercent}; A='Right'},
        @{N='Status'; E={$_.Status}} -AutoSize

    $critical = ($results | Where-Object Status -eq 'Critical').Count
    $warning = ($results | Where-Object Status -eq 'Warning').Count
    if ($critical -gt 0) { Write-Host "$critical drive(s) in CRITICAL state." -ForegroundColor Red }
    if ($warning -gt 0) { Write-Host "$warning drive(s) in WARNING state." -ForegroundColor Yellow }

    return $results
}
