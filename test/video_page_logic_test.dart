import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';

// Минимальные модели
enum VideoMode { uploaded, camera }

class ScreenshotItem {
  final String screenshotId;
  final String filename;
  final String filePath;
  final String timestampInVideo;
  final Uint8List imageBytes;

  ScreenshotItem({
    required this.screenshotId,
    required this.filename,
    required this.filePath,
    required this.timestampInVideo,
    required this.imageBytes,
  });
}

class ScreenshotMarker {
  final Duration timestamp;
  final String screenshotId;

  ScreenshotMarker({
    required this.timestamp,
    required this.screenshotId,
  });
}

// Обёртка для логики
class _TestWrapper {
  List<ScreenshotItem> screenshots = [];
  VideoMode mode = VideoMode.camera;
  Duration currentCameraDuration = Duration(minutes: 3, seconds: 7);
  Duration? uploadedVideoPosition;

  Duration parseDuration(String timeString) {
    final parts = timeString.split(":");
    final minutes = int.parse(parts[0]);
    final seconds = int.parse(parts[1]);
    return Duration(minutes: minutes, seconds: seconds);
  }

  List<ScreenshotMarker> getScreenshotMarkers() {
    return screenshots.map((screenshot) {
      return ScreenshotMarker(
        timestamp: parseDuration(screenshot.timestampInVideo),
        screenshotId: screenshot.screenshotId,
      );
    }).toList();
  }

  String getCurrentTimeCode() {
    if (mode == VideoMode.uploaded && uploadedVideoPosition != null) {
      final minutes = uploadedVideoPosition!.inMinutes;
      final seconds = uploadedVideoPosition!.inSeconds % 60;
      return "${minutes}:${seconds.toString().padLeft(2, '0')}";
    } else if (mode == VideoMode.camera) {
      final minutes = currentCameraDuration.inMinutes;
      final seconds = currentCameraDuration.inSeconds % 60;
      return "${minutes}:${seconds.toString().padLeft(2, '0')}";
    }
    return "0:00";
  }

  void onMarkerTap(Duration timestamp) {
    if (mode == VideoMode.uploaded && uploadedVideoPosition != null) {
      uploadedVideoPosition = timestamp; // эмуляция seek
    }
  }
}

void main() {
  group('Video logic unit tests', () {
    test('parseDuration parses "2:15" correctly', () {
      final logic = _TestWrapper();
      final duration = logic.parseDuration('2:15');
      expect(duration, Duration(minutes: 2, seconds: 15));
    });

    test('getScreenshotMarkers returns valid markers', () {
      final logic = _TestWrapper();
      logic.screenshots = [
        ScreenshotItem(
          screenshotId: '1',
          filename: 'screenshot1.png',
          filePath: '',
          timestampInVideo: '0:10',
          imageBytes: Uint8List(0),
        ),
        ScreenshotItem(
          screenshotId: '2',
          filename: 'screenshot2.png',
          filePath: '',
          timestampInVideo: '1:05',
          imageBytes: Uint8List(0),
        ),
      ];

      final markers = logic.getScreenshotMarkers();
      expect(markers.length, 2);
      expect(markers[0].timestamp, Duration(seconds: 10));
      expect(markers[1].timestamp, Duration(minutes: 1, seconds: 5));
    });

    test('getCurrentTimeCode (camera mode)', () {
      final logic = _TestWrapper();
      logic.mode = VideoMode.camera;
      final code = logic.getCurrentTimeCode();
      expect(code, '3:07');
    });

    test('getCurrentTimeCode (uploaded mode)', () {
      final logic = _TestWrapper();
      logic.mode = VideoMode.uploaded;
      logic.uploadedVideoPosition = Duration(minutes: 5, seconds: 2);
      final code = logic.getCurrentTimeCode();
      expect(code, '5:02');
    });

    test('onMarkerTap does not crash in camera mode', () {
      final logic = _TestWrapper();
      logic.mode = VideoMode.camera;
      logic.onMarkerTap(Duration(seconds: 10));
      expect(logic.uploadedVideoPosition, null); // не изменилось
    });
  });
}
