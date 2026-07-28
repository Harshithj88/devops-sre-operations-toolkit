<#
.SYNOPSIS
    Generates a server-to-application inventory and exports to Excel or CSV.

.DESCRIPTION
    Queries server fleet metadata, maps each server to its associated application
    components, and exports the inventory to a formatted Excel workbook.

.PARAMETER ComputerName
    One or more server names to query. If omitted, queries by Environment.

.PARAMETER Environment
    One or more environment names (e.g., DV1, QA1, SG1, RPRD).

.PARAMETER OutputPath
    Path for the output file. Defaults to Desktop with timestamp.

.PARAMETER Format
    Output format: Excel or CSV. Defaults to Excel.

.EXAMPLE
    .\Get-ServerInventory.ps1 -Environment RPRD

.EXAMPLE
    .\Get-ServerInventory.ps1 -ComputerName "WEB-01","WEB-02" -Format CSV
#>
[CmdletBinding(DefaultParameterSetName = 'ByEnvironment')]
param(
    [Parameter(ParameterSetName = 'ByName', Position = 0)]
    [string[]]$ComputerName,

    [Parameter(ParameterSetName = 'ByEnvironment')]
    [string[]]$Environment = @('DV1', 'QA1', 'SG1', 'RPRD'),

    [Parameter()]
    [string]$OutputPath,

    [Parameter()]
    [ValidateSet('Excel', 'CSV')]
    [string]$Format = 'Excel'
)

#region Prerequisites
if ($Format -eq 'Excel') {
    if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
        Write-Host "Installing ImportExcel module..." -ForegroundColor Yellow
        Install-Module -Name ImportExcel -Scope CurrentUser -Force -ErrorAction Stop
    }
    Import-Module ImportExcel -ErrorAction Stop
}
#endregion

#region Defaults
if (-not $OutputPath) {
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $ext = if ($Format -eq 'Excel') { '.xlsx' } else { '.csv' }
    $OutputPath = Join-Path ([Environment]::GetFolderPath('Desktop')) "ServerInventory_$timestamp$ext"
}
#endregion

#region Query servers
Write-Host "Querying servers..." -ForegroundColor Cyan
$allServers = @()

if ($PSCmdlet.ParameterSetName -eq 'ByName') {
    foreach ($name in $ComputerName) {
        try {
            $srv = Get-CimInstance -ClassName Win32_ComputerSystem -ComputerName $name -ErrorAction Stop
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $name -ErrorAction Stop
            $ip = (Resolve-DnsName $name -ErrorAction SilentlyContinue | Where-Object Type -eq 'A').IPAddress | Select-Object -First 1

            $allServers += [PSCustomObject]@{
                ComputerName = $srv.Name
                IP           = $ip
                Domain       = $srv.Domain
                OS           = $os.Caption
                OSVersion    = $os.Version
                TotalMemoryGB = [math]::Round($srv.TotalPhysicalMemory / 1GB, 1)
                Manufacturer = $srv.Manufacturer
                Model        = $srv.Model
            }
        } catch {
            Write-Warning "Failed to query $name : $_"
        }
    }
} else {
    foreach ($name in $Environment) {
        Write-Host "  Querying $name..." -ForegroundColor Gray
        # Placeholder: replace with your fleet query tool (e.g., Get-LDServer, AD query, CMDB API)
        # Example using Active Directory:
        try {
            $computers = Get-ADComputer -Filter "Name -like '*-$name-*'" -Properties OperatingSystem, IPv4Address -ErrorAction Stop
            foreach ($c in $computers) {
                $allServers += [PSCustomObject]@{
                    ComputerName = $c.Name
                    IP           = $c.IPv4Address
                    Domain       = $c.DistinguishedName -replace '^.*?,DC=', '' -replace ',DC=', '.'
                    OS           = $c.OperatingSystem
                    OSVersion    = ''
                    TotalMemoryGB = ''
                    Manufacturer = ''
                    Model        = ''
                }
            }
            Write-Host "    Found $($computers.Count) server(s)" -ForegroundColor Green
        } catch {
            Write-Warning "    Failed to query $name : $_"
        }
    }
}

if ($allServers.Count -eq 0) {
    Write-Error "No servers found."
    return
}

Write-Host "Total servers: $($allServers.Count)" -ForegroundColor Cyan
#endregion

#region Export
if ($Format -eq 'Excel') {
    if (Test-Path $OutputPath) { Remove-Item $OutputPath -Force }
    $allServers | Export-Excel -Path $OutputPath -WorksheetName 'Server Inventory' `
        -AutoSize -FreezeTopRow -BoldTopRow `
        -TableName 'Inventory' -TableStyle Medium6
} else {
    $allServers | Export-Csv -Path $OutputPath -NoTypeInformation
}

Write-Host "Exported to: $OutputPath" -ForegroundColor Green
#endregion
