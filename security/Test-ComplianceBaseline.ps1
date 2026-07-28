<#
.SYNOPSIS
    Validates servers against a security compliance baseline.

.DESCRIPTION
    Checks each server for required services, firewall state, Windows Update status,
    and security configuration. Returns a pass/fail report per check.

.PARAMETER ComputerName
    One or more server names to validate.

.EXAMPLE
    .\Test-ComplianceBaseline.ps1 -ComputerName "WEB-01","APP-01"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
    [string[]]$ComputerName
)

$requiredServices = @('W3SVC', 'WinRM', 'EventLog', 'MpsSvc')

begin {
    $results = @()
}

process {
    foreach ($server in $ComputerName) {
        Write-Host "Validating $server..." -ForegroundColor Cyan

        $checks = @()

        try {
            # 1. Required services
            $services = Invoke-Command -ComputerName $server -ScriptBlock {
                param($required)
                foreach ($svc in $required) {
                    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
                    [PSCustomObject]@{
                        Name   = $svc
                        Status = if ($s) { $s.Status.ToString() } else { 'NotFound' }
                    }
                }
            } -ArgumentList (, $requiredServices) -ErrorAction Stop

            foreach ($svc in $services) {
                $checks += [PSCustomObject]@{
                    ComputerName = $server
                    Check        = "Service: $($svc.Name)"
                    Result       = if ($svc.Status -eq 'Running') { 'Pass' } else { 'Fail' }
                    Detail       = $svc.Status
                }
            }

            # 2. Windows Firewall
            $firewall = Invoke-Command -ComputerName $server -ScriptBlock {
                Get-NetFirewallProfile | Select-Object Name, Enabled
            } -ErrorAction Stop

            foreach ($profile in $firewall) {
                $checks += [PSCustomObject]@{
                    ComputerName = $server
                    Check        = "Firewall: $($profile.Name)"
                    Result       = if ($profile.Enabled) { 'Pass' } else { 'Fail' }
                    Detail       = if ($profile.Enabled) { 'Enabled' } else { 'Disabled' }
                }
            }

            # 3. TLS 1.0/1.1 disabled
            $tlsCheck = Invoke-Command -ComputerName $server -ScriptBlock {
                $tls10 = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server' -Name 'Enabled' -ErrorAction SilentlyContinue
                $tls11 = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server' -Name 'Enabled' -ErrorAction SilentlyContinue
                [PSCustomObject]@{
                    TLS10Enabled = if ($tls10) { $tls10.Enabled -ne 0 } else { $true }
                    TLS11Enabled = if ($tls11) { $tls11.Enabled -ne 0 } else { $true }
                }
            } -ErrorAction Stop

            $checks += [PSCustomObject]@{
                ComputerName = $server
                Check        = 'TLS 1.0 Disabled'
                Result       = if (-not $tlsCheck.TLS10Enabled) { 'Pass' } else { 'Fail' }
                Detail       = if ($tlsCheck.TLS10Enabled) { 'Still enabled' } else { 'Disabled' }
            }
            $checks += [PSCustomObject]@{
                ComputerName = $server
                Check        = 'TLS 1.1 Disabled'
                Result       = if (-not $tlsCheck.TLS11Enabled) { 'Pass' } else { 'Fail' }
                Detail       = if ($tlsCheck.TLS11Enabled) { 'Still enabled' } else { 'Disabled' }
            }

            # 4. Pending reboot check
            $pendingReboot = Invoke-Command -ComputerName $server -ScriptBlock {
                Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
            } -ErrorAction Stop

            $checks += [PSCustomObject]@{
                ComputerName = $server
                Check        = 'No Pending Reboot'
                Result       = if (-not $pendingReboot) { 'Pass' } else { 'Fail' }
                Detail       = if ($pendingReboot) { 'Reboot pending' } else { 'Clean' }
            }

        } catch {
            $checks += [PSCustomObject]@{
                ComputerName = $server
                Check        = 'Connectivity'
                Result       = 'Fail'
                Detail       = $_.Exception.Message
            }
        }

        $results += $checks

        $failCount = ($checks | Where-Object Result -eq 'Fail').Count
        $color = if ($failCount -eq 0) { 'Green' } else { 'Yellow' }
        Write-Host "  $($checks.Count) checks, $failCount failure(s)" -ForegroundColor $color
    }
}

end {
    Write-Host "`nCompliance Report:" -ForegroundColor Cyan
    $results | Format-Table ComputerName, Check, Result, Detail -AutoSize
    return $results
}
