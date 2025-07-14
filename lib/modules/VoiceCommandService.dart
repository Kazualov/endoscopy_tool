import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final String _baseUrl = 'http://127.0.0.1:8000';
  StreamController<String>? _commandController;
  StreamController<String>? _transcriptController;
  Stream<String>? _commandStream;
  Stream<String>? _transcriptStream;
  http.Client? _client;
  bool _isListening = false;
  String _latestTranscript = '';
  String get latestTranscript => _latestTranscript;


  /// Поток для получения команд
  Stream<String> get commandStream {
    if (_commandStream == null) {
      _commandController = StreamController<String>.broadcast();
      _commandStream = _commandController!.stream;
      _startListeningIfNeeded();
    }
    return _commandStream!;
  }

  /// Поток для получения полного текста обследования
  Stream<String> get transcriptStream {
    if (_transcriptStream == null) {
      _transcriptController = StreamController<String>.broadcast();
      _transcriptStream = _transcriptController!.stream;
      _startListeningIfNeeded();
    }
    return _transcriptStream!;
  }

  void _startListeningIfNeeded() {
    if (!_isListening) {
      startListening();
    }
  }

  Future<void> startListening() async {
    if (_isListening) return;
    _isListening = true;

    try {
      _client = http.Client();
      final request = http.Request('GET', Uri.parse('$_baseUrl/voiceCommand'));
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';

      final response = await _client!.send(request);

      if (response.statusCode == 200) {
        print('[VoiceService] Подключение к SSE установлено');

        response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
            _handleSSELine(line);
          },
          onError: (error) {
            print('[VoiceService] Ошибка потока: $error');
            _commandController?.addError(error);
            _transcriptController?.addError(error);
            _reconnect();
          },
          onDone: () {
            print('[VoiceService] Поток завершен');
            _reconnect();
          },
        );
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('[VoiceService] Ошибка подключения: $e');
      _commandController?.addError(e);
      _transcriptController?.addError(e);
      _reconnect();
    }
  }

  void _handleSSELine(String line) {
    if (line.startsWith('data: ')) {
      try {
        final jsonData = line.substring(6); // Убираем "data: "
        final data = jsonDecode(jsonData);

        final type = data['type'] as String?;
        final command = data['command'] as String?;
        final text = data['text'] as String?;

        // Обрабатываем команды
        if (command != null && command != 'null') {
          print('[VoiceService] Получена команда: $command');
          _commandController?.add(command);
        }

        // Обрабатываем полный текст обследования
        if (type == 'transcript' && text != null) {
          print('[VoiceService] Получен полный текст обследования: ${text.length} символов');
          _latestTranscript = text; // сохраняем текст
          _transcriptController?.add(text);
        }


        // Обрабатываем heartbeat (для отладки)
        if (type == 'heartbeat') {
          print('[VoiceService] Heartbeat получен');
        }

      } catch (e) {
        print('[VoiceService] Ошибка парсинга JSON: $e');
      }
    }
  }

  void _reconnect() {
    if (!_isListening) return;

    print('[VoiceService] Переподключение через 1 секунду...');
    Future.delayed(const Duration(seconds: 1), () {
      if (_isListening) {
        print("[VoiceService] начинаю слушать заново");
        _isListening = false;
        startListening();
      }else{
        print("[VoiceService] все еще слушаем");
      }
    });
  }

  /// Принудительно остановить прослушивание
  void stopListening() {
    _isListening = false;
    _client?.close();
    print('[VoiceService] Прослушивание остановлено');
    _reconnect();
  }

  /// Полная очистка ресурсов
  void dispose() {
    _isListening = false;
    _client?.close();
    _commandController?.close();
    _transcriptController?.close();
    _commandController = null;
    _transcriptController = null;
    _commandStream = null;
    _transcriptStream = null;
  }
}

// Глобальный экземпляр сервиса
final voiceService = VoiceService();