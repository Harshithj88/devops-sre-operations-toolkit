targetScope = 'resourceGroup'

@description('Environment name (dev, prod)')
@allowed(['dev', 'prod'])
param environment string

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Base name prefix for resources')
param baseName string = 'ops'

@description('Log Analytics retention in days')
param logRetentionDays int = 30

@description('App Service Plan SKU')
param appServiceSkuName string = environment == 'prod' ? 'P1v3' : 'B1'

@description('SQL Database SKU')
param sqlSkuName string = environment == 'prod' ? 'S1' : 'Basic'

@description('Administrator login for SQL Server')
@secure()
param sqlAdminLogin string

@description('Administrator password for SQL Server')
@secure()
param sqlAdminPassword string

var resourceSuffix = '${baseName}-${environment}'

module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'log-analytics-${resourceSuffix}'
  params: {
    name: 'law-${resourceSuffix}'
    location: location
    retentionInDays: logRetentionDays
  }
}

module keyVault 'modules/key-vault.bicep' = {
  name: 'key-vault-${resourceSuffix}'
  params: {
    name: 'kv-${resourceSuffix}'
    location: location
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
  }
}

module appService 'modules/app-service.bicep' = {
  name: 'app-service-${resourceSuffix}'
  params: {
    appName: 'app-${resourceSuffix}'
    planName: 'plan-${resourceSuffix}'
    location: location
    skuName: appServiceSkuName
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    keyVaultName: keyVault.outputs.keyVaultName
  }
}

module sqlDatabase 'modules/sql-database.bicep' = {
  name: 'sql-${resourceSuffix}'
  params: {
    serverName: 'sql-${resourceSuffix}'
    databaseName: 'db-${resourceSuffix}'
    location: location
    skuName: sqlSkuName
    adminLogin: sqlAdminLogin
    adminPassword: sqlAdminPassword
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
  }
}

output appServiceUrl string = appService.outputs.defaultHostName
output keyVaultUri string = keyVault.outputs.keyVaultUri
output logAnalyticsWorkspaceId string = logAnalytics.outputs.workspaceId
