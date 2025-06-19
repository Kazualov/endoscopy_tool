import 'package:flutter/services.dart';

class MacOSCameraRecorder {
  static const MethodChannel _channel = MethodChannel('camera_recorder');

  /// Запускает запись с камеры (на macOS).
  static Future<void> startRecording() async {
    try {
      await _channel.invokeMethod('startRecording');
    } on PlatformException catch (e) {
      print('Ошибка при запуске записи: ${e.message}');
    }
  }

  /// Останавливает запись и возвращает путь к видеофайлу.
  static Future<String?> stopRecording() async {
    try {
      final result = await _channel.invokeMethod<String>('stopRecording');
      return result;
    } on PlatformException catch (e) {
      print('Ошибка при остановке записи: ${e.message}');
      return null;
    }
  }
}
