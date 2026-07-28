<#
.SYNOPSIS
    Reports IIS application pool status across a fleet of servers.

.DESCRIPTION
    Queries each server for all IIS application pools and reports their state
    (Started, Stopped, etc.), managed runtime version, and process ID.

.PARAMETER ComputerName
    One or more server names to query.

.PARAMETER AppPoolName
    Optional filter for a specific app pool name. Supports wildcards.

.EXAMPLE
    .\Get-AppPoolStatus.ps1 -ComputerName "WEB-01","WEB-02"

.EXAMPLE
    .\Get-AppPoolStatus.ps1 -ComputerName "WEB-01" -AppPoolName "MyApp*"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string[]]$ComputerName,

    [Parameter()]
    [string]$AppPoolName = '*'
)

begin {
    $results = @()
}

process {
    foreach ($server in $ComputerName) {
        Write-Host "Querying $server..." -ForegroundColor Cyan

        try {
            $pools = Invoke-Command -ComputerName $server -ScriptBlock {
                param($filter)
                Import-Module WebAdministration
                Get-ChildItem IIS:\AppPools | Where-Object Name -like $filter | ForEach-Object {
                    $workerProcesses = $_ | Get-ChildItem -ErrorAction SilentlyContinue
                    [PSCustomObject]@{
                        Name              = $_.Name
                        State             = $_.State
                        ManagedRuntime    = $_.managedRuntimeVersion
                        StartMode         = $_.startMode
                        PipelineMode      = $_.managedPipelineMode
                        ProcessId         = ($workerProcesses.processId -join ',')
                        AutoStart         = $_.autoStart
                    }
                }
            } -ArgumentList $AppPoolName -ErrorAction Stop

            foreach ($pool in $pools) {
                $results += [PSCustomObject]@{
                    ComputerName   = $server
                    AppPoolName    = $pool.Name
                    State          = $pool.State
                    ManagedRuntime = $pool.ManagedRuntime
                    StartMode      = $pool.StartMode
                    PipelineMode   = $pool.PipelineMode
                    ProcessId      = $pool.ProcessId
                    AutoStart      = $pool.AutoStart
                }
            }

            $running = ($pools | Where-Object State -eq 'Started').Count
            $stopped = ($pools | Where-Object State -ne 'Started').Count
            Write-Host "  $running running, $stopped stopped" -ForegroundColor $(if ($stopped -gt 0) { 'Yellow' } else { 'Green' })

        } catch {
            Write-Warning "  Failed to query $server : $_"
        }
    }
}

end {
    $results | Format-Table ComputerName, AppPoolName, State, ManagedRuntime, StartMode, ProcessId -AutoSize
    return $results
}
