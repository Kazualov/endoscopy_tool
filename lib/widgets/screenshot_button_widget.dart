import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';

class ScreenshotButton extends StatefulWidget {
  final GlobalKey screenshotKey;

  const ScreenshotButton({super.key, required this.screenshotKey});

  @override
  State<ScreenshotButton> createState() => _ScreenshotButtonState();
}

class _ScreenshotButtonState extends State<ScreenshotButton> {
  String? _savedFolderPath;

  Future<void> _captureAndSaveScreenshot(BuildContext context) async {
    try {
      // Capture screenshot
      final boundary = widget.screenshotKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // Ask for folder only once
      if (_savedFolderPath == null) {
        final folderPath = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Select folder to save screenshots',
        );

        if (folderPath == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Screenshot cancelled')),
          );
          return;
        }

        setState(() {
          _savedFolderPath = folderPath;
        });
      }

      // Save the file
      final now = DateTime.now();
      final timestamp = "${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}";
      final filePath = '$_savedFolderPath/screenshot_$timestamp.png';

      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to: $filePath')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save screenshot: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      color: Color(0xFF00ACAB),
      icon: const Icon(Icons.camera_alt),
      tooltip: 'Take Screenshot',
      onPressed: () => _captureAndSaveScreenshot(context),
    );
  }
}
