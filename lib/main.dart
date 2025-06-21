
import 'package:endoscopy_tool/pages/main_page.dart';
import 'package:flutter/material.dart';

import 'package:endoscopy_tool/pages/patient_library.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget{
   const MyApp({super.key});

  @override
  Widget build(BuildContext context){

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      //home: MainPage(videoPath: '/Users/egornava/Downloads/2025-06-16-13-55-53 (online-video-cutter.com).mp4')
      home: EndoscopistApp(),
      //
      //home: StartPage()
    );
  }
}
