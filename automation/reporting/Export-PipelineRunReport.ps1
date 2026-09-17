<#
.SYNOPSIS
    Exports Azure DevOps pipeline run history to CSV or JSON for reporting.

.DESCRIPTION
    Queries the Azure DevOps REST API for pipeline runs within a date range,
    collects status, duration, and trigger information, and exports a structured
    report. Useful for tracking deployment frequency, failure rates, and lead time.

.PARAMETER Organization
    Azure DevOps organization name.

.PARAMETER Project
    Azure DevOps project name.

.PARAMETER PipelineId
    Optional. Filter to a specific pipeline by ID. If omitted, queries all pipelines.

.PARAMETER FromDate
    Start date for the report window. Defaults to 30 days ago.

.PARAMETER ToDate
    End date for the report window. Defaults to today.

.PARAMETER OutputPath
    Path for the output file. Extension determines format (.csv or .json).
    Defaults to PipelineRunReport.csv in the current directory.

.PARAMETER PersonalAccessToken
    Azure DevOps PAT with Build (read) permissions. If not provided, uses
    the AZURE_DEVOPS_PAT environment variable.

.EXAMPLE
    .\Export-PipelineRunReport.ps1 -Organization "myorg" -Project "myproject" -FromDate "2026-01-01"

.EXAMPLE
    .\Export-PipelineRunReport.ps1 -Organization "myorg" -Project "myproject" -PipelineId 42 -OutputPath ".\report.json"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Organization,

    [Parameter(Mandatory)]
    [string]$Project,

    [Parameter()]
    [int]$PipelineId,

    [Parameter()]
    [datetime]$FromDate = (Get-Date).AddDays(-30),

    [Parameter()]
    [datetime]$ToDate = (Get-Date),

    [Parameter()]
    [string]$OutputPath = '.\PipelineRunReport.csv',

    [Parameter()]
    [string]$PersonalAccessToken = $env:AZURE_DEVOPS_PAT
)

if (-not $PersonalAccessToken) {
    Write-Error "No PAT provided. Set -PersonalAccessToken or the AZURE_DEVOPS_PAT environment variable."
    return
}

# Build auth header
$base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PersonalAccessToken"))
$headers = @{
    Authorization = "Basic $base64Auth"
    'Content-Type' = 'application/json'
}

$baseUrl = "https://dev.azure.com/$Organization/$Project/_apis"
$apiVersion = "api-version=7.1"

# Get pipeline runs
function Get-PipelineRuns {
    param([string]$Url, [hashtable]$Headers)

    $allRuns = @()
    $continuationToken = $null

    do {
        $requestUrl = $Url
        if ($continuationToken) {
            $requestUrl += "&continuationToken=$continuationToken"
        }

        try {
            $response = Invoke-WebRequest -Uri $requestUrl -Headers $Headers -Method Get -UseBasicParsing -ErrorAction Stop
            $data = $response.Content | ConvertFrom-Json
            $allRuns += $data.value
            $continuationToken = $response.Headers['x-ms-continuationtoken']
        } catch {
            Write-Warning "API request failed: $_"
            $continuationToken = $null
        }
    } while ($continuationToken)

    return $allRuns
}

Write-Host "Querying pipeline runs from $($FromDate.ToString('yyyy-MM-dd')) to $($ToDate.ToString('yyyy-MM-dd'))..." -ForegroundColor Cyan

$minTime = $FromDate.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$maxTime = $ToDate.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

if ($PipelineId) {
    $url = "$baseUrl/pipelines/$PipelineId/runs?$apiVersion&minCreatedDate=$minTime&maxCreatedDate=$maxTime"
} else {
    $url = "$baseUrl/build/builds?$apiVersion&minTime=$minTime&maxTime=$maxTime&`$top=5000"
}

$runs = Get-PipelineRuns -Url $url -Headers $headers

if (-not $runs -or $runs.Count -eq 0) {
    Write-Host "No pipeline runs found in the specified date range." -ForegroundColor Yellow
    return
}

Write-Host "Found $($runs.Count) pipeline run(s). Processing..." -ForegroundColor Green

# Build structured report
$report = foreach ($run in $runs) {
    $startTime = if ($run.startTime) { [datetime]$run.startTime } else { $null }
    $finishTime = if ($run.finishTime) { [datetime]$run.finishTime } else { $null }
    $durationMin = if ($startTime -and $finishTime) {
        [math]::Round(($finishTime - $startTime).TotalMinutes, 2)
    } else { $null }

    [PSCustomObject]@{
        RunId          = $run.id
        PipelineName   = $run.definition.name
        PipelineId     = $run.definition.id
        Status         = $run.status
        Result         = $run.result
        SourceBranch   = $run.sourceBranch
        SourceVersion  = if ($run.sourceVersion) { $run.sourceVersion.Substring(0, [Math]::Min(8, $run.sourceVersion.Length)) } else { 'N/A' }
        RequestedBy    = $run.requestedFor.displayName
        Reason         = $run.reason
        StartTime      = if ($startTime) { $startTime.ToString('yyyy-MM-dd HH:mm:ss') } else { 'N/A' }
        FinishTime     = if ($finishTime) { $finishTime.ToString('yyyy-MM-dd HH:mm:ss') } else { 'N/A' }
        DurationMinutes = $durationMin
        QueueTime      = if ($run.queueTime) { ([datetime]$run.queueTime).ToString('yyyy-MM-dd HH:mm:ss') } else { 'N/A' }
    }
}

# Export
$outputDir = Split-Path $OutputPath -Parent
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$extension = [IO.Path]::GetExtension($OutputPath).ToLower()
if ($extension -eq '.json') {
    $report | ConvertTo-Json -Depth 3 | Set-Content -Path $OutputPath -Encoding UTF8
} else {
    $report | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
}

Write-Host "Report exported to: $OutputPath" -ForegroundColor Green

# Summary statistics
$succeeded = ($report | Where-Object { $_.Result -eq 'succeeded' }).Count
$failed = ($report | Where-Object { $_.Result -eq 'failed' }).Count
$canceled = ($report | Where-Object { $_.Result -eq 'canceled' }).Count
$avgDuration = ($report | Where-Object { $_.DurationMinutes } | Measure-Object -Property DurationMinutes -Average).Average

Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "  Total runs:      $($report.Count)"
Write-Host "  Succeeded:       $succeeded" -ForegroundColor Green
Write-Host "  Failed:          $failed" -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'Green' })
Write-Host "  Canceled:        $canceled" -ForegroundColor Yellow
Write-Host "  Avg duration:    $([math]::Round($avgDuration, 1)) min"
Write-Host "  Success rate:    $([math]::Round(($succeeded / $report.Count) * 100, 1))%"

return $report
