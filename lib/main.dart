import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:endoscopy_tool/pages/patient_library.dart';
import 'package:endoscopy_tool/modules/VoiceCommandService.dart';

late Process backendProcess;                    // <-- добавлена переменная для процесса бэкенда

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  await startBackend();             // <-- запускаем бэкенд перед startListening и runApp
  voiceService.startListening();    // запуск сервиса голосовых команд

  runApp(const MyApp());           // запускаем Flutter-приложение
}

Future<void> startBackend() async {
  final exePath = Platform.isWindows
      ? '${Directory.current.path}${Platform.pathSeparator}dist${Platform.pathSeparator}main${Platform.pathSeparator}main.exe'
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
    print('❌ Ошибка запуска backend: $e');
  }
}


/// Функция корректного завершения процесса бэкенда
Future<void> stopBackend() async {
  try {
    backendProcess.kill();        // <-- убиваем процесс при закрытии приложения
    print('Backend stopped.');
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
    stopBackend();                // <-- останавливаем бэкенд в момент dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: EndoscopistApp(),     // основной экран
    );
  }
}
