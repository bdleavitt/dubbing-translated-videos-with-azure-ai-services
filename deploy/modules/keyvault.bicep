param location string
param keyVaultName string
param servicePrincipalId string

/******************/
// Key Vault
/******************/
resource keyVault 'Microsoft.KeyVault/vaults@2021-10-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    accessPolicies: [
      {
        permissions: {
          secrets: [
            'all'
          ]
        }
        objectId: servicePrincipalId
        tenantId: tenant().tenantId
      }
    ]
  }
}
resource AVAMACCOUNTID 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  name: 'AVAM-ACCOUNT-ID'
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
    }
    value: ''
  }
}
resource AVAMACCOUNTREGION 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  name: 'AVAM-ACCOUNT-REGION'
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
    }
    value: ''
  }
}
resource AVAMMANAGEMENTTOKENENDPOINT 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  name: 'AVAM-MANAGEMENT-TOKEN-ENDPOINT'
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
    }
    value: ''
  }
}
resource AVAMRESOURCEID 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  name: 'AVAM-RESOURCE-ID'
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
    }
    value: ''
  }
}
resource CLIENTAPPID 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  name: 'CLIENT-APP-ID'
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
    }
    value: ''
  }
}
resource CLIENTAPPSECRET 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  name: 'CLIENT-APP-SECRET'
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
    }
    value: ''
  }
}
resource LOGICAPPENDPOINTAVAMGENERATECAPTIONS 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  name: 'LOGICAPP-ENDPOINT-AVAM-GENERATE-CAPTIONS'
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
    }
    value: ''
  }
}
resource LOGICAPPENDPOINTAVAMUPLOADCALLBACK 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  name: 'LOGICAPP-ENDPOINT-AVAM-UPLOAD-CALLBACK'
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
    }
    value: ''
  }
}
resource LOGICAPPENDPOINTENCODEMP3TOAACMP4 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  name: 'LOGICAPP-ENDPOINT-ENCODE-MP3TOAACMP4'
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
    }
    value: ''
  }
}
resource LOGICAPPENDPOINTGETAVAMACCESSTOKEN 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  name: 'LOGICAPP-ENDPOINT-GET-AVAM-ACCESS-TOKEN'
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
    }
    value: ''
  }
}
resource SPEECHLANGUAGESCONFIG 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  name: 'SPEECH-LANGUAGES-CONFIG'
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
    }
    value: ''
  }
}
resource TENANTID 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  name: 'TENANT-ID'
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
    }
    value: ''
  }
}

