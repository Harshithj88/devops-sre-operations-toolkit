# Server Management

PowerShell scripts for Windows server operations including health checks, inventory, and rolling restarts.

## Scripts

| Script | Description |
|--------|-------------|
| `Test-ServerHealth.ps1` | Multi-point health check (connectivity, disk, certs, IIS) with structured output per server. |
| `Get-ServerInventory.ps1` | Generates server-to-application inventory with Excel/CSV export support. |
| `Invoke-RollingRestart.ps1` | Rolling IIS restart with health-check gates, drain delay, and global timeout. Supports `-WhatIf`. |

## Usage

```powershell
# Server health check
.\Test-ServerHealth.ps1 -ComputerName "WEB-01","WEB-02"

# Rolling restart with 30-minute timeout and 10-second drain
.\Invoke-RollingRestart.ps1 -ComputerName "WEB-01","WEB-02","WEB-03" -TimeoutMinutes 30 -DrainDelaySeconds 10

# Export server inventory
.\Get-ServerInventory.ps1 -ComputerName "WEB-01" -OutputPath ".\inventory.xlsx"
```

## Tests

Pester tests are located in `../../tests/server-management/`.
