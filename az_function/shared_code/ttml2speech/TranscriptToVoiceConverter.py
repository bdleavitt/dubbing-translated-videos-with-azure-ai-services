from fnmatch import translate
import os
from time import strftime
from bs4 import BeautifulSoup
from datetime import datetime, timedelta
import json
import azure.cognitiveservices.speech as speechsdk
import wave
import contextlib
from xml.etree import ElementTree
import shutil
import logging
from pydub import AudioSegment


class TranscriptToVoiceConverter:
    def __init__(
        self,
        transcript=None,
        transcript_file_path=None,
        output_staging_directory=None,
        prefix="tts",
    ):
        self.speech_key = ""
        self.service_region = ""
        self.voice_name = ""
        self.voice_language = ""
        self.prefix = prefix
        self.target_audio_format = "Riff16Khz16BitMonoPcm"
        if transcript_file_path is not None:
            with open(transcript_file_path, "r", encoding="utf-8") as f:
                self.transcript = f.read()
        elif transcript is not None:
            self.transcript = transcript
        else:
            raise AttributeError(
                "You must provide either a file path or a string value for your TTML input."
            )

        if output_staging_directory is None:
            now_string = datetime.strftime(datetime.now(), "%Y%m%d_%H%M%S")
            self.output_staging_directory = os.path.join("outputs", now_string)
        else:
            self.output_staging_directory = os.path.join(
                "outputs", output_staging_directory
            )

        ## clear the staging directory and create it
        if os.path.exists(self.output_staging_directory):
            shutil.rmtree(self.output_staging_directory)

        os.makedirs(self.output_staging_directory)

        logging.warning(f"Output directory: {self.output_staging_directory}")

        ## Copy the starting TTML to the target directory
        new_ttml_path = os.path.join(
            "./", self.output_staging_directory, "starting_transcript.json"
        )
        with open(new_ttml_path, "w", encoding="utf-8") as f:
            f.write(json.dumps(self.transcript))

    def parse_phrases(self, transcript=None) -> list:

        if transcript == None:
            transcript = self.transcript

        for i in range(len(transcript)):

            start = transcript[i]["instances"][0]["start"]
            end = transcript[i]["instances"][0]["end"]

            if len(start) == 7:
                start = f"{start}.000"
            if len(end) == 7:
                end = f"{end}.000"

            transcript[i]["start"] = start
            transcript[i]["end"] = end
            transcript[i]["duration"] = (
                datetime.strptime(end, "%H:%M:%S.%f")
                - datetime.strptime(start, "%H:%M:%S.%f")
            ).total_seconds()

            removed = transcript[i].pop("instances", None)

        return transcript

    def pre_process_audio_snippets(
        self,
        sentences_list,
        clip_audio_directory="preprocessed",
        duration_key="translated_duration",
    ):

        temp_audio_folder_path = os.path.join(
            self.output_staging_directory, clip_audio_directory
        )
        os.makedirs(temp_audio_folder_path, exist_ok=True)

        for i, sentence in enumerate(sentences_list):

            filename = os.path.join(temp_audio_folder_path, f"{self.prefix}_{i}.wav")
            sentences_list[i]["audio_file"] = filename

            ## get the SSML for the sentence
            phrase_ssml = self.build_ssml(
                [sentence],
                insert_breaks=False,
                output_files=False
            )

            sentences_list[i]["phrase_ssml"] = phrase_ssml

            speech_synthesizer = self.get_speech_synthesizer(output_filename=filename)
            resp = speech_synthesizer.speak_ssml_async(phrase_ssml).get()

            ## self.check_speech_result(resp, phrase_ssml)

            if sentence["text"] == "":
                sentences_list[i][duration_key] = 0
                continue
            sentences_list[i][duration_key] = self.calculate_duration(filename)

        self.sentences_list = sentences_list
        return sentences_list

    def output_sentences_list(self, file_name):
        path = os.path.join(self.output_staging_directory, file_name)

        with open(path, "w", encoding="utf-8") as f:
            f.write(json.dumps(self.sentences_list, indent=4))

    def calculate_prosody_rates(
        self, sentences_list, method="sentence") -> float:

        ## Calculate a per-sentence prosody rate for any sentences that are longer than the combined
        ## duration of the original sentence and any subsequent gap before the next sentence. 
        
        if method == None:
            method = "sentence"
        
        if method == "sentence":
            logging.warning("Calculating prosody rates per sentence")
            for i, sentence in enumerate(sentences_list):
                if i < len(sentences_list) - 1:
                    sentence_duration = sentences_list[i]["duration"]
                    translated_duration = sentences_list[i]["translated_duration"]
                    current_start_time = datetime.strptime(sentences_list[i]["start"], "%H:%M:%S.%f")
                    current_end_time = datetime.strptime(sentences_list[i]["end"], "%H:%M:%S.%f")
                    next_start_time = datetime.strptime(sentences_list[i + 1]["start"], "%H:%M:%S.%f")

                    
                    translated_end_time = current_start_time + timedelta(seconds=translated_duration)

                    current_gap_to_next = (next_start_time - translated_end_time).total_seconds()                    
                    
                    if current_gap_to_next > 0:
                        needed_adjustment_secs = 0
                    else:
                        needed_adjustment_secs = current_gap_to_next

                    target_duration = translated_duration + needed_adjustment_secs
                    if target_duration == 0:
                        prosody_rate = 1
                    else:
                        prosody_rate = translated_duration / target_duration
                    
                    adjusted_end_time = current_start_time + timedelta(seconds=target_duration)

                    # adjusted_gap_after_phrase = (adjusted_end_time - next_start_time).total_seconds()
                    # sentences_list[i]["gap_to_next"] = adjusted_gap_after_phrase
                    sentences_list[i]["needed_adjustment"] = needed_adjustment_secs
                    sentences_list[i]["adjusted_duration"] = target_duration
                    sentences_list[i]["prosody_rate"] = prosody_rate
                    sentences_list[i]["adjusted_end_time"] = adjusted_end_time.strftime("%H:%M:%S.%f")
                else:
                    sentences_list[i]["adjusted_duration"] = sentences_list[i]["duration"]

        if method == "max":
            ## Ignore statements that are SHORTER than the original duration.
            sentences_to_adjust = [
                (
                    sentence["adjusted_duration"],
                    sentence["duration"],
                    sentence["adjusted_duration"] - sentence["duration"],
                )
                for sentence in sentences_list
                if sentence["adjusted_duration"] > sentence["duration"]
            ]
            ## Of the remaining statements, choose the one that is LONGEST difference.
            max_difference = max([sentence[2] for sentence in sentences_to_adjust])
            adjustment_tuple = [
                sentence
                for sentence in sentences_to_adjust
                if sentence[2] == max_difference
            ][0]
            ## Calculate the prosody rate based on the difference of the longest difference phrase.
            prosody_rate = adjustment_tuple[0] / adjustment_tuple[1]

            for i, sentence in enumerate(sentences_list):
                sentences_list[i]["prosody_rate"] = prosody_rate

        elif method == "avg":
            sentences_to_adjust = [
                (
                    sentence["adjusted_duration"],
                    sentence["duration"],
                    sentence["adjusted_duration"] - sentence["duration"],
                )
                for sentence in sentences_list
                if sentence["adjusted_duration"] > sentence["duration"]
            ]
            ## calculate the average of the prosody phrases
            prosody_rate = sum(
                [speed[0] / speed[1] for speed in sentences_to_adjust]
            ) / len(sentences_to_adjust)

            for i, sentence in enumerate(sentences_list):
                sentences_list[i]["prosody_rate"] = prosody_rate

        return sentences_list

    def calculate_breaks(self, sentences_list):
        ## calculate the prosody adjusted end time for each sentence
        for i in range(len(sentences_list)):
            start_time = datetime.strptime(sentences_list[i]["start"], "%H:%M:%S.%f")
            adjusted_duration = timedelta(
                seconds=sentences_list[i]["adjusted_duration"]
            )
            adjusted_end_time = start_time + adjusted_duration
            sentences_list[i]["adjusted_end_time"] = adjusted_end_time.strftime(
                "%H:%M:%S.%f"
            )

        ## calculate the preceding breaks for each sentence
        start_list = [sentence["start"] for sentence in sentences_list]
        end_list = [sentence["adjusted_end_time"] for sentence in sentences_list]
        end_list.insert(0, "00:00:00.000")

        zipObject = zip(start_list, end_list)

        differences_list = [
            (
                datetime.strptime(start, "%H:%M:%S.%f")
                - datetime.strptime(end, "%H:%M:%S.%f")
            ).total_seconds()
            for start, end in zipObject
        ]
        ## add the preceding breaks to the list
        for i in range(len(differences_list)):
            sentences_list[i]["pre_break_duration"] = differences_list[i]

        return sentences_list

    def calculate_duration(self, wave_filename):
        with contextlib.closing(wave.open(wave_filename, "rb")) as f:
            frames = f.getnframes()
            rate = f.getframerate()
            duration = frames / float(rate)

        return duration

    def generate_ssml_breaks(self, sentences_list) -> list:
        for i in range(len(sentences_list)):
            ## Insert the desired breaks into the SSML.
            phrase_ssml = sentences_list[i]["phrase_ssml"]
            root = ElementTree.XML(phrase_ssml)
            ElementTree.register_namespace("", "http://www.w3.org/2001/10/synthesis")
            prosody_tag = [
                tag for tag in root.iter("{http://www.w3.org/2001/10/synthesis}prosody")
            ][0]

            ## Insert the breaks
            max_break_length_in_sec = 5
            break_length_in_sec = sentences_list[i]["pre_break_duration"]
            num_full_breaks = int(break_length_in_sec // max_break_length_in_sec)
            remainder_break_length_in_sec = (
                break_length_in_sec % max_break_length_in_sec
            )

            if num_full_breaks == 0:
                break_list = [remainder_break_length_in_sec]
            else:
                break_list = [5] * num_full_breaks
                if remainder_break_length_in_sec > 0:
                    break_list.append(remainder_break_length_in_sec)

            for b in break_list:
                ## insert code to add a break here.
                brk_ms = int(b * 1000)
                brk = ElementTree.Element("break", attrib={"time": f"{brk_ms}"})
                prosody_tag.insert(0, brk)

            sentences_list[i]["phrase_ssml_with_breaks"] = ElementTree.tostring(
                root, encoding="unicode"
            )
        return sentences_list

    def build_ssml(
        self,
        sentences_list,
        insert_breaks=True,
        output_files=True,
        output_file_num=None,
        prosody_rate=1,
        file_start="00:00:00.000",
    ):
        
        if 'prosody_rate' in sentences_list[0].keys():
            prosody_rate = sentences_list[0]['prosody_rate']
        
        ## Build the ElementTree tree for SSML
        root = ElementTree.Element(
            "speak",
            attrib={
                "version": "1.0",
                "xmlns": "http://www.w3.org/2001/10/synthesis",
                "xml:lang": f"{self.voice_language}",
            },
        )
        voice_element = ElementTree.Element(
            "voice", attrib={"name": f"{self.voice_name}"}
        )
        root.append(voice_element)
        prosody_element = ElementTree.Element(
            "prosody", attrib={"rate": f"{prosody_rate}"}
        )
        voice_element.append(prosody_element)

        # latest_timestamp = datetime.strptime("00:00:00.000", "%H:%M:%S.%f")
        # next_timestamp = datetime.strptime("00:00:00.000", "%H:%M:%S.%f")
        accumulated_overage_time = 0

        ## Insert starting break
        if insert_breaks == True:
            file_start = datetime.strptime(file_start, "%H:%M:%S.%f")
            first_time_stamp = datetime.strptime(
                sentences_list[0]["start"], "%H:%M:%S.%f"
            )
            starting_break_sec = (first_time_stamp - file_start).total_seconds()

            ## Put any breaks that precede the sentence
            self.generate_ssml_breaks(prosody_element, starting_break_sec)

        ## for each sentence, generate the objects and corresponding breaks
        for sentence in sentences_list:
            ## Create the sentence
            # sentence_element = ElementTree.Element("s", attrib={"duration": str(int(sentence['actual_duration']*1000))})
            sentence_element = ElementTree.Element("s")
            sentence_element.text = sentence["text"]
            prosody_element.append(sentence_element)
            non_break_element = ElementTree.Element(
                "break", attrib={"strength": "none"}
            )
            prosody_element.append(non_break_element)

            if insert_breaks == True:
                ## Put any breaks needed after the sentence

                ### TODO!!! : change this to the difference between the calculated end of the translated and adjusted phrase and the NEXT sentences start time.
                ### maybe just go ahead and calculate this in the calculate_prosody function

                sentence_gap_in_sec = (
                    sentence["target_duration"] - sentence["actual_duration"]
                )
                if (
                    sentence_gap_in_sec >= 0
                ):  ## if the generated audio is shorter than the target audio

                    ## Add the appropriate filler gap, removing any accumulated overages
                    ## Ex sentence gap is 3.5 seconds
                    ## Accumulated gap is -7.5 seconds
                    ## break_duration = 3.5 seconds + -7.5 seconds = -4 seconds
                    break_duration = sentence_gap_in_sec + accumulated_overage_time

                    if break_duration > 0:
                        ## create breaks, zero out the accumulated time
                        self.generate_ssml_breaks(prosody_element, sentence_gap_in_sec)
                        accumulated_overage_time = 0
                    else:
                        ## otherwise, just update the accumulated overage time
                        ## skip creating a break
                        accumulated_overage_time = break_duration
                else:
                    accumulated_overage_time = +sentence_gap_in_sec

        ssml_string = str(
            ElementTree.tostring(root, encoding="utf-8"), encoding="utf-8"
        )

        ## output files
        if output_files == True:
            ssml_output_path = os.path.join(
                self.output_staging_directory, f"{output_file_num}_output_ssml.xml"
            )
            with open(ssml_output_path, "w", encoding="utf-8") as f:
                f.write(ssml_string)

        return ssml_string

    def check_speech_result(self, result, text):
        from azure.cognitiveservices.speech import ResultReason, CancellationReason

        if result.reason == ResultReason.SynthesizingAudioCompleted:
            logging.info("Speech synthesized for text [{}]".format(text))
        elif result.reason == ResultReason.Canceled:
            cancellation_details = result.cancellation_details
            logging.info(
                "Speech synthesis canceled: {}".format(cancellation_details.reason)
            )
            logging.info("Supplied text was ", text)
            if cancellation_details.reason == CancellationReason.Error:
                if cancellation_details.error_details:
                    logging.info(
                        "Error details: {}".format(cancellation_details.error_details)
                    )
            logging.info("Did you update the subscription info?")

    def get_speech_synthesizer(
        self, output_filename=None, speech_synthesis_output_format=None
    ):

        speech_config = speechsdk.SpeechConfig(
            subscription=self.speech_key, region=self.service_region
        )
        speech_config.speech_synthesis_language = self.voice_language
        speech_config.speech_synthesis_voice_name = self.voice_name

        ## TODO: take the output audio format as a parameter
        if not speech_synthesis_output_format:
            speech_config.set_speech_synthesis_output_format(
                speechsdk.SpeechSynthesisOutputFormat[self.target_audio_format]
            )
        else:
            speech_config.set_speech_synthesis_output_format(
                speechsdk.SpeechSynthesisOutputFormat[speech_synthesis_output_format]
            )

        if not output_filename:
            audio_filename = f"{self.voice_language}_generated_audio.mp3"
            output_filename = os.path.join(
                self.output_staging_directory, audio_filename
            )

        audio_config = speechsdk.audio.AudioConfig(filename=output_filename)

        speech_synthesizer = speechsdk.SpeechSynthesizer(
            speech_config=speech_config, audio_config=audio_config
        )
        speech_synthesizer
        return speech_synthesizer

    def get_synthesized_speech(
        self,
        text,
        voice_name,
        voice_language,
        output_filename,
        speech_key,
        service_region,
    ):
        speech_config = speechsdk.SpeechConfig(
            subscription=speech_key, region=service_region
        )
        speech_config.speech_synthesis_language = voice_language
        speech_config.speech_synthesis_voice_name = voice_name
        audio_config = speechsdk.AudioConfig(filename=output_filename)
        speech_synthesizer = speechsdk.SpeechSynthesizer(
            speech_config=speech_config, audio_config=audio_config
        )
        resp = speech_synthesizer.speak_text_async(text).get()
        self.check_speech_result(resp, text)

    def trim_or_extend_audio(self, audio_file_path, target_duration):
        song = AudioSegment.from_mp3(audio_file_path)
        video_length_milliseconds = int(target_duration * 1000)
        song_length_milliseconds = len(song)
        end_gap_length_milliseconds = (
            video_length_milliseconds - song_length_milliseconds
        )
        logging.info(
            f"Trimming or extending {audio_file_path} audio by {end_gap_length_milliseconds} milliseconds"
        )
        ending_slice = AudioSegment.silent(duration=end_gap_length_milliseconds)
        new_song = song + ending_slice
        exported_song = new_song.export(audio_file_path, format="mp3")
