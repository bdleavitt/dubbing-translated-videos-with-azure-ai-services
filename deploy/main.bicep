/***************************************/
// Params
/***************************************/
param prefix string
param location string = resourceGroup().location

param videoUploadStorageName string = substring('${prefix}videodubstg${uniqueString(resourceGroup().id)}', 0, 24)
param medSvcStorageName string = substring('${prefix}mediasvcstg${uniqueString(resourceGroup().id)}', 0, 24)
param videoIndexerName string = '${prefix}-video-indexer-${uniqueString(resourceGroup().id)}'
param medSvcAccountName string = substring('${prefix}mediasvc${uniqueString(resourceGroup().id)}', 0, 24)
param keyVaultName string = substring('${prefix}-keyvault-${uniqueString(resourceGroup().id)}', 0, 24)

param azureFunctionAppName string = '${prefix}-dubbing-function-${uniqueString(resourceGroup().id)}'
param azureFunctionAppServicePlanName string = '${prefix}-dubbing-function-asp-${uniqueString(resourceGroup().id)}'
param azureAppInsightsName string = '${prefix}-dubbing-function-insights-${uniqueString(resourceGroup().id)}'
param azureLogAnalyticsName string = '${prefix}-dubbing-function-loganalytics-${uniqueString(resourceGroup().id)}'
param azureFunctionStorageName string = substring('${prefix}functionstg${uniqueString(resourceGroup().id)}', 0, 24)

param azureLogicAppConnectionSuffix string = uniqueString(resourceGroup().id)
param logicAppASPName string = '${prefix}-dubbing-logicapp-asp-${uniqueString(resourceGroup().id)}'
param logicAppName string = '${prefix}-dubbing-logicapp-${uniqueString(resourceGroup().id)}'
param logicAppStorageName string = substring('${prefix}logicstg${uniqueString(resourceGroup().id)}', 0, 24)
param blobStorageConnectionName string = 'connection-storage-blob-${azureLogicAppConnectionSuffix}'
param keyVaultConnectionName string = 'connection-keyvault-${azureLogicAppConnectionSuffix}'
param videoIndexerConnectionName string = 'connection-videoindexer-${azureLogicAppConnectionSuffix}'

/******************/
// Upload / WIP storage container (ADLS gen 2)
/******************/
resource videoWorkingStorage 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: videoUploadStorageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    isHnsEnabled: true
    accessTier: 'Hot'
  }
}

// Create storage container for working files
resource videoWorkingStorageContainerBlobSvc 'Microsoft.Storage/storageAccounts/blobServices@2021-09-01' = {
  name: 'default'
  parent: videoWorkingStorage
}

resource videoWorkingStorageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  name: 'videodubbing'
  parent: videoWorkingStorageContainerBlobSvc
}

/******************/
// Video Indexer
/******************/
resource videoIndexer 'Microsoft.VideoIndexer/accounts@2021-11-10-preview' = {
  name: videoIndexerName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    mediaServices: {
      resourceId: mediaSvcsAccount.id
    }
  }
}

resource mediaSvcsAccount 'Microsoft.Media/mediaservices@2021-06-01' = {
  name: medSvcAccountName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    storageAccounts: [
      {
        id: medSvcStorage.id
        type: 'Primary'
        identity: {
          useSystemAssignedIdentity: true
        }
      }
    ]
  }
}

// Media svcs storage
resource medSvcStorage 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: medSvcStorageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
}

// // default streaming endpoint
// resource medSvcStreamingEndpint 'Microsoft.Media/mediaservices/streamingEndpoints@2021-11-01' = {
//   name: 'default'
//   location: location
//   sku: {
//     capacity: 1
//   }
//   parent: mediaSvcsAccount
// }

/******************/
// Key Vault
/******************/
module keyVault 'modules/keyvault.bicep' = {
  name: 'keyVault'
  params: {
    keyVaultName: keyVaultName
    location: location
    servicePrincipalId: logicapp.outputs.logicappprincipalid
  }
  dependsOn: [
    logicapp
  ]
}

/******************/
// App Insights
/******************/
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: azureAppInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}
// Log Analytics
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: azureLogAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

/******************/
// Function
/******************/
module azfunction 'modules/azurefunction.bicep' = {
  name: azureFunctionAppName
  params: {
    appInsightsConnectionString: appInsights.properties.ConnectionString
    appInsightsInstrumentationKey: appInsights.properties.InstrumentationKey
    azureFunctionAppName: azureFunctionAppName
    azureFunctionAppServicePlanName: azureFunctionAppServicePlanName
    azureFunctionStorageName: azureFunctionStorageName
    location: location
  }
}

/******************/
// Logic App
/******************/
module logicapp 'modules/logicapp.bicep' = {
  name: logicAppName
  params: {
    azureAppInsightsName: appInsights.name
    blobStorageConnectionName: blobStorageConnectionName
    location: location
    logicAppASPName: logicAppASPName
    logicAppName: logicAppName
    logicAppStorageName: logicAppStorageName
    videoUploadStorageName: videoUploadStorageName
    keyVaultConnectionName: keyVaultConnectionName
    keyVaultName: keyVaultName
    videoIndexerConnectionName: videoIndexerConnectionName
    videoIndexerName: videoIndexerName
  }
}

/******************/
// Logic App - Connections
/******************/
module connections 'modules/logicapp_connections.bicep' = {
  name: 'connections'
  params: {
    keyVaultConnectionName: keyVaultConnectionName
    keyVaultName: keyVault.name
    location: location
  }
  dependsOn: [
    keyVault
  ]
}

/********************************/
// RBAC & Access Policies
/********************************/
// resource keyVaultRef 'Microsoft.KeyVault/vaults@2021-10-01' existing = {
//   name: keyVaultName
// }

// resource logicApp 'Microsoft.Web/sites@2021-03-01' existing = {
//   name: logicapp.outputs.app
// }

// resource keyVaultConnection 'Microsoft.Web/connectionGateways@2016-06-01' existing = {
//   name: keyVaultConnectionName
// }

resource logicapp_to_keyvault_policy 'Microsoft.Web/connections/accessPolicies@2016-06-01' = {
  name: '${keyVaultConnectionName}/${logicAppName}'
  location: location
  properties: {
    principal: {
      type: 'ActiveDirectory'
      identity: {
        tenantId: tenant().tenantId
        objectId: logicapp.outputs.logicappprincipalid
      }
    }
  }
  dependsOn: [
    connections
  ]
}

// resource logicappsKeyVaultAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
//   name: guid('Key Vault Secret User', logicApp.name, subscription().subscriptionId)
//   scope: keyVaultRef
//   properties: {
//     roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
//     principalId: logicApp.identity.principalId
//     principalType: 'ServicePrincipal'
//   }
// }
