/******************/
// Video Indexer
/******************/
param videoIndexerName string
param location string
param medSvcAccountName string
param medSvcStorageName string

resource videoIndexer 'Microsoft.VideoIndexer/accounts@2022-04-13-preview' = {
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

resource mediaSvcsTransformCreate 'Microsoft.Media/mediaServices/transforms@2021-11-01' = {
  name: 'MP3toAACMP4'
  parent: mediaSvcsAccount
  properties: {
    outputs: [
      {
        onError: 'StopProcessingJob'
        relativePriority: 'Normal'
        preset: {
          '@odata.type': '#Microsoft.Media.BuiltInStandardEncoderPreset'
          presetName: 'AACGoodQualityAudio'
        }
      }
    ]
  }
}

output avamAccountIDParam string = videoIndexer.properties.accountId
output avamAccountRegionParam string = videoIndexer.location
output avamResourceIDParam string = videoIndexer.id
output mediaServicesStorageAccountName string = medSvcStorage.name
