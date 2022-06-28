# Using Azure Cognitive and AI Services to Dub Video Translations
This solution allows a user to upload a video to Azure Blob Storage, and then automatically process and dub it into multiple languages, which can be then viewed using the Azure Video Indexer website. 

To get started

## What gets deployed? 
The deploy folder contains Azure bicep template code which deploys a number of resources: 

1. A storage account for video uploads and for intermediate assets used in the creation of the new audio tracks. 
1. An Azure App Insight resource and Log Analytics workspace
1. An Azure Logic Apps (standard) account, which includes the following resources
    1. Logic App resource
    2. App service plan
    3. Azure Storage Account (for logs and workflow state tracking)
1. Video Indexer account, which includes:
    1. Video Indexer
    1. Media Services Account
    1. Media Services Storage Account
    1. Streaming endpoint
1. Azure function, which includes
    1. Function app
    1. An app service plan
    1. A storage account (for logs and workflow state tracking)
1. Azure Key vault
1. A Speech Services instance, part of the Azure Cognitive Services family

## Pre-requisites:
* Install the Azure CLI client on your machine. 
* Create an Azure app registration (a.k.a. service principal). This will be used to authenticate to various services. 
    * the service principal needs access to these resources TODO
    * Get the application ID
    * Get the directory / tenant ID
    * Go to Certificates & Secrets -> Genereate new client secret
* Install Azure Storage explorer

## Deployment and Configuration Steps
1. Clone repo.
1. Log in to Azure CLI client ``az login``
1. From the command line, navigate to the deploly folder, i.e. ``cd ./deploy/``
1. Create a new resource group ``az group create -l eastus2 -g RG-VideoDubbing-Bicep``
1. Deploy the bicep templates. Choose your own prefix instead of "tla" and include the app replace the guid with the id of your service principal: ``az deployment group create -g RG-VideoDubbing-Bicep --template-file .\main.bicep --parameters prefix=tla spClientId=spClientId=0000000-0000-0000-0000-000000000000``
1. Open the Azure Portal and navigate to the resource group view of the resource group you created and deployed to. 
1. **Create an uploads directory in Azure Storage**
    1. Navigate to your storage account that will be used for video uploads and working files (this will be named something like {your prefix}**videodubstg**{uniquestring})
    1. Open the videodubbing storage container.
    1. Click "Add Directory". Name the directory "uploads" (lower case)
1. **Link Video Indexer and Media Services**
    1. Navigate to your Video Indexer resource. 
    1. You may see a message that says "This account is not connected to the specified Azure Media Service account due to a missing role assignment." If this shows, click the "Assign role" button 
1. **Configure Access Policy for Key Vault** - your Logic App needs to be able to read secrets from the Azure Key Vault, and so will you. 
    1. Copy the name of your deployed logic app. (i.e. "bdl-dubbing-logicapp-r2qqwn6j54t3c")
    1. Navigate to your key vault
    1. Go to Access Policies
    1. +Add access policy
    1. Under "Secret Permissions" select "Get" and "List" options. 
    1. Under Select principal click "None selected" then search for and select the name of your Logic App. 
    1. Click "Add"
    1. Repeat the above steps using your own User ID as the principal and assign yourself all rights on the key vaults using the "Configure from template" option. This will give you all permissions. 
    1. **Don't forget to click "SAVE" on before navigating away from the KV access policy  screen!**
