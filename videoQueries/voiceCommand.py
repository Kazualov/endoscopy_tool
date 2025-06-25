from fastapi import APIRouter
from fastapi.responses import StreamingResponse
import sounddevice as sd
from vosk import Model, KaldiRecognizer
import queue
import json

router = APIRouter()
SAMPLE_RATE = 16000
CHANNELS = 1
AUDIO_QUEUE = queue.Queue()
model = Model("vosk-model-small-ru-0.22")

recognizer = KaldiRecognizer(model, SAMPLE_RATE)


def audio_callback(indata, frames, time, status):
    AUDIO_QUEUE.put(bytes(indata))


def process_command(text):
    if "старт" in text:
        return "start"
    elif "стоп" in text:
        return "stop"
    elif "сохранить" in text:
        return "save"
    elif "скриншот" in text:
        return "screenshot"
    return None


def voice_command_generator():
    with sd.RawInputStream(
        samplerate=SAMPLE_RATE,
        blocksize=8000,
        dtype="int16",
        channels=CHANNELS,
        callback=audio_callback
    ):
        while True:
            data = AUDIO_QUEUE.get()
            if recognizer.AcceptWaveform(data):
                result = json.loads(recognizer.Result())
                text = result.get("text", "").lower()
                if text:
                    command = process_command(text)
                    if command:
                        yield f"data: {json.dumps({'command': command})}\n\n"
                        if command == "stop":
                            break


@router.get("/voiceCommand")
def voice_command():
    return StreamingResponse(voice_command_generator(), media_type="text/event-stream")
