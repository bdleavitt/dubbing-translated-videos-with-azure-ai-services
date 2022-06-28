param location string
param keyVaultName string
param principalID string
param avamAccountIDParam string = ''
param avamAccountRegionParam string = ''
param avamResourceIDParam string = ''
param avamManagementTokenEndpointParam string = ''

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
    enabledForDeployment: true
    enableRbacAuthorization: false
    tenantId: tenant().tenantId
    accessPolicies: [
      // {
      //   permissions: {
      //     secrets: [
      //       'all'
      //     ]
      //   }
      //   objectId: '60f6fccb-935a-40a3-a7bb-f899b9ca0f1b'
      //   tenantId: tenant().tenantId
      // }
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
    value: avamAccountIDParam
  }
}
resource AVAMACCOUNTREGION 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  name: 'AVAM-ACCOUNT-REGION'
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
    }
    value: avamAccountRegionParam
  }
}
resource AVAMMANAGEMENTTOKENENDPOINT 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  name: 'AVAM-MANAGEMENT-TOKEN-ENDPOINT'
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
    }
    value: avamManagementTokenEndpointParam
  }
}
resource AVAMRESOURCEID 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  name: 'AVAM-RESOURCE-ID'
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
    }
    value: avamResourceIDParam
  }
}
resource CLIENTAPPID 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  name: 'CLIENT-APP-ID'
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
    }
    value: principalID
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
    value: '''[
      {
        "language-text-code": "zh-Hans",
        "language-three-letter-code": "zho",
        "language-voice-code": "zh-CN",
        "language-voice-name": "zh-CN-YunxiNeural",
        "language-display-name": "Chinese - 中文"
      },
      {
        "language-text-code": "es-MX",
        "language-three-letter-code": "spa",
        "language-voice-code": "es-MX",
        "language-voice-name": "es-MX-JorgeNeural",
        "language-display-name": "Spanish - Español"
      },
      {
        "language-text-code": "fr-FR",
        "language-three-letter-code": "fra",
        "language-voice-code": "fr-FR",
        "language-voice-name": "fr-FR-HenriNeural",
        "language-display-name": "French - Français"
      },
      {
        "language-text-code": "th-TH",
        "language-three-letter-code": "tha",
        "language-voice-code": "th-TH",
        "language-voice-name": "th-TH-NiwatNeural",
        "language-display-name": "Thai - ไทย"
      }
    ]
    '''
  }
}
resource TENANTID 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  name: 'TENANT-ID'
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
    }
    value: tenant().tenantId
  }
}

