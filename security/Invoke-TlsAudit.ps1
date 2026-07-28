<#
.SYNOPSIS
    Audits TLS versions and cipher suites on a fleet of servers.

.DESCRIPTION
    Connects to each server's HTTPS endpoint and reports the negotiated TLS version
    and cipher suite. Flags servers using TLS 1.0 or 1.1 as non-compliant.

.PARAMETER ComputerName
    One or more server names to audit.

.PARAMETER Port
    HTTPS port to test. Defaults to 443.

.EXAMPLE
    .\Invoke-TlsAudit.ps1 -ComputerName "WEB-01","WEB-02","API-01"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
    [string[]]$ComputerName,

    [Parameter()]
    [int]$Port = 443
)

begin {
    $results = @()
}

process {
    foreach ($server in $ComputerName) {
        Write-Host "Auditing $server`:$Port..." -ForegroundColor Cyan

        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $tcpClient.Connect($server, $Port)
            $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false)
            $sslStream.AuthenticateAsClient($server)

            $tlsVersion = $sslStream.SslProtocol.ToString()
            $cipher = $sslStream.CipherAlgorithm.ToString()
            $keyExchange = $sslStream.KeyExchangeAlgorithm.ToString()
            $hashAlg = $sslStream.HashAlgorithm.ToString()

            $compliant = $tlsVersion -match 'Tls12|Tls13'

            $results += [PSCustomObject]@{
                ComputerName  = $server
                Port          = $Port
                TlsVersion    = $tlsVersion
                CipherSuite   = $cipher
                KeyExchange   = $keyExchange
                HashAlgorithm = $hashAlg
                Compliant     = $compliant
                Status        = if ($compliant) { 'OK' } else { 'NON-COMPLIANT' }
            }

            $sslStream.Close()
            $tcpClient.Close()

            $color = if ($compliant) { 'Green' } else { 'Red' }
            Write-Host "  TLS: $tlsVersion — $( if ($compliant) {'Compliant'} else {'NON-COMPLIANT'} )" -ForegroundColor $color
        } catch {
            $results += [PSCustomObject]@{
                ComputerName  = $server
                Port          = $Port
                TlsVersion    = 'Error'
                CipherSuite   = ''
                KeyExchange   = ''
                HashAlgorithm = ''
                Compliant     = $false
                Status        = "Error: $($_.Exception.Message)"
            }
            Write-Warning "  Failed: $_"
        }
    }
}

end {
    Write-Host "`nTLS Audit Summary:" -ForegroundColor Cyan
    $results | Format-Table ComputerName, TlsVersion, CipherSuite, Compliant, Status -AutoSize

    $nonCompliant = ($results | Where-Object { -not $_.Compliant }).Count
    if ($nonCompliant -gt 0) {
        Write-Warning "$nonCompliant server(s) are non-compliant (TLS < 1.2)."
    }
    return $results
}
