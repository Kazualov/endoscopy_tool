
import 'package:endoscopy_tool/pages/start_page.dart';
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
      //home: MainPage(videoPath: '/Users/ivan/Documents/Videos for project/videos/Bad Piggies Soundtrack | Building Contraptions | ABFT.mp4')
      home: EndoscopistApp(),
      //
      //home: StartPage()
    );
  }
}
