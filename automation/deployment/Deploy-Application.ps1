<#
.SYNOPSIS
    Scripted application deployment: stop site, copy artifacts, start site, verify.

.DESCRIPTION
    Deploys an application to a remote IIS server by stopping the site, copying
    build artifacts to the deployment path, starting the site, and running a
    post-deploy health check.

.PARAMETER ComputerName
    Target server name.

.PARAMETER SiteName
    IIS site name to stop/start during deployment.

.PARAMETER ArtifactPath
    Local path to the build artifacts to deploy.

.PARAMETER DeployPath
    Remote deployment directory (e.g., C:\Apps\MyApp).

.PARAMETER HealthUrl
    Optional URL for post-deploy health check.

.PARAMETER BackupFirst
    Create a backup of the current deployment before overwriting.

.EXAMPLE
    .\Deploy-Application.ps1 -ComputerName "WEB-01" -SiteName "MyApp" `
        -ArtifactPath ".\artifacts" -DeployPath "C:\Apps\MyApp" `
        -HealthUrl "https://WEB-01/health" -BackupFirst
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$ComputerName,

    [Parameter(Mandatory)]
    [string]$SiteName,

    [Parameter(Mandatory)]
    [string]$ArtifactPath,

    [Parameter(Mandatory)]
    [string]$DeployPath,

    [Parameter()]
    [string]$HealthUrl,

    [Parameter()]
    [switch]$BackupFirst
)

$remoteDeployPath = "\\$ComputerName\$($DeployPath -replace ':', '$')"
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

if (-not (Test-Path $ArtifactPath)) {
    Write-Error "Artifact path not found: $ArtifactPath"
    return
}

if ($PSCmdlet.ShouldProcess($ComputerName, "Deploy $SiteName")) {

    # 1. Backup current deployment
    if ($BackupFirst) {
        $backupPath = "${remoteDeployPath}_backup_$timestamp"
        Write-Host "[1/5] Backing up current deployment..." -ForegroundColor Cyan
        if (Test-Path $remoteDeployPath) {
            Copy-Item -Path $remoteDeployPath -Destination $backupPath -Recurse -Force
            Write-Host "  Backup created: $backupPath" -ForegroundColor Green
        } else {
            Write-Host "  No existing deployment to backup." -ForegroundColor Gray
        }
    } else {
        Write-Host "[1/5] Backup skipped." -ForegroundColor Gray
    }

    # 2. Stop IIS site
    Write-Host "[2/5] Stopping IIS site '$SiteName'..." -ForegroundColor Cyan
    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        param($site)
        Import-Module WebAdministration
        Stop-Website -Name $site -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
    } -ArgumentList $SiteName -ErrorAction Stop
    Write-Host "  Site stopped." -ForegroundColor Green

    # 3. Copy artifacts
    Write-Host "[3/5] Copying artifacts to $remoteDeployPath..." -ForegroundColor Cyan
    if (-not (Test-Path $remoteDeployPath)) {
        New-Item -ItemType Directory -Path $remoteDeployPath -Force | Out-Null
    }
    Copy-Item -Path "$ArtifactPath\*" -Destination $remoteDeployPath -Recurse -Force
    Write-Host "  Artifacts deployed." -ForegroundColor Green

    # 4. Start IIS site
    Write-Host "[4/5] Starting IIS site '$SiteName'..." -ForegroundColor Cyan
    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        param($site)
        Import-Module WebAdministration
        Start-Website -Name $site -ErrorAction Stop
    } -ArgumentList $SiteName -ErrorAction Stop
    Write-Host "  Site started." -ForegroundColor Green

    # 5. Health check
    if ($HealthUrl) {
        Write-Host "[5/5] Running post-deploy health check..." -ForegroundColor Cyan
        Start-Sleep -Seconds 5
        $retries = 3
        $healthy = $false
        for ($i = 1; $i -le $retries; $i++) {
            try {
                $resp = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
                if ($resp.StatusCode -eq 200) {
                    Write-Host "  Health check passed." -ForegroundColor Green
                    $healthy = $true
                    break
                }
            } catch {
                Write-Host "  Attempt $i/$retries failed." -ForegroundColor Yellow
                Start-Sleep -Seconds 5
            }
        }
        if (-not $healthy) {
            Write-Warning "Health check failed after $retries attempts. Consider rolling back."
        }
    } else {
        Write-Host "[5/5] No health URL provided, skipping." -ForegroundColor Gray
    }

    Write-Host "`nDeployment complete." -ForegroundColor Green
}
