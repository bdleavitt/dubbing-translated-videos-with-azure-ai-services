param keyVaultConnectionName string
param keyVaultName string
param location string

resource keyVaultConnectionMSI 'Microsoft.Web/connections@2016-06-01' = {
  name: keyVaultConnectionName
  location: location
  kind: 'V2'
  properties: {
    api: {
      id: 'subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/keyvault'
    }
    displayName: keyVaultConnectionName
    parameterValueType: 'Alternative'
    alternativeParameterValues: { 
      'vaultName': keyVaultName
    }
  }
}


// resource connectionBlob 'Microsoft.Web/connections@2016-06-01' = {
//   name: blobStorageConnectionName
//   location: location
//   kind: 'V2'
//   properties: {
//     displayName: blobStorageConnectionName
//     api: {
//       id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azureblob')
//     }
//     parameterValues: {
//       accountName: videoWorkingStorage.name
//       accessKey: listKeys(videoWorkingStorage.id, videoWorkingStorage.apiVersion).keys[0].value
//       authType: 'basic'
//       privacySetting: 'Private'
//     }
//   }
// }

// resource videoIndexer 'Microsoft.VideoIndexer/accounts@2022-04-13-preview' existing = {
//   name: videoIndexerName
// }

// resource connectionVideoIndexer 'Microsoft.Web/connections@2016-06-01' = {
//   name: videoIndexerConnectionName
//   location: location
//   kind: 'V2'
//   properties: {
//     displayName: videoIndexerConnectionName
//     api: {
//       id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'videoindexer-v2')
//     }
//     parameterValues:{
//       'api_key': 'FILLMEINLATER'
//     }
//   }
// }


// resource keyvault 'Microsoft.KeyVault/vaults@2021-10-01' existing = {
//   name: keyVaultName
// }

// resource connectionKeyVault 'Microsoft.Web/connections@2016-06-01' = {
//   name: '${keyVaultConnectionName}02'
//   location: location
//   kind: 'V2'
//   properties: {
//     displayName: keyVaultConnectionName
//     api: {
//       id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'keyvault')
//     }
//     parameterValues: {
//       vaultName: keyvault.name
//     }
//   }
// }

// resource keyvaultPolicy 'Microsoft.Web/connections/accessPolicies@2016-06-01' = {
//   name: 
// }
