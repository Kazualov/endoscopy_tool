
import 'package:endoscopy_tool/pages/start_page.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'package:endoscopy_tool/pages/patient_library.dart';
import 'package:endoscopy_tool/widgets/VoiceCommandService.dart';



void main(){
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  voiceService.startListening(); // запуск прослушивания при старте
  runApp(MyApp());
}

class MyApp extends StatelessWidget{
  MyApp({super.key});

  @override
  Widget build(BuildContext context){

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      //home: MainPage(videoPath: '/Users/ivan/Documents/Videos for project/videos/Bad Piggies Soundtrack | Building Contraptions | ABFT.mp4')
      home: EndoscopistApp(),
      //
      //home: StartPage()
    );
  }
}
