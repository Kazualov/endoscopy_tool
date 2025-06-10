
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:endoscopy_tool/pages/main_page.dart';
import 'package:endoscopy_tool/pages/start_page.dart';
import 'package:endoscopy_tool/pages/video_player_widget.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget{
   MyApp({super.key});

  @override
  Widget build(BuildContext context){

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StartPage(),
      //home: MainPage()
    );
  }
}
