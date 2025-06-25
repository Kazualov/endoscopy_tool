import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:stream_transform/stream_transform.dart';

class VoiceCommandService {
  final Uri uri = Uri.parse('http://127.0.0.1:8000/voiceCommand');
  final StreamController<String> _controller = StreamController.broadcast();
  bool _isConnected = false;

  Stream<String> get commandStream => _controller.stream;

  void startListening() async {
    if (_isConnected) return;
    _isConnected = true;

    final request = http.Request('GET', uri);
    final client = http.Client();
    final response = await client.send(request);

    if (response.statusCode != 200) {
      _controller.addError('Ошибка подключения: ${response.statusCode}');
      return;
    }

    final utf8Stream = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    try {
      await for (final line in utf8Stream) {
        if (line.startsWith("data:")) {
          final jsonString = line.replaceFirst("data:", "").trim();
          final data = jsonDecode(jsonString);
          final command = data['command'] as String;
          _controller.add(command);
        }
      }
    } catch (e) {
      _controller.addError('Ошибка обработки: $e');
    } finally {
      _isConnected = false;
      client.close();
      // Реконнект если нужно
      await Future.delayed(Duration(seconds: 1));
      startListening();
    }
  }

  void dispose() {
    _controller.close();
  }
}
