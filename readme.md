This solution allows a user to upload a video to Azure Blob Storage, and then automatically process and dub it into multiple languages, which can be then viewed using the Azure Video Indexer website. 

To get started

1. Clone repo.
2. cd ./deploy/
3. Create a new resource group, i.e. "az group create -l eastus2 -g RG-VideoDubbing-Bicep"
4. Deploy the bicep templates. Choose your own prefix instead of "tla": "az deployment group create -g RG-VideoDubbing-Bicep --template-file .\main.bicep --parameters prefix=tla"


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
1.  