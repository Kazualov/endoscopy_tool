import 'package:flutter/material.dart';
import 'package:endoscopy_tool/pages/screenShotsEditor.dart';

class ScreenShotsEditorDialog extends StatelessWidget {
  final ImageProvider screenshot;
  final List<ImageProvider> otherScreenshots;
  const ScreenShotsEditorDialog({
    super.key,
    required this.screenshot,
    required this.otherScreenshots,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: SizedBox.expand(
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              ScreenshotEditor(screenshot: screenshot, otherScreenshots: otherScreenshots,),

              // Кнопка "назад"
              Positioned(
                top: 16,
                left: 16,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
