<#
.SYNOPSIS
    Rotates secrets in Azure Key Vault with zero-downtime.

.DESCRIPTION
    Generates a new secret value, stores it as a new version in Key Vault,
    and optionally updates application settings to reference the latest version.

.PARAMETER VaultName
    Azure Key Vault name.

.PARAMETER SecretName
    Name of the secret to rotate.

.PARAMETER GeneratePassword
    Auto-generate a cryptographically random password.

.PARAMETER Length
    Length of generated password. Defaults to 32.

.PARAMETER NewValue
    Explicit new secret value. Mutually exclusive with GeneratePassword.

.PARAMETER UpdateAppService
    Optional App Service name to restart after rotation.

.EXAMPLE
    .\Invoke-SecretRotation.ps1 -VaultName "kv-ops-prod" -SecretName "DbConnectionString" -NewValue "Server=..."

.EXAMPLE
    .\Invoke-SecretRotation.ps1 -VaultName "kv-ops-prod" -SecretName "ApiKey" -GeneratePassword -Length 64
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$VaultName,

    [Parameter(Mandatory)]
    [string]$SecretName,

    [Parameter(ParameterSetName = 'Generate')]
    [switch]$GeneratePassword,

    [Parameter(ParameterSetName = 'Generate')]
    [int]$Length = 32,

    [Parameter(ParameterSetName = 'Explicit', Mandatory)]
    [SecureString]$NewValue,

    [Parameter()]
    [string]$UpdateAppService
)

function New-RandomPassword {
    param([int]$Length)
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*'
    $bytes = New-Object byte[] $Length
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    $password = -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
    return $password
}

# Resolve the new secret value
if ($GeneratePassword) {
    $plainText = New-RandomPassword -Length $Length
    $secureValue = ConvertTo-SecureString $plainText -AsPlainText -Force
    Write-Host "Generated new $Length-character password." -ForegroundColor Cyan
} else {
    $secureValue = $NewValue
}

if ($PSCmdlet.ShouldProcess("$VaultName/$SecretName", "Rotate secret")) {
    # Get current version for audit trail
    $current = Get-AzKeyVaultSecret -VaultName $VaultName -Name $SecretName -ErrorAction SilentlyContinue
    $previousVersion = if ($current) { $current.Version } else { '(none)' }

    # Set new version
    Write-Host "Setting new version of '$SecretName' in vault '$VaultName'..." -ForegroundColor Cyan
    $newSecret = Set-AzKeyVaultSecret -VaultName $VaultName -Name $SecretName -SecretValue $secureValue -ErrorAction Stop

    Write-Host "Secret rotated successfully." -ForegroundColor Green
    Write-Host "  Previous version: $previousVersion" -ForegroundColor Gray
    Write-Host "  New version:      $($newSecret.Version)" -ForegroundColor Gray
    Write-Host "  Secret ID:        $($newSecret.Id)" -ForegroundColor Gray

    # Optionally restart App Service to pick up new secret
    if ($UpdateAppService) {
        Write-Host "Restarting App Service '$UpdateAppService' to apply new secret..." -ForegroundColor Cyan
        Restart-AzWebApp -Name $UpdateAppService -ResourceGroupName (
            (Get-AzWebApp -Name $UpdateAppService).ResourceGroup
        ) -ErrorAction Stop
        Write-Host "App Service restarted." -ForegroundColor Green
    }
}
