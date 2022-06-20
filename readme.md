1. Clone repo.
2. cd ./deploy/
3. Create a new resource group, i.e. "az group create -l eastus2 -g RG-VideoDubbing-Bicep"
4. Deploy the bicep templates. Choose your own prefix instead of "tla": "az deployment group create -g RG-VideoDubbing-Bicep --template-file .\main.bicep --parameters prefix=tla"