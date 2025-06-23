import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';

import 'package:endoscopy_tool/pages/screenShotsEditor.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final GlobalKey<ScreenshotEditorState> editorKey = GlobalKey<ScreenshotEditorState>();

  @override
  Widget build(BuildContext context) {
    final screenshotFile = File("/Users/egornava/Pictures/screenshots/photo/Screenshot 2025-05-21 at 18.52.41.png");

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Stack(
          children: [
            ScreenshotEditor(
              key: editorKey,
              screenshot: FileImage(screenshotFile),
              otherScreenshots: [FileImage(screenshotFile)],
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                onPressed: () async {
                  final path = await editorKey.currentState?.save();
                  if (path != null) {
                    print('Сохранено в: $path');
                    ScaffoldMessenger.of(editorKey.currentContext!).showSnackBar(
                      SnackBar(content: Text('Сохранено: $path')),
                    );
                  }
                },
                child: const Icon(Icons.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
