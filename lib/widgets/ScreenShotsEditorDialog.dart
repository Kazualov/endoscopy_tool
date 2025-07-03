import 'package:flutter/material.dart';
import 'package:endoscopy_tool/pages/screenShotsEditor.dart';

import '../pages/main_page.dart';
import 'ApiService.dart';

class ScreenShotsEditorDialog extends StatelessWidget {
  final ScreenshotItem screenshot;
  final List<ScreenshotItem> otherScreenshots;
  final String examinationId;
  final ApiService apiService;

  const ScreenShotsEditorDialog({
    super.key,
    required this.screenshot,
    required this.otherScreenshots,
    required this.examinationId,
    required this.apiService
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
              ScreenshotEditor(screenshot: screenshot, otherScreenshots: otherScreenshots, examinationId: examinationId, apiService: apiService,),

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
