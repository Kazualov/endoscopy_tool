import 'package:flutter/material.dart';
import 'package:endoscopy_tool/pages/main_page.dart';

void main() {
  runApp( MyApp());
}

class MyApp extends StatelessWidget{
   MyApp({super.key});

  @override
  Widget build(BuildContext context){

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainPage()
    );
  }
}
