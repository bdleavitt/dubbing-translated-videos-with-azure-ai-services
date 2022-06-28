Saving only for posterity. Please see deployment steps in the readme.md file. 

### Deploy Azure Resources:
1. Deploy an Azure Storage Account w/ hierarchichal namespace enabled (a.k.a Azure Data Lake Storage Gen 2 or ADLS gen 2)
    * Set geo replication to "Locally redundant" for pilot/POC work, or per your organization's policy. 
    * Click enable Hierarchical namespace
    * After deployment, create a container/filesystem called "videodubbing"
1.  Deploy Video Indexer
    * Create a media services account.
    * Create a media services storage account.
    * Create a user-assignmed managed identity.
    * Check "I have all the rights to use the content/file, and agree that it will be handled per the Online Services Terms and the Microsoft Privacy Statement." 
    * If after deployment you see a message in the Video Indexer portal page about a missing role assignment, click the button "add role assignment". 
1. Deploy Speech API
    * Defaults are okay.
1. Deploy an Azure Key Vault
    * Pricing tier: Standard
    * Add a Access policy with all key permissions using the app registration you created previously. 
    * After deployment, create the following secrets and apply their 

    Secret Name |Description | Example Value
    ---|---|---
    AVAM-ACCOUNT-ID | Guid you can in the Azure portal or at videoindexer.ai | "00000000-0000-0000-0000-000000000000"
    AVAM-ACCOUNT-REGION | Azure region where AVAM was deployed | i.e. eastus2, westus2, etc.     
    AVAM-RESOURCE-ID | Found in the Azure portal in the AVAM resource, under the "Properties" tab | Ex. "/subscriptions/{your_subscription_id_guid}/<br/>resourceGroups/{resource_group_name}/providers/<br/>Microsoft.VideoIndexer/accounts/{avam_account_name}"
    AVAM-MANAGEMENT-TOKEN-ENDPOINT | Used to generate access tokens for the API |   "https://management.azure.com/subscriptions/<br/>{your_subscription_guid}/resourceGroups/{your_resource_group_name}<br/>/providers/Microsoft.VideoIndexer/accounts/<br/>{video_indexer_account}/generateAccessToken?<br/>api-version=2022-04-13-preview"
    CLIENT-APP-ID | Application ID of the service principal you created | "00000000-0000-0000-0000-000000000000"
    CLIENT-APP-SECRET | Secret key of the service prinicpal | 
    LOGICAPP-ENDPOINT-AVAM-GENERATE-CAPTIONS | Url of logic app workflow, found after deploying logic app | ""
    LOGICAPP-ENDPOINT-AVAM-UPLOAD-CALLBACK | Url of logic app workflow, found after deploying logic app | ""
    LOGICAPP-ENDPOINT-ENCODE-MP3TOAACMP4 | Url of logic app workflow, found after deploying logic app | ""
    LOGICAPP-ENDPOINT-GET-AVAM-ACCESS-TOKEN | Url of logic app workflow, found after deploying logic app | "" 
    SPEECH-LANGUAGES-CONFIG | A json array of the various languages that you want to translate and dub the languages to. You can find [supported languages for AVAM](https://api-portal.videoindexer.ai/api-details#api=Operations&operation=Get-Video-Captions) here and [supported voices for Azure Speech API](https://docs.microsoft.com/en-us/azure/cognitive-services/speech-service/language-support?tabs=speechtotext#prebuilt-neural-voices) | See below
    TENANT-ID | The Azure Active Directory tenant ID where you created the app registration and deployed your resources. | "00000000-0000-0000-0000-000000000000"

    Sample speech languages config:
    ```json [
    {
        "language-text-code": "zh-Hans",
        "language-voice-code": "zh-CN",
        "language-voice-name": "zh-CN-XiaomoNeural",
        "language-display-name": "Chinese"
    },
    {
        "language-text-code": "es-MX",
        "language-voice-code": "es-MX",
        "language-voice-name": "es-MX-JorgeNeural",
        "language-display-name": "Spanish (Mexico)"
    },
    ...repeat for additional languages...
    ]
    ```

1. Deploy an Azure Function App with translation container
    0. (Optional) You an build a docker image using the dockerfile in the az_function folder. Otherwise, you can pull from the image hosted in docker hub. 
    1. In Azure portal, begin creating a new function app. 
        * Publish: Docker Container
        * Region: same region as your other resources
        * Operating system: Linux 
        * Plan type: functions premium
        * Linux Plan: create new
        * SKU: EP1
        * Redundancy: disabled
        * Hosting > create or use an existing storage account
        * Networking > Enable network injection: off
        * Monitoring > Enable App Insights: yes (create new if needed)
    2. After deployment, open the portal page for the function app. 
    3. Go to "Deployment center"
        * Source: Container registry
        * Container Type: single
        * Registry source: Docker Hub
        * Repository access: Public
        * Full image name and tag: bleavitt/videodubbingfunction:latest
        * Continuous deployment: Off

1. Deploy an Azure Logic App
    1. Open the logic_app folder in VSCode (don't open the parent directory). 
    1. Be sure to have installed the vscode extension for logic apps (standard)
    1. From the command pallet, type "Azure Logic Apps: Deploy to Logic App..."
    1. Select your subscription
    1. Choose "Create a new Logic App (Standard) in Azure..." with the following choices
        * Publish: Workflow
        * Plan type: Standard
        * App Service Plan: Create New
        * Plan Sku and Size: WS1
        * Create new storage account for workflow state and run history.
        * Enable application insights (create a new instance)



## Creating Logic App connections
After deploying the logic app from the bicep template, you need to create some connections. 
0. Key Vault connection
    * connection name: "keyvault"
    * vault name: the name of the deployed vault
    * managed identity: System-assigned managed identity
0. Blob storage connection for V2 actions
    * connection name: azureblob
    * authentication type: managed 