param prefix string
param location string = resourceGroup().location
param spClientId string

// Add service principal as contributor resource group.
@description('This is the built-in Contributor role. See https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#contributor')
resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

resource spRBACAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid('Contributor', spClientId, subscription().subscriptionId)
  scope: resourceGroup()
  properties: {
    principalId: spClientId
    roleDefinitionId: contributorRoleDefinition.id
    principalType: 'ServicePrincipal'
  }
}

/******************/
// Create WIP storage container (ADLS gen 2)
/******************/
param videoUploadStorageName string = substring('${prefix}videodubstg${uniqueString(resourceGroup().id)}', 0, 24)

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
// Application insights (reused by az function/logic app)
/******************/
param azureAppInsightsName string = '${prefix}-dubbing-function-insights-${uniqueString(resourceGroup().id)}'
param azureLogAnalyticsName string = '${prefix}-dubbing-function-loganalytics-${uniqueString(resourceGroup().id)}'

// App Insights
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
// Logic App
/******************/
param logicAppName string = '${prefix}-dubbing-logicapp-${uniqueString(resourceGroup().id)}'
param logicAppASPName string = '${prefix}-dubbing-logicapp-asp-${uniqueString(resourceGroup().id)}'
param logicAppStorageName string = substring('${prefix}logicstg${uniqueString(resourceGroup().id)}', 0, 24)

module logicApp 'modules/logicapp.bicep' = {
  name: logicAppName
  params: {
    location: location
    logicAppName: logicAppName
    logicAppASPName: logicAppASPName
    logicAppStorageName: logicAppStorageName
    appInsightsConnectionString: appInsights.properties.ConnectionString
    appInsightsInstrumentationKey: appInsights.properties.InstrumentationKey
  }
}

/******************/
// Video Indexer
/******************/
param medSvcAccountName string = substring('${prefix}mediasvc${uniqueString(resourceGroup().id)}', 0, 24)
param medSvcStorageName string = substring('${prefix}mediasvcstg${uniqueString(resourceGroup().id)}', 0, 24)
param videoIndexerName string = '${prefix}-video-indexer-${uniqueString(resourceGroup().id)}'

module videoIndexer 'modules/videoindexer.bicep' = {
  name: videoIndexerName
  params: {
    location: location
    medSvcAccountName: medSvcAccountName
    medSvcStorageName: medSvcStorageName
    videoIndexerName: videoIndexerName
  }
}

/******************/
// Speech Service
/******************/
param speechServiceName string = '${prefix}-speech-api-${uniqueString(resourceGroup().id)}'

resource speechService 'Microsoft.CognitiveServices/accounts@2022-03-01' = {
  name: speechServiceName
  sku: {
    name: 'S0'
  }
  location: location
  kind: 'SpeechServices'
  properties: {
    publicNetworkAccess: 'Enabled'
  }
}

/******************/
// Azure Function
/******************/
param azureFunctionAppName string = '${prefix}-dubbing-function-${uniqueString(resourceGroup().id)}'
param azureFunctionAppServicePlanName string = '${prefix}-dubbing-function-asp-${uniqueString(resourceGroup().id)}'
param azureFunctionStorageName string = substring('${prefix}functionstg${uniqueString(resourceGroup().id)}', 0, 24)

module azfunction 'modules/azurefunction.bicep' = {
  name: azureFunctionAppName
  params: {
    location: location    
    azureFunctionAppName: azureFunctionAppName
    azureFunctionStorageName: azureFunctionStorageName
    azureFunctionAppServicePlanName: azureFunctionAppServicePlanName
    appInsightsInstrumentationKey: appInsights.properties.InstrumentationKey
    appInsightsConnectionString: appInsights.properties.ConnectionString
    clientAppId: spClientId
    mediaServicesAccountName: medSvcAccountName
    mediaServicesAccountStorageName: videoIndexer.outputs.mediaServicesStorageAccountName
    speechServiceKey: speechService.listKeys().key1
    speechServiceKeyRegion: speechService.location
    videoStorageConnectionString: 'DefaultEndpointsProtocol=https;AccountName=${videoWorkingStorage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${videoWorkingStorage.listKeys().keys[0].value}'
  }
}

/******************/
// Key Vault
/******************/
param keyVaultName string = substring('${prefix}-keyvault-${uniqueString(resourceGroup().id)}', 0, 24)

module keyVault 'modules/keyvault.bicep' = {
  name: 'keyVault'
  params: {
    keyVaultName: keyVaultName
    location: location
    principalID: spClientId
    avamAccountIDParam: videoIndexer.outputs.avamAccountIDParam
    avamResourceIDParam: videoIndexer.outputs.avamResourceIDParam
    avamAccountRegionParam: videoIndexer.outputs.avamAccountRegionParam
    avamManagementTokenEndpointParam: '${environment().resourceManager}subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.VideoIndexer/accounts/${videoIndexer.name}/generateAccessToken?api-version=2022-04-13-preview'
  }
}

/******************/
// Connections
/******************/
// param blobStorageConnectionName string = 'azureblob' // 'connection-storage-blob-${azureLogicAppConnectionSuffix}'
// param keyVaultConnectionName string = 'keyvault' // 'connection-keyvault-${azureLogicAppConnectionSuffix}'
// param videoIndexerConnectionName string = 'videoindexer-v2' // 'connection-videoindexer-${azureLogicAppConnectionSuffix}'

// module connections 'modules/logicapp_connections.bicep' = {
//   name: 'logicAppConnections'
//   params: {
//     location: location
//     keyVaultName: keyVault.name
//     keyVaultConnectionName: keyVaultConnectionName
//     blobStorageConnectionName: blobStorageConnectionName
//     videoWorkingStorageID: videoWorkingStorage.id
//     videoWorkingStorageName: videoWorkingStorage.name
//     videoWorkingStorageApiVersion: videoWorkingStorage.apiVersion
//     videoIndexerConnectionName: videoIndexerConnectionName
//     logicAppPrincipalId: logicApp.outputs.logicAppPrincipalID
//     logicAppName: logicApp.outputs.appName
//   }
// }
