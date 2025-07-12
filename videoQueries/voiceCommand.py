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


def get_model_path():
    if getattr(sys, 'frozen', False):
        base = os.path.dirname(sys.executable)
        return os.path.join(base, "_internal", "videoQueries", "vosk-model-small-ru-0.22")
    else:
        base = os.path.dirname(__file__)
        return os.path.join(base, "vosk-model-small-ru-0.22")


model = Model(get_model_path())
recognizer = KaldiRecognizer(model, SAMPLE_RATE)

# Счетчик подключений
connection_count = 0


def audio_callback(indata, frames, time, status):
    AUDIO_QUEUE.put(bytes(indata))


def process_command(text):
    #print(f"[COMMAND] Обрабатываем текст: '{text}'")

    if "старт" in text:
        #print("[COMMAND] Команда: START")
        return "start"
    elif "стоп" in text:
        #print("[COMMAND] Команда: STOP")
        return "stop"
    elif "сохранить" in text:
        #print("[COMMAND] Команда: SAVE")
        return "save"
    elif "скриншот" in text:
        #print("[COMMAND] Команда: SCREENSHOT")
        return "screenshot"
    elif "создать обследование" in text:
        #print("[COMMAND] Команда: EXEMINATION")
        return "exemination"
    elif ("завершить" in text) or ("завершить обследование" in text):
        return "exit"
    elif "выбрать камеру" in text:
        # print("[COMMAND] Команда: C")
        return "choose camera"
    elif "выбрать файл" in text:
        return "choose file"

    print(f"[COMMAND] Неизвестная команда: '{text}'")
    return None


def voice_command_generator():
    global connection_count
    connection_count += 1
    client_id = connection_count
    full_transcript = ""
    is_recording = False
    last_save_index = 0

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
                                    message = json.dumps({'command': "start", 'text': text})
                                    yield f"data: {message}\n\n"

                                elif command == "save":
                                    if is_recording:
                                        words = full_transcript.split()
                                        new_segment = " ".join(words[last_save_index:])
                                        last_save_index = len(words)
                                        message = json.dumps({'command': "save", 'text': new_segment})
                                        yield f"data: {message}\n\n"
                                    else:
                                        message = json.dumps({'command': "save", 'error': "Not recording"})
                                        yield f"data: {message}\n\n"

                                elif command == "exit":
                                    message = json.dumps({'command': "exit", 'text': full_transcript.strip()})
                                    yield f"data: {message}\n\n"
                                    break
                                elif command == "stop":
                                    is_recording = False
                                    message = json.dumps({'command': "stop", 'text': text})
                                    yield f"data: {message}\n\n"

                                else:
                                    # Накопление текста только если запись включена и это не команда
                                    if not command:
                                        if is_recording:
                                            full_transcript += text + " "
                                    # Отправляем команду, если она есть (например, стоп, скриншот и т.д.)
                                    if command:
                                        message = json.dumps({'command': command, 'text': text})
                                        yield f"data: {message}\n\n"

                        else:
                            partial = json.loads(recognizer.PartialResult())
                            partial_text = partial.get("partial", "")
                            if partial_text:
                                pass  # можно отправлять частичный текст, если нужно

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