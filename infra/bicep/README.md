# Infrastructure (Bicep)

Modular Bicep templates for provisioning the operations toolkit's supporting Azure infrastructure across `dev` and `prod` environments.

## Layout

```
infra/bicep/
├── main.bicep              # Orchestrates all modules (resource-group scope)
├── params/                 # Per-environment parameter files
│   ├── dev.bicepparam
│   └── prod.bicepparam
└── modules/
    ├── log-analytics.bicep     # Log Analytics workspace
    ├── key-vault.bicep         # RBAC-enabled Key Vault + diagnostics
    ├── app-service.bicep       # App Service plan + web app
    ├── sql-database.bicep      # SQL Server + database
    ├── virtual-network.bicep   # VNet with configurable subnets
    └── container-registry.bicep # ACR with content trust + retention
```

## Deployment

```bash
# Validate
az deployment group validate \
  --resource-group rg-ops-dev \
  --template-file main.bicep \
  --parameters params/dev.bicepparam

# What-if preview
az deployment group what-if \
  --resource-group rg-ops-dev \
  --template-file main.bicep \
  --parameters params/dev.bicepparam

# Deploy
az deployment group create \
  --resource-group rg-ops-dev \
  --template-file main.bicep \
  --parameters params/dev.bicepparam
```

## Modules

### log-analytics.bicep
Central workspace for diagnostics and queries. All other modules send diagnostic settings here.

| Param | Description |
|-------|-------------|
| `name` | Workspace name |
| `location` | Azure region |
| `retentionInDays` | Log retention period |

**Outputs:** `workspaceId`

### key-vault.bicep
RBAC-authorized Key Vault with soft-delete and purge protection enabled.

| Param | Description |
|-------|-------------|
| `name` | Vault name |
| `location` | Azure region |
| `logAnalyticsWorkspaceId` | Workspace for diagnostics |

**Outputs:** `keyVaultName`, `keyVaultUri`, `keyVaultId`

### app-service.bicep
App Service plan and web app with Key Vault reference support and diagnostics.

| Param | Description |
|-------|-------------|
| `appName` / `planName` | Resource names |
| `skuName` | Plan SKU (e.g. `B1`, `P1v3`) |
| `keyVaultName` | Vault for app settings references |
| `logAnalyticsWorkspaceId` | Workspace for diagnostics |

**Outputs:** `defaultHostName`

### sql-database.bicep
SQL Server and database with auditing routed to Log Analytics.

| Param | Description |
|-------|-------------|
| `serverName` / `databaseName` | Resource names |
| `skuName` | Database SKU (e.g. `Basic`, `S1`) |
| `adminLogin` / `adminPassword` | Secure admin credentials |
| `logAnalyticsWorkspaceId` | Workspace for diagnostics |

### virtual-network.bicep
VNet with a configurable list of subnets, optional service endpoints, delegations, and diagnostics.

| Param | Description |
|-------|-------------|
| `name` | VNet name |
| `addressPrefixes` | CIDR blocks |
| `subnets` | Array of `{ name, addressPrefix, ... }` |
| `logAnalyticsWorkspaceId` | Optional workspace for diagnostics |

**Outputs:** `vnetId`, `vnetName`, `subnetIds`

### container-registry.bicep
Azure Container Registry with security-hardened defaults (admin disabled, private access, content trust, quarantine, retention).

| Param | Description |
|-------|-------------|
| `name` | Registry name (5–50 alphanumeric) |
| `sku` | `Basic`, `Standard`, or `Premium` |
| `publicNetworkAccess` | Allow public access (default false) |
| `retentionDays` | Untagged manifest retention |
| `logAnalyticsWorkspaceId` | Optional workspace for diagnostics |

**Outputs:** `registryId`, `registryName`, `loginServer`

## Conventions

- **Resource-group scope** — `main.bicep` targets a resource group; create it first
- **Diagnostics everywhere** — modules accept a `logAnalyticsWorkspaceId` to centralize logs
- **Secure by default** — Key Vault uses RBAC; ACR disables admin and public access
- **Environment-driven SKUs** — `main.bicep` selects SKUs based on the `environment` parameter