1. **Set Logic Apps to access resources**
    1. Open Logic apps
    2. Click on "Workflows"
    3. Add a Workflow named "ConnectionsSetup"
    4. Set the trigger to "When a HTTP request is received"
    5. Add a Key Vault "Get Secret" action.
        * Click connect with managed identity.
        * In "connection name" put this exact string: ``keyvault``
        * In vault name paste the name of your keyvault (i.e. bdl-keyvault-r2qqwn6j54t)
        * Select any of the listed secrets and click "Save" to save the workflow. This will preserved the connection to be used by the custom logic app. 
    6. Add a "List Blobs (V2)" action
        * For connection name enter exactly: ``azureblob``
        * Authentication type: Access Key
        * Azure Storage Account Name: paste the storage account name for your upload/working storage account (i.e. bdlvideodubstgr2qqwn6j54)
        * In a separate tab, navigate to your storage account > Access Keys > "show keys" > then copy the key string. Paste this in the Azure S torage Account Access Key
        * Under storage account name, choose "Use Connection Settings" 
        * Verify you can connect by clicking to the videodubbing/uploads folder.
        * Click save
    7. Add a "Get Accounts" Video Indexer action
        * Under connection name set the value to exactly: ``videoindexer-2``
        * Under API Key enter any random string. We will be using the more modern identity based authentication. 
        * Click save
    8. Add Azure Function connections
        * Add a "Call an Azure Function" action. 
        * Call this connection ``TranscriptToAudio``
        * Click on your deployed function app (i.e. bdl-dubbing-function-r2qqwn6j54t3c)
        * Select the TranscriptToAudio function (i.e. bdl-dubbing-function-r2qqwn6j54t3c/TranscriptToAudio)
        * Click "Create"
        * Set the Method to POST
        * Type ``'{}'`` in the Request body field.
        * Repeat these steps for the "EncodeMP3toAACMP4" and "UpdateVideoManifestXML" functions. Save after adding each action. 

1. **Deploy your logic apps code from VS Code** 
    1. Open the ./logic_app directory directly. (If you try to deploy from the root folder you may get an error)
    1. Ctrl+Shift+P to open command palled
    1. Type "Deploy to Logic App" and choose the menu option. 
    1. Follow the prompts to deploy the code to your newly created logic app (i.e. bdl-dubbing-logicapp-r2qqwn6j54t3c)
    1. After deployment, navigate to your logic app in the Azure Portal. You should see new workflows added. 
1. **Connect your Logic App with Azure Functions**
    1. Navigate to the "WF3-GenerateAVAMTranscriptandAudio" workflow.
    1. In the desinger, locate the "Call AzureFn TranscriptToAudio" step. 
    1. Click change connection.
    1. Select the TranscriptToAudio function connection you created earlier. 
    1. Navigate to WF4-EncodeMP3toAACMP4 workflow and repeat these steps forthe  EncodeMP3toAACMP4 and UpdateVideoManifestXML function connections. 
    1. Save your workflow. 

1. **Update Function App Settings**
    1. Open your function app in the portal > Configuration
    1. In the app settings, set the CLIENT_APP_SECRET to the secret for your service principal. 
    1. Be sure to click SAVE before navigating from the app settings screen. 

1. **Update Key Vault Secrets**
    1. Navigate to your Key Vault
    1. Update CLIENT-APP-SECRET wit the secret for your service principal. 
    1. Update the following secrets with the respective Logic App worfklow URL (you may want to open a second browser and do this side by side)
        
        * LOGICAPP-ENDPOINT-GET-AVAM-ACCESS-TOKEN (WF0)
        * LOGICAPP-ENDPOINT-AVAM-UPLOAD-CALLBACK (WF2)
        * LOGICAPP-ENDPOINT-AVAM-GENERATE-CAPTIONS (WF3)
        * LOGICAPP-ENDPOINT-ENCODE-MP3TOAACMP4 (WF4)
        
1. **Update Language Config**
The language config setting is house in the Key Vault under the SPEECH-LANGUAGES-CONFIG
secret. This is a JSON array that specifies what language and what voice should be used to generate the dubbed audio. Update your own list using the supported pre-built neural voices listed here: https://docs.microsoft.com/en-us/azure/cognitive-services/speech-service/language-support?tabs=speechtotext#text-to-speech. You finished product should look should look something like this: 

```
[
  {
    "language-text-code": "zh-Hans",
    "language-three-letter-code": "zho",
    "language-voice-code": "zh-CN",
    "language-voice-name": "zh-CN-YunxiNeural"
  },
  {
    "language-text-code": "es-MX",
    "language-three-letter-code": "spa",
    "language-voice-code": "es-MX",
    "language-voice-name": "es-MX-JorgeNeural"
  },
  {
    "language-text-code": "fr-FR",
    "language-three-letter-code": "fra",
    "language-voice-code": "fr-FR",
    "language-voice-name": "fr-FR-HenriNeural"
  },
  {
    "language-text-code": "th-TH",
    "language-three-letter-code": "tha",
    "language-voice-code": "th-TH",
    "language-voice-name": "th-TH-NiwatNeural"
  }
]
```