import sounddevice as sd
from vosk import Model, KaldiRecognizer


# Настройки аудио
SAMPLE_RATE = 16000
CHANNELS = 1
AUDIO_QUEUE = queue.Queue()


# Загружаем модель Vosk
model = Model("vosk-model-small-ru-0.22")  # Путь к распакованной модели
recognizer = KaldiRecognizer(model, SAMPLE_RATE)


# Колбек для захвата аудио
def audio_callback1(indata, frames, time, status):
    if status:
        print("Ошибка аудиопотока: ", status)
    AUDIO_QUEUE.put(bytes(indata))


def process_command(text):
    if "старт" in text:
        print("Команда: Начать обследовани")
        # start_recording()
    elif "стоп" in text:
        print("Команда: Остановить обследовани")
        # stop_recording()
    elif "сохранить" in text:
        print("Команда: Сохранить данные")
        # save_data()
    elif "скриншот"  in text:
        print("команда: сделать снимок экрана")



# Запуск аудиопотока
with sd.RawInputStream(
    samplerate=SAMPLE_RATE,
    blocksize=8000,
    dtype="int16",
    channels=CHANNELS,
    callback=audio_callback1
):
    print("Слушаю команды... Нажмите Ctrl+С для выхода.")
    while True:
        data = AUDIO_QUEUE.get()
        if recognizer.AcceptWaveform(data):
            result = json.loads(recognizer.Result())
            text = result.get("text", "").lower()
            if text:
                print("Распознано:", text)
                process_command(text)  # Ваша функция обработки команд