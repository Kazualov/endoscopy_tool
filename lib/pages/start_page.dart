import 'package:endoscopy_tool/pages/patients.dart';
import 'package:endoscopy_tool/pages/video_recorder_page.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'package:endoscopy_tool/pages/main_page.dart';

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          toolbarHeight: 100,
          title: Text(
            "Добро пожаловать в инструмент для Эндоскопии",
            style: TextStyle(
              fontSize: 32,
              fontFamily: 'Nunito',
            ),
          ),
          backgroundColor: const Color(0xFF00ACAB),
        ),
        body: Column(
          children: [
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Загрузить видео
                  GestureDetector(
                    onTap: () async {
                      /*try {
                        final result = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: false);

                        if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
                          String path = result.files.single.path!;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MainPage(videoPath: path,),
                            ),
                          );
                        } else {
                          print("Video picking canceled or no file selected");
                        }
                      } catch (e) {
                        print("Error picking video: $e");
                      }*/
                      Navigator.push(context, MaterialPageRoute(builder: (context) => EndoscopistApp()));
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 300, horizontal: 10),
                      width: 300,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9D9D9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF00ACAB),
                          width: 5,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          "Загрузить видео",
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w400,
                            fontSize: 28,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Снять видео (не изменён)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => VideoRecorderPage()),);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                      width: 300,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9D9D9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF00ACAB),
                          width: 5,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          "Снять видео",
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w400,
                            fontSize: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
