<#
.SYNOPSIS
    Installs a PFX certificate on a remote server and optionally binds it to an IIS site.

.DESCRIPTION
    Copies a PFX file to the target server, imports it into the LocalMachine\My store,
    and optionally updates an IIS HTTPS binding to use the new certificate.

.PARAMETER ComputerName
    Target server name.

.PARAMETER PfxPath
    Local path to the PFX certificate file.

.PARAMETER PfxPassword
    SecureString password for the PFX file.

.PARAMETER IISSiteName
    Optional. IIS site name to bind the certificate to.

.PARAMETER Port
    HTTPS port for the IIS binding. Defaults to 443.

.EXAMPLE
    $pwd = Read-Host -AsSecureString -Prompt "PFX Password"
    .\Install-Certificate.ps1 -ComputerName "WEB-01" -PfxPath ".\wildcard.pfx" -PfxPassword $pwd -IISSiteName "Default Web Site"
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$ComputerName,

    [Parameter(Mandatory)]
    [string]$PfxPath,

    [Parameter(Mandatory)]
    [SecureString]$PfxPassword,

    [Parameter()]
    [string]$IISSiteName,

    [Parameter()]
    [int]$Port = 443
)

if (-not (Test-Path $PfxPath)) {
    Write-Error "PFX file not found: $PfxPath"
    return
}

$pfxFileName = Split-Path $PfxPath -Leaf
$remoteTempPath = "\\$ComputerName\C$\Windows\Temp\$pfxFileName"

if ($PSCmdlet.ShouldProcess($ComputerName, "Install certificate from $pfxFileName")) {
    # Copy PFX to remote server
    Write-Host "Copying PFX to $ComputerName..." -ForegroundColor Cyan
    Copy-Item -Path $PfxPath -Destination $remoteTempPath -Force -ErrorAction Stop

    # Import certificate
    Write-Host "Importing certificate..." -ForegroundColor Cyan
    $thumbprint = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        param($pfxFile, $password)
        $cert = Import-PfxCertificate -FilePath $pfxFile -CertStoreLocation Cert:\LocalMachine\My -Password $password -ErrorAction Stop
        Remove-Item $pfxFile -Force -ErrorAction SilentlyContinue
        return $cert.Thumbprint
    } -ArgumentList "C:\Windows\Temp\$pfxFileName", $PfxPassword -ErrorAction Stop

    Write-Host "Certificate imported. Thumbprint: $thumbprint" -ForegroundColor Green

    # Bind to IIS site if requested
    if ($IISSiteName) {
        Write-Host "Binding to IIS site '$IISSiteName' on port $Port..." -ForegroundColor Cyan
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            param($siteName, $port, $thumbprint)
            Import-Module WebAdministration

            $binding = Get-WebBinding -Name $siteName -Protocol https -Port $port -ErrorAction SilentlyContinue
            if ($binding) {
                $binding.AddSslCertificate($thumbprint, 'My')
                Write-Host "  Binding updated."
            } else {
                New-WebBinding -Name $siteName -Protocol https -Port $port -IPAddress '*'
                $newBinding = Get-WebBinding -Name $siteName -Protocol https -Port $port
                $newBinding.AddSslCertificate($thumbprint, 'My')
                Write-Host "  Binding created."
            }
        } -ArgumentList $IISSiteName, $Port, $thumbprint -ErrorAction Stop

        Write-Host "IIS binding complete." -ForegroundColor Green
    }
}
