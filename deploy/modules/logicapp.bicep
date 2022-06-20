/******************/
// Logic App
/******************/
param location string
param logicAppASPName string
param logicAppName string
param logicAppStorageName string
param azureAppInsightsName string
param videoUploadStorageName string
param blobStorageConnectionName string
param keyVaultName string
param keyVaultConnectionName string
param videoIndexerName string
param videoIndexerConnectionName string


//App Service Plan
resource logicAppASP 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: logicAppASPName
  location: location
  sku: {
    name: 'WS1'
    tier: 'WorkflowStandard'
  }
  properties: {
    elasticScaleEnabled: true
    maximumElasticWorkerCount: 20
  }
}

// App insights reference
resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: azureAppInsightsName
}
// Video WIP storage account reference
resource videoWorkingStorage 'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
  name: videoUploadStorageName
}

// Storage Account for stateful workflows
resource logicAppStorage 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: logicAppStorageName 
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
}

// Logic App
resource logicApp 'Microsoft.Web/sites@2021-03-01' = {
  name: logicAppName
  location: location
  kind: 'functionapp,workflowapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: logicAppASP.id
    siteConfig: {
      numberOfWorkers: 1
      appSettings: [
        {
          'name': 'FUNCTIONS_WORKER_RUNTIME'
          'value': 'node'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3' 
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~14'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${logicAppStorage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${logicAppStorage.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${logicAppStorage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${logicAppStorage.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: 'app-${logicAppName}-a6e9'
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__id'
          value: 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__version'
          value: '[1.*, 2.0.0)'
        }
        {
          name: 'APP_KIND'
          value: 'workflowApp'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~2'
        }
        {
          name: 'WORKFLOWS_LOCATION_NAME'
          value: location
          
        }
        {
          name: 'WORKFLOWS_MANAGEMENT_BASE_URI'
          value: environment().resourceManager
          
        }
        {
          name: 'WORKFLOWS_RESOURCE_GROUP_NAME'
          value: resourceGroup().name
          
        }
        {
          name: 'WORKFLOWS_SUBSCRIPTION_ID'
          value: subscription().id
          
        }
        {
          name: 'WORKFLOWS_TENANT_ID'
          value: tenant().tenantId
        }
      ]
    }
    httpsOnly: true
  }
}


output app string = logicApp.name
output plan string = logicAppASP.name
output logicappprincipalid string = logicApp.identity.principalId
