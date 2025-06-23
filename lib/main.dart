import 'dart:io';
import 'package:endoscopy_tool/pages/start_page.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:endoscopy_tool/pages/screenShotsEditor.dart';

import 'package:endoscopy_tool/pages/patient_library.dart';

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
  //
  //launchMyExe();
  runApp(MyApp());
}

class MyApp extends StatelessWidget{
  MyApp({super.key});

  @override
  Widget build(BuildContext context){

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      //home: MainPage(videoPath: '/Users/ivan/Documents/Videos for project/videos/Bad Piggies Soundtrack | Building Contraptions | ABFT.mp4')
      //home: EndoscopistApp(),
      //home: StartPage()
      home: ScreenshotEditor(
        screenshot: FileImage(File("/Users/egornava/Pictures/screenshots/photo/Screenshot 2025-05-21 at 18.52.41.png")),
        otherScreenshots : [FileImage(File("/Users/egornava/Pictures/screenshots/photo/Screenshot 2025-05-21 at 18.52.41.png"))]));
  }
}
