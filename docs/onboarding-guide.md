# Onboarding Guide

Welcome to the DevOps & SRE Operations Toolkit. This guide helps new team members get productive quickly.

## Prerequisites

- **PowerShell 7+** — [Install](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell)
- **Azure CLI** — [Install](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- **Azure Bicep** — Included with Azure CLI 2.20+
- **Git** — [Install](https://git-scm.com/downloads)
- **ImportExcel module** — `Install-Module ImportExcel -Scope CurrentUser`

## Repository Layout

| Folder | What's Here | When to Use |
|---|---|---|
| `automation/` | PowerShell operational scripts | Day-to-day server, cert, IIS, and deployment tasks |
| `pipelines/` | CI/CD pipeline templates | Setting up new build/deploy pipelines |
| `infra/` | Bicep IaC modules | Provisioning or modifying Azure resources |
| `monitoring/` | Alert rules, dashboards, KQL queries | Setting up monitoring or investigating incidents |
| `security/` | TLS audit, compliance, secret rotation | Security reviews and secret management |
| `docs/` | Architecture, job duties mapping | Understanding the system and onboarding |

## First-Day Tasks

### 1. Clone and explore

```bash
git clone https://github.com/Harshithj88/devops-sre-operations-toolkit.git
cd devops-sre-operations-toolkit
```

### 2. Verify PowerShell modules

```powershell
Install-Module ImportExcel -Scope CurrentUser
Import-Module ImportExcel
```

### 3. Run a health check

```powershell
.\automation\monitoring\Test-EndpointHealth.ps1 -Url "https://your-app.com/health"
```

### 4. Review architecture

Read [architecture.md](architecture.md) to understand the environment model and component layers.

### 5. Understand the job duties mapping

Read [job-duties-mapping.md](job-duties-mapping.md) to see how each artifact maps to a DevOps/SRE responsibility.

## Key Concepts

- **Four-stage promotion**: DV1 → QA1 → SG1 → RPRD
- **Health-gated deployments**: Every deploy validates health before proceeding
- **IaC-first**: Infrastructure changes go through Bicep, never manual portal clicks
- **Secrets in Key Vault**: Never in code, config files, or pipeline variables
