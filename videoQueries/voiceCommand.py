from fastapi import APIRouter
from fastapi.responses import StreamingResponse
import sounddevice as sd
from vosk import Model, KaldiRecognizer
import queue
import json
import time
import os
import sys

router = APIRouter()
SAMPLE_RATE = 16000
CHANNELS = 1
AUDIO_QUEUE = queue.Queue()

# === Добавленные переменные ===
FULL_TRANSCRIPT = ""
force_stop = False

def get_model_path():
    if getattr(sys, 'frozen', False):
        base = os.path.dirname(sys.executable)
        return os.path.join(base, "_internal", "videoQueries", "vosk-model-small-ru-0.22")
    else:
        base = os.path.dirname(__file__)
        return os.path.join(base, "vosk-model-small-ru-0.22")

model = Model(get_model_path())
recognizer = KaldiRecognizer(model, SAMPLE_RATE)
connection_count = 0

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
    elif "создать обследование" in text:
        return "exemination"
    elif "выбрать камеру" in text:
        return "choose camera"
    elif "выбрать файл" in text:
        return "choose file"
    return None

def voice_command_generator():
    global connection_count, FULL_TRANSCRIPT, force_stop
    connection_count += 1
    client_id = connection_count
    full_transcript = ""
    is_recording = False
    last_save_index = 0
    force_stop = False

    print(f"[SSE] Новое подключение #{client_id}")
    last_heartbeat = time.time()

    try:
        with sd.RawInputStream(
            samplerate=SAMPLE_RATE,
            blocksize=8000,
            dtype="int16",
            channels=CHANNELS,
            callback=audio_callback
        ):
            print(f"[SSE] Клиент #{client_id}: Микрофон активирован")

            while True:
                if force_stop:
                    print(f"[SSE] Клиент #{client_id}: Принудительное завершение через getTranscript")
                    break
                try:
                    current_time = time.time()
                    if current_time - last_heartbeat > 5:
                        yield f"data: {json.dumps({'type': 'heartbeat', 'timestamp': current_time})}\n\n"
                        last_heartbeat = current_time

                    try:
                        data = AUDIO_QUEUE.get(timeout=0.1)

                        if recognizer.AcceptWaveform(data):
                            result = json.loads(recognizer.Result())
                            text = result.get("text", "").lower()

                            if text:
                                command = process_command(text)

                                if command == "start":
                                    is_recording = True
                                    full_transcript = ""
                                    last_save_index = 0
                                    yield f"data: {json.dumps({'command': 'start', 'text': text})}\n\n"

                                elif command == "save":
                                    if is_recording:
                                        words = full_transcript.split()
                                        new_segment = " ".join(words[last_save_index:])
                                        last_save_index = len(words)
                                        yield f"data: {json.dumps({'command': 'save', 'text': new_segment})}\n\n"
                                    else:
                                        yield f"data: {json.dumps({'command': 'save', 'error': 'Not recording'})}\n\n"

                                elif command == "stop":
                                    is_recording = False
                                    yield f"data: {json.dumps({'command': 'stop', 'text': text})}\n\n"

                                else:
                                    if not command and is_recording:
                                        full_transcript += text + " "
                                        FULL_TRANSCRIPT += text + " "
                                    if command:
                                        yield f"data: {json.dumps({'command': command, 'text': text})}\n\n"
                        else:
                            partial = json.loads(recognizer.PartialResult())
                            partial_text = partial.get("partial", "")
                    except queue.Empty:
                        continue

                except Exception as e:
                    print(f"[ERROR] Клиент #{client_id}: Ошибка в цикле: {e}")
                    break

    except Exception as e:
        print(f"[ERROR] Клиент #{client_id}: Ошибка микрофона: {e}")
    finally:
        print(f"[SSE] Клиент #{client_id}: Подключение закрыто")
        if full_transcript.strip():
            yield f"data: {json.dumps({'type': 'transcript', 'text': full_transcript.strip()})}\n\n"

@router.get("/voiceCommand")
def voice_command():
    print("[ENDPOINT] Новый запрос к /voiceCommand")
    return StreamingResponse(
        voice_command_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "*",
        }
    )

@router.get("/peekTranscript")
def peek_transcript():
    global FULL_TRANSCRIPT
    return {"transcript": FULL_TRANSCRIPT.strip()}

@router.get("/getTranscript")
def get_transcript():
    global FULL_TRANSCRIPT, force_stop
    force_stop = True
    transcript_to_return = FULL_TRANSCRIPT.strip()
    FULL_TRANSCRIPT = ""
    return {"transcript": transcript_to_return}
