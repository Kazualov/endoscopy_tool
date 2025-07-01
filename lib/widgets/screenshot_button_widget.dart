import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'package:endoscopy_tool/widgets/SettingsStorage.dart';

class ScreenshotButton extends StatefulWidget {
  final GlobalKey screenshotKey;
  final Function(Uint8List)? onScreenshotTaken;
  final examId;

  const ScreenshotButton({
    super.key,
    required this.screenshotKey,
    required this.examId,
    this.onScreenshotTaken, // Опциональный параметр

  });

  @override
  ScreenshotButtonState createState() => ScreenshotButtonState();
}

class ScreenshotButtonState extends State<ScreenshotButton> {
  String? _savedFolderPath;

  Future<void> captureAndSaveScreenshot(BuildContext context) async {
    try {
      final boundary = widget.screenshotKey.currentContext!.findRenderObject()
      as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // Вызываем колбэк для добавления в панель (если он предоставлен)
      if (widget.onScreenshotTaken != null) {
        widget.onScreenshotTaken!(pngBytes);
      }

      final result = await SettingsStorage.loadSettings();
      String? path = result?.path;
      String examId = widget.examId;
      _savedFolderPath = "$path/$examId/screenshots";

      // Ask for folder only once
      if (_savedFolderPath == null) {
        final folderPath = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Select folder to save screenshots',
        );
        if (folderPath == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Screenshot added to timeline')),
          );
          return; // Не отменяем операцию, просто не сохраняем в файл
        }
        setState(() {
          _savedFolderPath = folderPath;
        });
      }

      // Save the file (опционально)
      if (_savedFolderPath != null) {
        final now = DateTime.now();
        final timestamp = "${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}";
        final filePath = '$_savedFolderPath/screenshot_$timestamp.png';

        final file = File(filePath);
        await file.writeAsBytes(pngBytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Screenshot added to timeline and saved to: $filePath')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to take screenshot: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      color: const Color(0xFF00ACAB),
      icon: const Icon(Icons.camera_alt),
      tooltip: 'Take Screenshot',
      onPressed: () => captureAndSaveScreenshot(context),
    );
  }
}
