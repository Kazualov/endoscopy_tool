import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class SettingsStorage {
  static const _fileName = 'settings.json';

  static Future<File> getSettingsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<void> saveSettings({
    required String resolution,
    required String path,
    required ThemeMode theme,
  }) async {
    final file = await getSettingsFile();
    final data = {
      'resolution': resolution,
      'path': path,
      'theme': theme.name,
    };
    await file.writeAsString(jsonEncode(data));
  }


  static Future<({String resolution, String path, ThemeMode theme})?> loadSettings() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/settings.json');

      if (!await file.exists()) return null;

      final jsonString = await file.readAsString();
      final jsonMap = jsonDecode(jsonString);

      final resolution = jsonMap['resolution'] as String? ?? '1920x1080';
      final path = jsonMap['path'] as String? ?? '';
      final themeString = jsonMap['theme'] as String? ?? 'system';
      final theme = _themeModeFromString(themeString);

      return (resolution: resolution, path: path, theme: theme);
    } catch (e) {
      debugPrint('Ошибка загрузки настроек: $e');
      return null;
    }
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
      default:
        return 'system';
    }
  }

  static ThemeMode _themeModeFromString(String value) {
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
