import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../modules/SettingsStorage.dart';


class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    super.key,
    required this.initialPath,
    required this.onSave,
  });

  /// Initial value for the folder‑path field.
  final String initialPath;
  final void Function(String path) onSave;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late final TextEditingController _resolutionCtl;
  late final TextEditingController _pathCtl;
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _pathCtl       = TextEditingController(text: widget.initialPath);
  }

  @override
  void dispose() {
    _resolutionCtl.dispose();
    _pathCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Выберите путь к папке',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // ── Folder path ───────────────────────────────────────────────────
            TextField(
              controller: _pathCtl,
              decoration: InputDecoration(
                labelText: 'Путь к папке',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Выбрать папку',
                  icon: const Icon(Icons.folder_open),
                  onPressed: () async {
                    final selectedDirectory = await FilePicker.platform.getDirectoryPath();
                    if (selectedDirectory != null) {
                      setState(() {
                        _pathCtl.text = selectedDirectory;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Action buttons ───────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    widget.onSave(
                      _pathCtl.text.trim(),
                    );
                    Navigator.of(context).pop();
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


Future<({String path})?> showSettingsDialog(BuildContext context) async {
  // Загружаем настройки из файла
  final saved = await SettingsStorage.loadSettings();

  // Значения по умолчанию, если файл отсутствует
  final path = saved?.path ?? '';

  // Сюда вернём результат
  ({String path})? result;

  // Показываем диалог с загруженными значениями
  await showDialog(
    context: context,
    builder: (ctx) => SettingsDialog(
      initialPath: path,
      onSave: (p) {
        result = (path: p);
        // Обязательно сохраняем новые настройки
        SettingsStorage.saveSettings(path: p);
      },
    ),
  );

  return result;
}
