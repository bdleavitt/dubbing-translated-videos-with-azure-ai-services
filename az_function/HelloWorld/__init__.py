import logging
import platform, os, sys, stat
import azure.functions as func
from pydub import AudioSegment

def main(req: func.HttpRequest) -> func.HttpResponse:
    # try:
    #     with os.popen("sudo apt install ffmpeg") as f:
    #         install_message = f.readlines()
    # except Exception as e:
    #     logging.warning(e)

    with open("./never_gonna_give_you_up.mp3", 'rb') as f:
        audio = AudioSegment.from_file(f, format="mp3")
        audio.export("./never_gonna_give_you_up.wav", format="wav")
    

    return func.HttpResponse(
        f"{os.listdir()}"
    )