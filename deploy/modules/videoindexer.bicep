/******************/
// Video Indexer
/******************/
param videoIndexerName string
param location string
param medSvcAccountName string
param medSvcStorageName string

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

output avamAccountIDParam string = videoIndexer.properties.accountId
output avamAccountRegionParam string = videoIndexer.location
output avamResourceIDParam string = videoIndexer.id
