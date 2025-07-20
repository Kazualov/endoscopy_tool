import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class SettingsStorage {
  static const _fileName = 'settings.json';

  static Future<File> getSettingsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<void> saveSettings({
    required String path,
  }) async {
    final file = await getSettingsFile();
    final data = {
      'path': path,
    };
    await file.writeAsString(jsonEncode(data));
  }


  static Future<({String path})?> loadSettings() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'settings.json'));

      if (!await file.exists()) return null;

      final jsonString = await file.readAsString();
      final jsonMap = jsonDecode(jsonString);

      var path = jsonMap['path'] as String? ?? '';

      // Удаляем последнюю папку из пути
      path = p.dirname(path);

      return (path: path);
    } catch (e) {
      debugPrint('Ошибка загрузки настроек: $e');
      return null;
    }
  }
}
