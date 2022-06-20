/******************/
// Function
/******************/
// Azure function storage
param azureFunctionStorageName string
param azureFunctionAppServicePlanName string
param azureFunctionAppName string
param location string
param appInsightsInstrumentationKey string
param appInsightsConnectionString string

resource azFunctionStorage 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: azureFunctionStorageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
}

// Hosting plan
resource azFunctionAppServicePlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: azureFunctionAppServicePlanName
  location: location
  kind: 'linux'
  sku: {
    name: 'EP1'
    tier: 'ElasticPremium'
  }
  properties: {
    reserved: true
  }
}

//Azure function
resource azFunction 'Microsoft.Web/sites@2021-03-01' = {
  name: azureFunctionAppName
  location: location
  kind: 'functionapp,linux,container'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    serverFarmId: azFunctionAppServicePlan.id
    siteConfig: {
      linuxFxVersion: 'DOCKER|bleavitt/videodubbingfunction:1.0.4'
      numberOfWorkers: 1
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${azureFunctionStorageName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${azFunctionStorage.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${azureFunctionStorageName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${azFunctionStorage.listKeys().keys[0].value}'
        }

        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          'name': 'DOCKER_REGISTRY_SERVER_URL'
          'value': 'https://index.docker.io/v1'
        }
        {
          name: 'DOCKER_ENABLE_CI'
          value: 'false'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: azFunctionStorage.name
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
      ]
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
    }
  }
}
output azFunctionStorageName string = azFunctionStorage.name
