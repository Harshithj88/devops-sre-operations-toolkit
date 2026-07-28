<#
.SYNOPSIS
    Scans servers for certificates expiring within a configurable threshold.

.DESCRIPTION
    Remotely queries the LocalMachine\My certificate store on each server and reports
    certificates that will expire within the specified number of days. Outputs a
    structured report for remediation planning.

.PARAMETER ComputerName
    One or more server names to scan.

.PARAMETER DaysUntilExpiry
    Report certificates expiring within this many days. Defaults to 30.

.PARAMETER IncludeExpired
    Include already-expired certificates in the report.

.EXAMPLE
    .\Get-ExpiringCertificates.ps1 -ComputerName "WEB-01","WEB-02" -DaysUntilExpiry 60

.EXAMPLE
    .\Get-ExpiringCertificates.ps1 -ComputerName "APP-01" -IncludeExpired
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string[]]$ComputerName,

    [Parameter()]
    [int]$DaysUntilExpiry = 30,

    [Parameter()]
    [switch]$IncludeExpired
)

begin {
    $results = @()
    $cutoffDate = (Get-Date).AddDays($DaysUntilExpiry)
    Write-Host "Scanning for certificates expiring before $($cutoffDate.ToString('yyyy-MM-dd'))..." -ForegroundColor Cyan
}

process {
    foreach ($server in $ComputerName) {
        Write-Host "  Scanning $server..." -ForegroundColor Gray

        try {
            $certs = Invoke-Command -ComputerName $server -ScriptBlock {
                param($cutoff, $includeExpired)
                $now = Get-Date
                Get-ChildItem Cert:\LocalMachine\My | Where-Object {
                    ($_.NotAfter -lt $cutoff -and $_.NotAfter -gt $now) -or
                    ($includeExpired -and $_.NotAfter -lt $now)
                } | Select-Object Subject, Issuer, Thumbprint, NotBefore, NotAfter,
                    @{N='DaysRemaining'; E={[math]::Floor(($_.NotAfter - $now).TotalDays)}}
            } -ArgumentList $cutoffDate, $IncludeExpired.IsPresent -ErrorAction Stop

            if ($certs) {
                foreach ($cert in $certs) {
                    $status = if ($cert.DaysRemaining -lt 0) { 'Expired' }
                              elseif ($cert.DaysRemaining -le 7) { 'Critical' }
                              elseif ($cert.DaysRemaining -le 14) { 'Warning' }
                              else { 'Expiring' }

                    $results += [PSCustomObject]@{
                        ComputerName  = $server
                        Subject       = $cert.Subject
                        Issuer        = $cert.Issuer
                        Thumbprint    = $cert.Thumbprint
                        ExpiryDate    = $cert.NotAfter.ToString('yyyy-MM-dd')
                        DaysRemaining = $cert.DaysRemaining
                        Status        = $status
                    }
                }
                Write-Host "    Found $($certs.Count) certificate(s)" -ForegroundColor Yellow
            } else {
                Write-Host "    No expiring certificates" -ForegroundColor Green
            }
        } catch {
            Write-Warning "    Failed to scan $server : $_"
        }
    }
}

end {
    if ($results.Count -gt 0) {
        Write-Host "`nExpiring Certificates Report:" -ForegroundColor Cyan
        $results | Sort-Object DaysRemaining | Format-Table ComputerName, Status, DaysRemaining, ExpiryDate, Subject -AutoSize
    } else {
        Write-Host "`nNo expiring certificates found." -ForegroundColor Green
    }
    return $results
}
