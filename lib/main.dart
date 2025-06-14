
import 'package:flutter/material.dart';

import 'package:endoscopy_tool/pages/main_page.dart';
import 'package:endoscopy_tool/pages/start_page.dart';
import 'package:endoscopy_tool/widgets/video_player_widget.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget{
   MyApp({super.key});

  @override
  Widget build(BuildContext context){

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainPage(videoPath: '/Users/ivan/Documents/Flutter_Projects/endoscopy_tool/endoscopy_tool/assets/videos/strip.mp4')
      //home: StartPage(),
    );
  }
}
