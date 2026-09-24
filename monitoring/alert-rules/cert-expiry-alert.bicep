@description('Log Analytics workspace resource ID containing certificate telemetry')
param workspaceId string

@description('Action group resource ID for notifications')
param actionGroupId string

@description('Azure region')
param location string = resourceGroup().location

@description('Days-before-expiry threshold that triggers a warning alert')
param warningThresholdDays int = 30

@description('Days-before-expiry threshold that triggers a critical alert')
param criticalThresholdDays int = 7

resource certExpiryWarning 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'alert-certificate-expiry-warning'
  location: location
  properties: {
    displayName: 'Certificate Expiring Within ${warningThresholdDays} Days'
    description: 'Fires when a monitored certificate is within the warning window of expiry.'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT1H'
    windowSize: 'P1D'
    scopes: [workspaceId]
    criteria: {
      allOf: [
        {
          query: 'CertificateInventory_CL\n| where DaysUntilExpiry_d <= ${warningThresholdDays} and DaysUntilExpiry_d > ${criticalThresholdDays}\n| summarize AggregatedValue = count() by Subject_s, Thumbprint_s, Computer'
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [actionGroupId]
    }
    autoMitigate: false
  }
}

resource certExpiryCritical 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'alert-certificate-expiry-critical'
  location: location
  properties: {
    displayName: 'Certificate Expiring Within ${criticalThresholdDays} Days'
    description: 'Fires when a monitored certificate is critically close to expiry.'
    severity: 0
    enabled: true
    evaluationFrequency: 'PT1H'
    windowSize: 'P1D'
    scopes: [workspaceId]
    criteria: {
      allOf: [
        {
          query: 'CertificateInventory_CL\n| where DaysUntilExpiry_d <= ${criticalThresholdDays}\n| summarize AggregatedValue = count() by Subject_s, Thumbprint_s, Computer'
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [actionGroupId]
    }
    autoMitigate: false
  }
}

output warningAlertId string = certExpiryWarning.id
output criticalAlertId string = certExpiryCritical.id
