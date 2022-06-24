param keyVaultConnectionName string
param keyVaultName string
param blobStorageConnectionName string
param videoWorkingStorageName string
param videoWorkingStorageID string
param videoWorkingStorageApiVersion string
param videoIndexerConnectionName string
param location string
param logicAppName string
param logicAppPrincipalId string


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

resource connectionBlob 'Microsoft.Web/connections@2016-06-01' = {
  name: blobStorageConnectionName
  location: location
  kind: 'V2'
  properties: {
    displayName: blobStorageConnectionName
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azureblob')
    }
    parameterValues: {
      accountName: videoWorkingStorageName
      accessKey: listKeys(videoWorkingStorageID, videoWorkingStorageApiVersion).keys[0].value
      authType: 'basic'
      privacySetting: 'Private'
    }
  }
}

resource connectionVideoIndexer 'Microsoft.Web/connections@2016-06-01' = {
  name: videoIndexerConnectionName
  location: location
  kind: 'V2'
  properties: {
    displayName: videoIndexerConnectionName
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'videoindexer-v2')
    }
    parameterValues:{
      'api_key': 'FILLMEINLATER'
    }
  }
}


/* 
resource logicapp_to_keyvault_policy 'Microsoft.Web/connections/accessPolicies@2016-06-01' = {
  location: location
  name: '${logicAppName}-${logicAppPrincipalId}'
  parent: keyVaultConnectionMSI
  properties: {
    principal: {
      type: 'ActiveDirectory'
      identity: {
        objectId: logicAppPrincipalId
        tenantId: tenant().tenantId
      }
    }
  }
}

resource logicapp_to_azureblob_policy 'Microsoft.Web/connections/accessPolicies@2016-06-01' = {
  name: '${logicAppName}-${logicAppPrincipalId}'
  location: location
  parent: connectionBlob
  properties: {
    principal: {
      type: 'ActiveDirectory'
      identity: {
        tenantId: tenant().tenantId
        objectId: logicAppPrincipalId
      }
    }
  }
}

resource logicapp_to_videoindexer_policy 'Microsoft.Web/connections/accessPolicies@2016-06-01' = {
  name: '${logicAppName}-${logicAppPrincipalId}'
  location: location
  parent: connectionVideoIndexer
  properties: {
    principal: {
      type: 'ActiveDirectory'
      identity: {
        tenantId: tenant().tenantId
        objectId: logicAppPrincipalId
      }
    }
  }
}
*/
