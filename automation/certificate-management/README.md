# Certificate Management

PowerShell scripts for SSL/TLS certificate lifecycle management across Windows servers.

## Scripts

| Script | Description |
|--------|-------------|
| `Get-ExpiringCertificates.ps1` | Scans servers for certificates expiring within a configurable threshold. Reports status (Critical/Warning/Expiring/Expired) with structured output. |
| `Install-Certificate.ps1` | Imports a PFX certificate on a remote server and optionally binds it to an IIS HTTPS site. Supports `-WhatIf`. |

## Usage

```powershell
# Find certificates expiring within 60 days
.\Get-ExpiringCertificates.ps1 -ComputerName "WEB-01","WEB-02" -DaysUntilExpiry 60

# Install and bind a certificate
$pwd = Read-Host -AsSecureString -Prompt "PFX Password"
.\Install-Certificate.ps1 -ComputerName "WEB-01" -PfxPath ".\wildcard.pfx" -PfxPassword $pwd -IISSiteName "Default Web Site"
```

## Tests

Pester tests are located in `../../tests/certificate-management/`.
