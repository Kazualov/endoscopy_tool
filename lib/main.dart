import 'dart:io';
import 'package:endoscopy_tool/pages/screenShotsEditor.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'package:endoscopy_tool/pages/patient_library.dart';
import 'package:endoscopy_tool/widgets/VoiceCommandService.dart';

Future<void> launchMyExe() async {
  final exePath = 'endoscopy_tool/windows/runner/assets/backend_launcher/main.exe'; // relative to your app executable


  try {
    final process = await Process.start(exePath, []);
    // Optional: capture output
    process.stdout.transform(SystemEncoding().decoder).listen(print);
    process.stderr.transform(SystemEncoding().decoder).listen(print);
  } catch (e) {
    print('Failed to launch exe: $e');
  }
}

void main(){
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  // voiceService.startListening(); // запуск прослушивания при старте
  voiceService.startListening(); // запуск прослушивания при старте
  runApp(MyApp());
}

String path = "assets/img/demo0.jpg";

class MyApp extends StatelessWidget{
  MyApp({super.key});

  @override
  Widget build(BuildContext context){

    return MaterialApp(
      debugShowCheckedModeBanner: false,

      //home: MainPage(videoPath: '/Users/ivan/Documents/Videos for project/videos/Bad Piggies Soundtrack | Building Contraptions | ABFT.mp4')
      home: EndoscopistApp(),
      //home:ScreenshotEditor(screenshot: FileImage(File(path)), otherScreenshots: [FileImage(File(path)), FileImage(File(path)), FileImage(File(path))],)
      //
      //home: StartPage()
    );
  }
}
