@description('Container registry name (globally unique, alphanumeric, 5-50 chars)')
@minLength(5)
@maxLength(50)
param name string

@description('Azure region')
param location string

@description('Registry SKU')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param sku string = 'Premium'

@description('Enable admin user (disable for production; use RBAC/managed identity)')
param adminUserEnabled bool = false

@description('Enable public network access')
param publicNetworkAccess bool = false

@description('Untagged manifest retention in days')
param retentionDays int = 30

@description('Log Analytics workspace ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

@description('Tags to apply')
param tags object = {}

resource registry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: adminUserEnabled
    publicNetworkAccess: publicNetworkAccess ? 'Enabled' : 'Disabled'
    zoneRedundancy: sku == 'Premium' ? 'Enabled' : 'Disabled'
    networkRuleBypassOptions: 'AzureServices'
    policies: {
      retentionPolicy: {
        status: 'enabled'
        days: retentionDays
      }
      trustPolicy: {
        status: sku == 'Premium' ? 'enabled' : 'disabled'
        type: 'Notary'
      }
      quarantinePolicy: {
        status: sku == 'Premium' ? 'enabled' : 'disabled'
      }
    }
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  scope: registry
  name: 'diag-${name}'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      { categoryGroup: 'allLogs'; enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics'; enabled: true }
    ]
  }
}

output registryId string = registry.id
output registryName string = registry.name
output loginServer string = registry.properties.loginServer
