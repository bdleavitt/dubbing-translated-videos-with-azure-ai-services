import logging
import os
import random
import json
from datetime import datetime, timedelta
import time
import azure.functions as func
from azure.identity import ClientSecretCredential
from azure.mgmt.media import AzureMediaServices
from azure.storage.blob import BlobServiceClient, BlobClient, ContainerClient, generate_blob_sas, BlobSasPermissions
from azure.mgmt.media.models import (
    Asset,
    Job,
    JobInputAsset,
    JobOutputAsset,
    ListContainerSasInput,
)

def main(req: func.HttpRequest) -> func.HttpResponse:

    ####################################################################################################################
    ## Set up all the variables
    ####################################################################################################################
    ## Get the video_id from the request
    req_body = req.get_json()
    video_id = req_body.get("video_id")
    
    ## Get the blob sas URI to the mp3 file included in the request
    blob_sas_uri = req_body.get("blob_sas_uri")

    ## Get the target audio file details
    input_audio_blob_client = BlobClient.from_blob_url(blob_sas_uri)
    input_audio_blob_file_name = input_audio_blob_client.blob_name.split("/")[-1]

    ## Unique identifier for this job
    uniqueness = random.randint(0,9999)

    ## get authentication credentials
    client_cred = ClientSecretCredential(
        client_id=os.environ["CLIENT_APP_ID"],
        client_secret=os.environ["CLIENT_APP_SECRET"],
        tenant_id=os.environ["CLIENT_APP_TENANT_ID"],
    )

    ## Create media services client
    media_client = AzureMediaServices(
        credential=client_cred, subscription_id=os.environ["AZURE_SUBSCRIPTION_ID"]
    )

    ## Create a blob services client for the media services storage account:
    media_blob_service_client = BlobServiceClient.from_connection_string(
        os.environ["MEDIA_SERVICES_STORAGE_ACCOUNT_CONNECTION_STRING"]
    )

    ####################################################################################################################
    ## Create an asset in media services as the temporary input location for encoding.
    ####################################################################################################################

    ## create an asset and container for the audio file and upload the audio file
    temp_input_asset_name = video_id + "-audio-temp-input-" + input_audio_blob_file_name + str(uniqueness)

    logging.info("Creating asset: " + temp_input_asset_name)

    temp_input_asset = media_client.assets.create_or_update(
        resource_group_name=os.environ["MEDIA_SERVICES_RESOURCE_GROUP"],
        account_name=os.environ["MEDIA_SERVICES_ACCOUNT_NAME"],
        parameters=Asset(),
        asset_name=temp_input_asset_name
    )

    temp_input_container_name = "asset-" + temp_input_asset.asset_id

    ####################################################################################################################
    ## Upload the mp3 file to the asset using the passed in blob SAS URI
    ####################################################################################################################
    logging.info(f"Uploading blob: {input_audio_blob_file_name} to asset: {temp_input_asset_name}")

    temp_input_blob_client = media_blob_service_client.get_blob_client(
        container=temp_input_container_name,
        blob=input_audio_blob_file_name
    )

    temp_input_blob_client.upload_blob_from_url(blob_sas_uri, overwrite=True)

    ####################################################################################################################
    ## Create an asset in media services as the temporary output location for the encoded .mp4 file.
    ####################################################################################################################
    logging.info("Creating an asset for the output file")
    temp_output_asset_name = video_id + "-audio-temp-output-" + input_audio_blob_file_name + str(uniqueness)

    temp_output_asset = media_client.assets.create_or_update(
        resource_group_name=os.environ["MEDIA_SERVICES_RESOURCE_GROUP"],
        account_name=os.environ["MEDIA_SERVICES_ACCOUNT_NAME"],
        parameters=Asset(),
        asset_name=temp_output_asset_name
    )
    
    temp_output_container_name = "asset-" + temp_output_asset.asset_id

    ####################################################################################################################
    ## Configure a job to do the encoding and wait for completion
    ####################################################################################################################
    ## create a media services job to encode the audio
    job_name = "job-" + video_id + f"-{input_audio_blob_file_name}-encode-{str(uniqueness)}"

    job_input = JobInputAsset(asset_name=temp_input_asset_name)
    job_output = JobOutputAsset(asset_name=temp_output_asset_name)

    theJob = Job(input=job_input, outputs=[job_output])

    transform_name="MP3toAACMP4"

    current_job = media_client.jobs.create(
        account_name=os.environ["MEDIA_SERVICES_ACCOUNT_NAME"],
        resource_group_name=os.environ["MEDIA_SERVICES_RESOURCE_GROUP"],
        job_name=job_name,
        parameters=theJob,
        transform_name=transform_name
    )

    finished = False

    while not finished:
        logging.info('Waiting for encoding to complete')
        current_job = media_client.jobs.get(
            resource_group_name=os.environ["MEDIA_SERVICES_RESOURCE_GROUP"],
            account_name=os.environ["MEDIA_SERVICES_ACCOUNT_NAME"],
            transform_name=transform_name,
            job_name=job_name
        )
        state = current_job.state

        if state == "Finished":
            finished = True
            logging.info("Job completed. Uploading to destination video account.")
        elif state =="Error":
            raise Error
        else:
            time.sleep(10)
            logging.info("Job not complete. Checking in 10 seconds.")


    ####################################################################################################################
    ## Lookup the destination video container by video id
    ####################################################################################################################
    ## Looking up the storage account requires a couple of lookups.
    ## [video_id] -> Streaming Locators API -> [assetname] -> Asset API -> [storage container info]
    logging.info(f"Looking up the destination video container by video id: {video_id}")
    
    locators = media_client.streaming_locators.list(
        account_name=os.environ["MEDIA_SERVICES_ACCOUNT_NAME"],
        resource_group_name=os.environ["MEDIA_SERVICES_RESOURCE_GROUP"],
    )

    locators_list = []
    for i, r in enumerate(locators):
        locators_list.append(r.as_dict())

    ## [assetname] -> Asset API
    ## get the properties.assetname for the streaming locator that starts with the video id
    video_asset_name = [
        locator["asset_name"]
        for locator in locators_list
        if locator["name"].startswith(video_id)
    ][0]

    ## get the container name from asset details using the asset name
    video_asset = media_client.assets.get(
        resource_group_name=os.environ["MEDIA_SERVICES_RESOURCE_GROUP"],
        account_name=os.environ["MEDIA_SERVICES_ACCOUNT_NAME"],
        asset_name=video_asset_name
    )

    video_asset_id = video_asset.asset_id
    video_container_name = video_asset.container

    print(f"Found asset '{video_asset_name}' destination video container: '{video_container_name}'")

    ####################################################################################################################
    ## Upload the encoded .mp4 file to the video storage container.
    ####################################################################################################################
    ## find the MP4 file in the temp_output container
    output_asset_container_client = media_blob_service_client.get_container_client(temp_output_container_name)

    output_asset_container_client.list_blobs()
    output_mp4 = [asset for asset in output_asset_container_client.list_blobs() if asset.name.endswith(".mp4")][0]

    source_blob_sas_token = generate_blob_sas(
        account_name = media_blob_service_client.credential.account_name,
        account_key = media_blob_service_client.credential.account_key,
        container_name = output_mp4.container,
        blob_name=output_mp4.name,
        expiry=datetime.utcnow() + timedelta(hours=1),
        permission=BlobSasPermissions(read=True, list=True)
    )

    source_blob_sas_uri = f"https://{media_blob_service_client.credential.account_name}.blob.core.windows.net/{output_mp4.container}/{output_mp4.name}?{source_blob_sas_token}"

    destination_audio_blob = media_blob_service_client.get_blob_client(
        container=video_container_name,
        blob=output_mp4.name
    )

    destination_audio_blob.upload_blob_from_url(source_blob_sas_uri, overwrite=True)
    
    results_dict = {
        "file_name": output_mp4.name,
        "container": video_container_name
    }
    # Retun the results
    return func.HttpResponse(
        json.dumps(results_dict), status_code=200
    )