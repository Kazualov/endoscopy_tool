import 'package:flutter/material.dart';

import '../widgets/SettingsStorage.dart';


class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    super.key,
    required this.initialResolution,
    required this.initialPath,
    required this.initialTheme,
    required this.onSave,
  });

  /// Initial value for the resolution field.
  final String initialResolution;

  /// Initial value for the folder‑path field.
  final String initialPath;

  /// Initial theme selection.
  final ThemeMode initialTheme;

  /// Called when the user presses **Save**.
  ///
  /// Parameters returned in order:
  ///  * `resolution` — String the user entered (e.g. "1280x720").
  ///  * `path`       — Folder path string.
  ///  * `theme`      — The chosen [ThemeMode].
  final void Function(String resolution, String path, ThemeMode theme) onSave;

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
    _resolutionCtl = TextEditingController(text: widget.initialResolution);
    _pathCtl       = TextEditingController(text: widget.initialPath);
    _themeMode     = widget.initialTheme;
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
              'Настройки',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // ── Resolution ────────────────────────────────────────────────────
            TextField(
              controller: _resolutionCtl,
              decoration: const InputDecoration(
                labelText: 'Разрешение (например 1920x1080)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

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
                    // TODO: Integrate a folder‑picker such as `file_picker`.
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Theme selection ──────────────────────────────────────────────
            DropdownButtonFormField<ThemeMode>(
              value: _themeMode,
              decoration: const InputDecoration(
                labelText: 'Тема интерфейса',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text('Светлая'),
                ),
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Text('Тёмная'),
                ),
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('Системная'),
                ),
              ],
              onChanged: (value) => setState(() => _themeMode = value ?? ThemeMode.system),
            ),
            const SizedBox(height: 24),

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
                      _resolutionCtl.text.trim(),
                      _pathCtl.text.trim(),
                      _themeMode,
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


Future<({String resolution, String path, ThemeMode theme})?> showSettingsDialog(BuildContext context) async {
  // Загружаем настройки из файла
  final saved = await SettingsStorage.loadSettings();

  // Значения по умолчанию, если файл отсутствует
  final resolution = saved?.resolution ?? '1920x1080';
  final path = saved?.path ?? '';
  final theme = saved?.theme ?? ThemeMode.system;

  // Сюда вернём результат
  ({String resolution, String path, ThemeMode theme})? result;

  // Показываем диалог с загруженными значениями
  await showDialog(
    context: context,
    builder: (ctx) => SettingsDialog(
      initialResolution: resolution,
      initialPath: path,
      initialTheme: theme,
      onSave: (res, p, t) {
        result = (resolution: res, path: p, theme: t);
        // Обязательно сохраняем новые настройки
        SettingsStorage.saveSettings(resolution: res, path: p, theme: t);
      },
    ),
  );

  return result;
}
