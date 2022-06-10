import os
import logging
import json
import tempfile
import azure.functions as func
from shared_code.ttml2speech.TranscriptToVoiceConverter import TranscriptToVoiceConverter
from azure.storage.blob import BlobServiceClient

def main(req: func.HttpRequest): # -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    ## TODO: can remove some of the parameters in the request because they are 
    ## available in the avi index passed in the body. 

    ## Get the language code from the request
    language_code = req.params.get('language_code')
    ## language 3-letter code
    language_3_letter_code = req.params.get('language_three_letter_code')
    ## Get the language voice from the request
    language_voice = req.params.get('language_voice')
    ## Get the ttml text from the request
    index = req.get_body().decode('utf-8')
    index = json.loads(index)
    ## Get the video id
    video_id = req.params.get('video_id')
    ## Get the video duration
    video_duration = float(req.params.get('video_duration'))
    ## Prosody method
    prosody_method = req.params.get('prosody_method')
    ## Create the TTML Converter Object

    temp_path = os.path.join(tempfile.gettempdir(), video_id, language_code)
    logging.info(f'Creating the temp path {temp_path}')

    logging.info(f'Instantiating the TranscripttoVoiceConverter object')
    
    transcript = index['videos'][0]['insights']['transcript']

    my_converter = TranscriptToVoiceConverter(transcript=transcript, output_staging_directory=temp_path, prefix=video_id)
    
    ## TODO: pull from app settings or key vault
    ## Speech synthesis settings
    my_converter.speech_key = os.environ['SPEECH_SERVICE_KEY']
    my_converter.service_region = os.environ['SPEECH_SERVICE_KEY_REGION']
    my_converter.voice_name = language_voice
    my_converter.voice_language = language_code

    logging.info('Parsing Transcript to SSML')
    sentences_list = my_converter.parse_phrases()

    logging.info('Pre-process audio to determine phrase duration')
    sentences_list = my_converter.pre_process_audio_snippets(
        sentences_list=sentences_list
    )

    ## Get determine the rate to apply to hte voice to most closely match the original. 
    ## Then Re-preprocess audio snippet but include the average prosody rate
    logging.info('Calculate the optimal prosody rate')
    sentences_list = my_converter.calculate_prosody_rates(sentences_list=sentences_list, method=prosody_method)

    logging.info('Re-preprocess audio to include the average prosody rate')
    sentences_list = my_converter.pre_process_audio_snippets(
        sentences_list=sentences_list, 
        clip_audio_directory='prosody_adjusted', 
        duration_key="prosody_adjusted_duration"
    )

    # logging.info('Calculate the breaks to preserve timings')
    sentences_list = my_converter.calculate_breaks(sentences_list=sentences_list)
    
    logging.info('Generate the SSML with breaks')
    sentences_list = my_converter.generate_ssml_breaks(sentences_list=sentences_list)

    ## generate the ssml for each the created batches and submit the ssml to the audio for processing
    ## using the same target file and audio config which should allow us to exceed the 10 minute limit for speech sytnthesis. 
    output_audio_filename = f"{video_id}_{prosody_method}_{language_code}_{language_3_letter_code}_{language_voice}.mp3"
    output_audio_filepath = os.path.join(temp_path, output_audio_filename)
    
    logging.warning(f'Attempting to synthesize the audio to file: {output_audio_filename}')
    speech_synthesizer = my_converter.get_speech_synthesizer(output_filename=output_audio_filepath, speech_synthesis_output_format='Audio24Khz96KBitRateMonoMp3')
    for sentence in sentences_list:
        res = speech_synthesizer.speak_ssml_async(sentence['phrase_ssml_with_breaks']).get()
        my_converter.check_speech_result(res, f"SSML for sentences")
    
    ## trim or extend the audio to match the video duration
    logging.info(f'Trimming or extending the audio to match the video duration')
    my_converter.trim_or_extend_audio(
        audio_file_path=output_audio_filepath,
        target_duration=video_duration
    )
    
    ## upload the audio file to the blob storage
    blob_conn_string = os.environ['VIDEO_UPLOAD_STORAGE_CONN_STRING']
    container = os.environ['VIDEO_UPLOAD_STORAGE_CONTAINER']
    blob_service_client = BlobServiceClient.from_connection_string(blob_conn_string)

    logging.info(f'Uploading the audio file to blob storage: {output_audio_filename}')
    blob_client = blob_service_client.get_blob_client(container=container, blob=f"working-files/{video_id}/{output_audio_filename}")
    if not blob_client.exists():
        with open(output_audio_filepath, 'rb') as f:
            audio_bytes = f.read()
            blob_client.upload_blob(audio_bytes)

    ## upload the sentences list to the blob storage
    logging.info(f'Uploading the sentences list to blob storage: {video_id}_{language_code}_{language_voice}.json')
    blob_client = blob_service_client.get_blob_client(container=container, blob=f"working-files/{video_id}/{output_audio_filename}_sentences.json")
    if not blob_client.exists():
        blob_client.upload_blob(json.dumps(sentences_list, indent=4))

    return func.HttpResponse(body=json.dumps(sentences_list), status_code=200)