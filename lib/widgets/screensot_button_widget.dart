import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ScreenshotButton extends StatelessWidget {
  final GlobalKey screenshotKey;

  const ScreenshotButton({super.key, required this.screenshotKey});

  Future<void> _captureAndSaveScreenshot(BuildContext context) async {
    try {
      final boundary = screenshotKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final now = DateTime.now();
      final timestamp = "${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}";

      final screenshotsDir = Directory("/Users/ivan/Documents/Flutter Projects/endoscopy_tool/endoscopy_tool/screenshots_by_doctor");
      if (!screenshotsDir.existsSync()) {
        screenshotsDir.createSync(recursive: true);
      }

      final file = File("${screenshotsDir.path}/screenshot_$timestamp.png");
      await file.writeAsBytes(pngBytes);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Screenshot saved to ${file.path}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed: $e")),
      );
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.camera_alt),
      onPressed: () => _captureAndSaveScreenshot(context),
    );
  }
}
