import logging
import os
import json
import azure.functions as func
from lxml import etree as ET
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

def lookup_asset_details(video_id, media_client):
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

    streaming_locator_id = [
        locator["streaming_locator_id"]
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

    endpoints = media_client.streaming_endpoints.list(
        account_name=os.environ["MEDIA_SERVICES_ACCOUNT_NAME"],
        resource_group_name=os.environ["MEDIA_SERVICES_RESOURCE_GROUP"],
    )
    endpoint = [endpoint for endpoint in endpoints][0]
    endpoint_host_name = endpoint.host_name
    return(
        {
            "asset_id":video_asset_id, 
            "container_name":video_container_name,
            "endpoint_host_name":endpoint_host_name,
            "streaming_locator_id":streaming_locator_id
        }
    )


def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    try:
        req_body = req.get_json()
        video_id = req_body['video_id']
    except ValueError as e :
        logging.warning(e)
        raise e 
    try:
        default_language_language_code = req.get_json()["default_language_language_code"]
        default_language_3_letter_code = req.get_json()["default_language_3_letter_code"]
    except:
        default_language_language_code = 'en-US'
        default_language_3_letter_code = 'eng'

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
    
    ## Lookup the video container in media services based on video id
    asset_details_dict = lookup_asset_details(video_id, media_client)

    ## Read all the contents of the container and select just the .mp4s that have the text AACAudio in them. 
    ## Create a blob services client for the media services storage account:
    media_blob_service_client = BlobServiceClient.from_connection_string(
        os.environ["MEDIA_SERVICES_STORAGE_ACCOUNT_CONNECTION_STRING"]
    )
    container_client = media_blob_service_client.get_container_client(
        asset_details_dict["container_name"]
    )
    ## get the list of all the audio mp4 blobs in the container
    all_asset_files = container_client.list_blobs()
    track_list = [
        track.name for track in all_asset_files
        if track.name.endswith(".mp4") 
        and track.name.startswith(video_id)
    ]
    ## get the .ism
    all_asset_files = container_client.list_blobs()
    manifest_name = [f.name for f in all_asset_files if f.name.endswith(".ism")][0]
    manifest_xml_blob_client = container_client.get_blob_client(manifest_name)
    manifest_xml_text = manifest_xml_blob_client.download_blob().readall()

    ## Parse and adjust the manifest
    parser = ET.XMLParser(remove_blank_text=True)
    root = ET.fromstring(text=manifest_xml_text, parser=parser)

    default_ns = "http://www.w3.org/2001/SMIL20/Language"
    ns = "{" + default_ns + "}"

    ## Update the header to include just the mp4 content meta tag.
    namespaces = {"": default_ns}
    head = root.find(f"./head", namespaces)

    for metatag in head.findall(f"./meta", namespaces):
        head.remove(metatag)

    head.append(ET.Element("meta", attrib={"name": "formats", "content": "mp4"}))

    ## Update the original audio (track 2) with default language values
    orignal_audio_track_param = root.find(f"./body/switch/audio/param[@value='2']", namespaces)
    audio_element = orignal_audio_track_param.getparent()

    audio_element.set("systemLanguage", default_language_3_letter_code)

    audio_lang_param = audio_element.find(f"./param[@name='systemLanguage']", namespaces)
    audio_lang_param.set("value", default_language_3_letter_code)

    audio_lang_param = audio_element.find(f"./param[@name='trackName']", namespaces)
    audio_lang_param.set("value", default_language_language_code)

    ## save the updated original audio track
    audio_element_temp = ET.tostring(audio_element, encoding="unicode")

    ## For each .mp4, create a manifest entry and add it to the manifest.xml
    ## Insert all the new audio language definitions into the the top of the switch
    ## tag. The entry order will affect the display order in hte media player.
    ## The last audio entry will be treated as the default.
    switch = root.find("./body/switch", namespaces=namespaces)

    ## delete all the audio tracks from the switch tag, then reinsert the original
    for audio_element in switch.findall("./audio", namespaces=namespaces):
        switch.remove(audio_element)

    switch.insert(0, ET.fromstring(audio_element_temp, parser=parser))

    for i in range(len(track_list)):
        three_letter_language = track_list[i].split("_")[3]
        language_code = track_list[i].split("_")[2]
        bitrate = str(192000)

        audio_element = ET.Element("audio", attrib={
                "src": track_list[i], "systemBitrate": bitrate, "systemLanguage": three_letter_language
            },
        )
        audio_element.append(ET.Element('param', attrib={'name': "systemBitrate", 'value': bitrate, 'valuetype': "data"}))
        audio_element.append(ET.Element('param', attrib={'name': "trackID", 'value': str(i+3), 'valuetype': "data"}))
        audio_element.append(ET.Element('param', attrib={'name': "trackName", 'value': language_code, 'valuetype': "data"}))
        audio_element.append(ET.Element('param', attrib={'name': "systemLanguage", 'value': three_letter_language, 'valuetype': "data"}))

        switch.insert(0, audio_element)

    ## overwrite the manifest.xml with the new manifest.
    manifest_xml_blob_client.upload_blob(
        ET.tostring(root, encoding="unicode"), 
        overwrite=True
    )

    ## Delete the .ismc file, call the streaming endpoint for a new one, then write it back. 
    all_asset_files = container_client.list_blobs()
    client_manifest_name = [f.name for f in all_asset_files if f.name.endswith(".ismc")][0]
    client_manifest_blob_client = container_client.get_blob_client(client_manifest_name)
    client_manifest_blob_client.download_blob().readall()
    client_manifest_blob_client.delete_blob()

    import requests
    manifest_url = f"https://{asset_details_dict['endpoint_host_name']}/{asset_details_dict['streaming_locator_id']}/{manifest_name}/manifest(encryption=cbc)"
    resp = requests.get(manifest_url)
    client_manifest_xml = resp.content

    ## remove the protection section
    client_tree = ET.fromstring(client_manifest_xml)
    protection_element = client_tree.find(f"./Protection")
    client_tree.remove(protection_element)
    client_manifest_xml_clean = ET.tostring(client_tree, encoding="unicode")
    client_manifest_blob_client.upload_blob(client_manifest_xml_clean)

    return(
        func.HttpResponse("Manifests updated!", status_code=200)
    )