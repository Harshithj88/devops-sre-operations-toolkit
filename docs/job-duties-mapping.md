# Job Duties Mapping

Every artifact in this repository maps to a specific DevOps & SRE job duty.

## Infrastructure Provisioning & Management

| Artifact | Description |
|---|---|
| `infra/bicep/main.bicep` | Orchestrator for Azure resource provisioning |
| `infra/bicep/modules/app-service.bicep` | App Service with deployment slots |
| `infra/bicep/modules/key-vault.bicep` | Key Vault with RBAC and diagnostics |
| `infra/bicep/modules/sql-database.bicep` | Azure SQL with auditing |
| `infra/bicep/modules/log-analytics.bicep` | Centralized logging workspace |
| `pipelines/github-actions/deploy-infra.yml` | Automated IaC deployment with OIDC |

## CI/CD Pipeline Design & Automation

| Artifact | Description |
|---|---|
| `pipelines/azure-devops/build-dotnet.yml` | .NET build, test, and artifact publishing |
| `pipelines/azure-devops/deploy-iis.yml` | Multi-stage IIS deploy with approval gates |
| `pipelines/azure-devops/deploy-kubernetes.yml` | AKS Helm deploy with canary strategy |
| `pipelines/github-actions/build-container.yml` | Container build, scan, and push to ACR |
| `pipelines/github-actions/deploy-infra.yml` | Bicep deployment with validation |

## Server & Application Fleet Management

| Artifact | Description |
|---|---|
| `automation/server-management/Get-ServerInventory.ps1` | Fleet inventory and OS reporting |
| `automation/server-management/Invoke-RollingRestart.ps1` | Zero-downtime rolling IIS restarts |
| `automation/server-management/Test-ServerHealth.ps1` | Multi-point server health validation |
| `automation/iis-management/Get-AppPoolStatus.ps1` | App pool state reporting |
| `automation/iis-management/Invoke-AppPoolRecycle.ps1` | Safe app pool recycling with drain |

## Release & Deployment Orchestration

| Artifact | Description |
|---|---|
| `automation/deployment/Deploy-Application.ps1` | Scripted deploy with backup and rollback |
| `automation/deployment/Invoke-HealthCheckAfterDeploy.ps1` | Post-deploy smoke tests |
| `pipelines/azure-devops/deploy-iis.yml` | Multi-environment pipeline with approvals |

## Monitoring, Alerting & Incident Response

| Artifact | Description |
|---|---|
| `automation/monitoring/Test-EndpointHealth.ps1` | HTTP endpoint health checker |
| `automation/monitoring/Get-DiskSpaceReport.ps1` | Disk utilization with threshold alerts |
| `monitoring/alert-rules/availability-alerts.bicep` | Availability and 5xx alert rules |
| `monitoring/alert-rules/performance-alerts.bicep` | CPU and memory threshold alerts |
| `monitoring/dashboards/operations-overview.json` | Azure Portal operations dashboard |
| `monitoring/log-queries/error-analysis.kql` | Error investigation queries |
| `monitoring/log-queries/performance-baseline.kql` | Performance trending and percentiles |
| `monitoring/log-queries/deployment-correlation.kql` | Deploy-to-error correlation |

## Certificate & Secret Management

| Artifact | Description |
|---|---|
| `automation/certificate-management/Get-ExpiringCertificates.ps1` | Fleet cert expiry scanning |
| `automation/certificate-management/Install-Certificate.ps1` | Remote cert install with IIS binding |
| `security/Invoke-SecretRotation.ps1` | Key Vault secret rotation |

## Security & Compliance Automation

| Artifact | Description |
|---|---|
| `security/Invoke-TlsAudit.ps1` | TLS version and cipher audit |
| `security/Test-ComplianceBaseline.ps1` | Security baseline validation |
| `security/Invoke-SecretRotation.ps1` | Zero-downtime secret rotation |
