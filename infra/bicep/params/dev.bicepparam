using '../main.bicep'

param environment = 'dev'
param location = 'eastus'
param baseName = 'ops'
param logRetentionDays = 30
param appServiceSkuName = 'B1'
param sqlSkuName = 'Basic'
param sqlAdminLogin = readEnvironmentVariable('SQL_ADMIN_LOGIN')
param sqlAdminPassword = readEnvironmentVariable('SQL_ADMIN_PASSWORD')
