import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class SettingsStorage {
  static const _fileName = 'settings.json';

  static Future<File> _getSettingsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<void> saveSettings({
    required String resolution,
    required String path,
    required ThemeMode theme,
  }) async {
    final file = await _getSettingsFile();
    final data = {
      'resolution': resolution,
      'path': path,
      'theme': theme.name,
    };
    await file.writeAsString(jsonEncode(data));
  }


  Future<
      ({String resolution, String path, ThemeMode theme})?> loadSettings() async {
    try {
      // Получаем путь к файлу
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/settings.json');

      if (!await file.exists()) return null;

      final jsonString = await file.readAsString();
      final jsonMap = jsonDecode(jsonString);

      final resolution = jsonMap['resolution'] as String? ?? '1920x1080';
      final path = jsonMap['path'] as String? ?? '';
      final themeString = jsonMap['theme'] as String? ?? 'system';

      // Преобразуем строку в ThemeMode
      final theme = _themeModeFromString(themeString);

      // Возвращаем как запись
      return (resolution: resolution, path: path, theme: theme);
    } catch (e) {
      // В случае ошибки логируем и возвращаем null
      debugPrint('Ошибка при загрузке настроек: $e');
      return null;
    }
  }

  ThemeMode _themeModeFromString(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}

