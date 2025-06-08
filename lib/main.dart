import 'package:flutter/material.dart';
import 'package:endoscopy_tool/pages/main_page.dart';
import 'package:endoscopy_tool/pages/test.dart';

void main() {
  runApp( MyApp());
}

class MyApp extends StatelessWidget{
   MyApp({super.key});

  @override
  Widget build(BuildContext context){

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      //home: MainPage()
      home: Test()
    );
  }
}
