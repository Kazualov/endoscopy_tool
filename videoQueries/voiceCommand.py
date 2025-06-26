from fastapi import APIRouter
from fastapi.responses import StreamingResponse
import sounddevice as sd
from vosk import Model, KaldiRecognizer
import queue
import json
import time

router = APIRouter()
SAMPLE_RATE = 16000
CHANNELS = 1
AUDIO_QUEUE = queue.Queue()
model = Model("vosk-model-small-ru-0.22")

recognizer = KaldiRecognizer(model, SAMPLE_RATE)

# Счетчик подключений
connection_count = 0

def audio_callback(indata, frames, time, status):
    AUDIO_QUEUE.put(bytes(indata))

def process_command(text):
    print(f"[COMMAND] Обрабатываем текст: '{text}'")

    if "старт" in text:
        print("[COMMAND] Команда: START")
        return "start"
    elif "стоп" in text:
        print("[COMMAND] Команда: STOP")
        return "stop"
    elif "сохранить" in text:
        print("[COMMAND] Команда: SAVE")
        return "save"
    elif "скриншот" in text:
        print("[COMMAND] Команда: SCREENSHOT")
        return "screenshot"

    print(f"[COMMAND] Неизвестная команда: '{text}'")
    return None

def voice_command_generator():
    global connection_count
    connection_count += 1
    client_id = connection_count

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
                try:
                    # Проверяем heartbeat
                    current_time = time.time()
                    if current_time - last_heartbeat > 5:
                        print(f"[SSE] Клиент #{client_id}: Отправляем heartbeat")
                        yield f"data: {json.dumps({'type': 'heartbeat', 'timestamp': current_time})}\n\n"
                        last_heartbeat = current_time

                    # Проверяем очередь аудио (с таймаутом)
                    try:
                        data = AUDIO_QUEUE.get(timeout=0.1)
                        print(f"[AUDIO] Клиент #{client_id}: Получены аудио данные ({len(data)} байт)")

                        if recognizer.AcceptWaveform(data):
                            result = json.loads(recognizer.Result())
                            text = result.get("text", "").lower()

                            if text:
                                print(f"[SPEECH] Клиент #{client_id}: Распознан текст: '{text}'")
                                command = process_command(text)

                                if command:
                                    message = json.dumps({'command': command, 'text': text})
                                    print(f"[SSE] Клиент #{client_id}: Отправляем команду: {message}")
                                    yield f"data: {message}\n\n"

                                    if command == "stop":
                                        print(f"[SSE] Клиент #{client_id}: Получена команда остановки")
                                        break
                                else:
                                    print(f"[SSE] Клиент #{client_id}: Текст не содержит команд")
                            else:
                                print(f"[SPEECH] Клиент #{client_id}: Пустой результат распознавания")
                        else:
                            # Промежуточный результат
                            partial = json.loads(recognizer.PartialResult())
                            partial_text = partial.get("partial", "")
                            if partial_text:
                                print(f"[SPEECH] Клиент #{client_id}: Промежуточный текст: '{partial_text}'")

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