import 'dart:io';
import 'dart:convert';

import 'package:endoscopy_tool/pages/start_page.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'package:endoscopy_tool/pages/patient_library.dart';
import 'package:endoscopy_tool/widgets/VoiceCommandService.dart';

final voiceService = VoiceCommandService(); // глобальный экземпляр
late Process backendProcess;


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await startBackend(); // ← запуск main.exe
  voiceService.startListening();
  runApp(MyApp());
}

Future<void> startBackend() async {
  final exePath = Platform.isWindows
    ? '${Directory.current.path}\\dist\\main\\main.exe'
    : '${Directory.current.path}/dist/main/main';

  if (!Platform.isWindows) {
    await Process.run('chmod', ['+x', exePath]);
  }

  try {
    backendProcess = await Process.start(
      exePath,
      [],
      mode: ProcessStartMode.detachedWithStdio,
    );

    backendProcess.stdout.transform(utf8.decoder).listen((data) {
      print('[backend stdout] $data');
    });

    backendProcess.stderr.transform(utf8.decoder).listen((data) {
      print('[backend stderr] $data');
    });
  } catch (e) {
    print('Ошибка запуска backend: $e');
  }
}

Future<void> stopBackend() async {
  try {
    backendProcess.kill();
  } catch (e) {
    print('Ошибка завершения backend: $e');
  }
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void dispose() {
    stopBackend(); // ← завершение процесса
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: EndoscopistApp(),
    );
  }
}

