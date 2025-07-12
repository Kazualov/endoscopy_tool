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
    global connection_count, force_stop
    force_stop = False
    connection_count += 1
    client_id = connection_count
    full_transcript = ""

    print(f"[SSE] Новое подключение #{client_id}")

    # Отправляем heartbeat каждые 5 секунд
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
                global FULL_TRANSCRIPT
                if force_stop:
                    print(f"[SSE] Клиент #{client_id}: Принудительное завершение через getTranscript")
                    break
                try:
                    # Проверяем heartbeat
                    current_time = time.time()
                    if current_time - last_heartbeat > 5:
                        # print(f"[SSE] Клиент #{client_id}: Отправляем heartbeat")
                        yield f"data: {json.dumps({'type': 'heartbeat', 'timestamp': current_time})}\n\n"
                        last_heartbeat = current_time

                    # Проверяем очередь аудио (с таймаутом)
                    try:
                        data = AUDIO_QUEUE.get(timeout=0.1)
                        # print(f"[AUDIO] Клиент #{client_id}: Получены аудио данные ({len(data)} байт)")

                        if recognizer.AcceptWaveform(data):
                            result = json.loads(recognizer.Result())
                            text = result.get("text", "").lower()
                            if text and not process_command(text):
                                FULL_TRANSCRIPT += text + " "

                            if text:
                                # print(f"[SPEECH] Клиент #{client_id}: Распознан текст: '{text}'")
                                command = process_command(text)

                                if command == "exit":
                                    # message = json.dumps({'command': "exit", 'text': text})
                                    # yield f"data: {message}\n\n"
                                    pass
                                else:
                                    message = json.dumps({'command': command, 'text': text})
                                    # print(f"[SSE] Клиент #{client_id}: Отправляем команду: {message}")
                                    yield f"data: {message}\n\n"
                                    # print(f"[SSE] Клиент #{client_id}: Текст не содержит команд")
                            else:
                                pass
                                # print(f"[SPEECH] Клиент #{client_id}: Пустой результат распознавания")
                        else:
                            # Промежуточный результат
                            partial = json.loads(recognizer.PartialResult())
                            partial_text = partial.get("partial", "")
                            if partial_text:
                                pass
                                # print(f"[SPEECH] Клиент #{client_id}: Промежуточный текст: '{partial_text}'")

                    except queue.Empty:
                        # Нет новых аудио данных, продолжаем
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


@router.get("/getTranscript")
def get_transcript():
    global FULL_TRANSCRIPT, force_stop
    transcript_to_return = FULL_TRANSCRIPT.strip()
    FULL_TRANSCRIPT = ""  # Сброс после запроса
    force_stop = True
    return {"transcript": transcript_to_return}


@router.get("/peekTranscript")
def peek_transcript():
    global FULL_TRANSCRIPT
    return {"transcript": FULL_TRANSCRIPT.strip()}

