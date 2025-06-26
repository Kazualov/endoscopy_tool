
import 'dart:async';

import 'package:endoscopy_tool/widgets/screenshot_button_widget.dart';
import 'package:endoscopy_tool/widgets/VoiceCommandService.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../main.dart';

class VoiceCommandHome extends StatefulWidget {
  @override
  _VoiceCommandHomeState createState() => _VoiceCommandHomeState();
}

class _VoiceCommandHomeState extends State<VoiceCommandHome> {
  final GlobalKey screenshotKey = GlobalKey();
  final GlobalKey<ScreenshotButtonState> screenshotButtonKey = GlobalKey();

  String _lastCommand = 'Ожидание...';
  StreamSubscription<String>? _commandSubscription;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    _commandSubscription = voiceService.commandStream.listen(
          (command) async {
        print('[LOG] Получена команда: $command');

        setState(() {
          _lastCommand = '✅ Команда: $command';
        });

        if (command == 'screenshot') {
          final state = screenshotButtonKey.currentState;
          if (state != null) {
            await state.captureAndSaveScreenshot(context);
          }
        }
        // можно расширить на другие команды
      },
      onError: (error) {
        print('[ERROR] Ошибка потока команд: $error');
        setState(() {
          _lastCommand = '❌ Ошибка: $error';
        });
      },
    );
  }

  @override
  void dispose() {
    _commandSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Голосовые команды')),
      body: Column(
        children: [
          RepaintBoundary(
            key: screenshotKey,
            child: Container(
              height: 200,
              color: Colors.amber,
              child: Center(child: Text('📸 Зона скриншота')),
            ),
          ),
          ScreenshotButton(
            key: screenshotButtonKey,
            screenshotKey: screenshotKey,
          ),
          SizedBox(height: 20),
          Text(_lastCommand, style: TextStyle(fontSize: 18)),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              // Принудительный перезапуск подключения для тестирования
              _commandSubscription?.cancel();
              _startListening();
            },
            child: Text('Переподключиться'),
          ),
        ],
      ),
    );
  }
}