import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final String _baseUrl = 'http://127.0.0.1:8000';
  StreamController<String>? _commandController;
  Stream<String>? _commandStream;
  http.Client? _client;
  bool _isListening = false;

  Stream<String> get commandStream {
    if (_commandStream == null) {
      _commandController = StreamController<String>.broadcast();
      _commandStream = _commandController!.stream;
      startListening();
    }
    return _commandStream!;
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
      _reconnect();
    }
  }

  void _handleSSELine(String line) {
    if (line.startsWith('data: ')) {
      try {
        final jsonData = line.substring(6); // Убираем "data: "
        final data = jsonDecode(jsonData);
        final command = data['command'] as String?;

        if (command != null) {
          print('[VoiceService] Получена команда: $command');
          _commandController?.add(command);
        }
      } catch (e) {
        print('[VoiceService] Ошибка парсинга JSON: $e');
      }
    }
  }

  void _reconnect() {
    if (!_isListening) return;

    print('[VoiceService] Переподключение через 3 секунды...');
    Future.delayed(const Duration(seconds: 3), () {
      if (_isListening) {
        startListening();
      }
    });
  }

  void dispose() {
    _isListening = false;
    _client?.close();
    _commandController?.close();
    _commandController = null;
    _commandStream = null;
  }
}

// Глобальный экземпляр сервиса
final voiceService = VoiceService();