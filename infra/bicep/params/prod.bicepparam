using '../main.bicep'

param environment = 'prod'
param location = 'eastus'
param baseName = 'ops'
param logRetentionDays = 90
param appServiceSkuName = 'P1v3'
param sqlSkuName = 'S1'
param sqlAdminLogin = readEnvironmentVariable('SQL_ADMIN_LOGIN')
param sqlAdminPassword = readEnvironmentVariable('SQL_ADMIN_PASSWORD')
