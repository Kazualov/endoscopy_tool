import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Add this import
import 'package:endoscopy_tool/widgets/screenshot_button_widget.dart';

import '../modules/ApiService.dart';

// Класс для хранения данных о детекции
class DetectionBox {
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final String label;
  final double confidence;
  final Duration timestamp; // Изменили DateTime на Duration

  DetectionBox({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.label,
    required this.confidence,
    required this.timestamp,
  });

  factory DetectionBox.fromJson(Map<String, dynamic> json) {
    // Функция для преобразования временной метки в Duration
    Duration parseTimestamp(dynamic timestamp) {
      if (timestamp is int) {
        return Duration(milliseconds: timestamp);
      } else if (timestamp is double) {
        return Duration(milliseconds: timestamp.toInt());
      } else if (timestamp is String) {
        try {
          return Duration(milliseconds: int.parse(timestamp));
        } catch (e) {
          return Duration.zero;
        }
      } else {
        return Duration.zero;
      }
    }

    return DetectionBox(
      x1: _toDouble(json['x1']),
      y1: _toDouble(json['y1']),
      x2: _toDouble(json['x2']),
      y2: _toDouble(json['y2']),
      label: json['label']?.toString() ?? '',
      confidence: _toDouble(json['confidence']),
      timestamp: parseTimestamp(json['timestamp']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // Метод для преобразования в команду drawbox FFmpeg с точным временем
  String toFFmpegDrawbox({double? startTime, double? endTime}) {
    final width = x2 - x1;
    final height = y2 - y1;
    String filter = "drawbox=x=${x1.toInt()}:y=${y1.toInt()}:w=${width.toInt()}:h=${height.toInt()}:color=red@0.5:thickness=3";
    if (startTime != null && endTime != null) {
      filter += ":enable='between(t,$startTime,$endTime)'";
    }
    return filter;
  }

// Метод для создания текстового фильтра с точным временем
  String toFFmpegDrawtext({double? startTime, double? endTime}) {
    String filter = "drawtext=text='$label ${(confidence * 100).toInt()}%':x=${x1.toInt()}:y=${(y1 - 20).toInt()}:fontsize=16:fontcolor=red:box=1:boxcolor=white@0.8";
    if (startTime != null && endTime != null) {
      filter += ":enable='between(t,$startTime,$endTime)'";
    }
    return filter;
  }
}

// CustomPainter для отрисовки прямоугольников детекции
class DetectionOverlayPainter extends CustomPainter {
  final List<DetectionBox> detections;
  final Size videoSize;

  DetectionOverlayPainter({
    required this.detections,
    required this.videoSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (detections.isEmpty || videoSize.width == 0 || videoSize.height == 0) return;

    // Вычисляем масштаб для преобразования координат
    final scaleX = size.width / videoSize.width;
    final scaleY = size.height / videoSize.height;

    for (var detection in detections) {
      // Преобразуем координаты
      final left = detection.x1 * scaleX;
      final top = detection.y1 * scaleY;
      final right = detection.x2 * scaleX;
      final bottom = detection.y2 * scaleY;

      // Рисуем прямоугольник
      final paint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final rect = Rect.fromLTRB(left, top, right, bottom);
      canvas.drawRect(rect, paint);

      // Рисуем подпись
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${detection.label} ${(detection.confidence * 100).toStringAsFixed(1)}%',
          style: const TextStyle(
            color: Colors.red,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      // Позиция для текста (над прямоугольником)
      final textOffset = Offset(
        left,
        (top - textPainter.height - 2).clamp(0, size.height - textPainter.height),
      );

      // Рисуем фон для текста
      final textBackgroundPaint = Paint()..color = Colors.white.withOpacity(0.8);
      canvas.drawRect(
        Rect.fromLTWH(
          textOffset.dx,
          textOffset.dy,
          textPainter.width,
          textPainter.height,
        ),
        textBackgroundPaint,
      );

      textPainter.paint(canvas, textOffset);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! DetectionOverlayPainter ||
        oldDelegate.detections != detections ||
        oldDelegate.videoSize != videoSize;
  }
}

class CameraStreamWidget extends StatefulWidget {
  final double? width;
  final double? height;
  final double aspectRatio;
  final int videoWidth;
  final int videoHeight;
  final int frameRate;
  final Function(String, List<DetectionBox>)? onVideoCaptured;
  final Function()? startCaptured;
  final String? examinationId;
  final GlobalKey screenshotKey;

  const CameraStreamWidget({
    super.key,
    this.width,
    this.height,
    this.aspectRatio = 16 / 9,
    this.videoWidth = 1280,
    this.videoHeight = 720,
    this.frameRate = 30,
    this.onVideoCaptured,
    this.startCaptured,
    this.examinationId,
    required this.screenshotKey, // Add this
  });

  @override
  State<CameraStreamWidget> createState() => _CameraStreamWidgetState();
}

class _CameraStreamWidgetState extends State<CameraStreamWidget> {

  bool _isRecording = false;
  String? _outputPath;

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;

  String? _defaultSaveFolder;
  SharedPreferences? _prefs;
  String? _selectedVideoDeviceId;
  String? _selectedAudioDeviceId;

  // Добавляем переменные для детекции
  WebSocketChannel? _webSocketChannel;
  List<DetectionBox> _currentDetections = [];
  List<DetectionBox> _allDetections = [];
  bool _isDetectionEnabled = false;
  DateTime? _recordingStartTime;

  @override
  void initState() {
    super.initState();
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    await _initializeSettings();
    await _initializeCameras();

    if (widget.examinationId != null) {
      _connectToCameraStream(widget.examinationId!);
    }
  }

  Future<void> _initializeCameras() async {
    try {
      // Сначала запрашиваем разрешения
      final cameraPermission = await Permission.camera.request();
      final microphonePermission = await Permission.microphone.request();

      if (cameraPermission != PermissionStatus.granted) {
        print('Camera permission denied');
        _showErrorSnackbar('Camera permission is required');
        return;
      }

      if (microphonePermission != PermissionStatus.granted) {
        print('Microphone permission denied');
        _showErrorSnackbar('Microphone permission is required');
        return;
      }

      // Получаем доступные камеры
      _cameras = await availableCameras();
      print('Available cameras: ${_cameras.length}');

      for (int i = 0; i < _cameras.length; i++) {
        print('Camera $i: ${_cameras[i].name} - ${_cameras[i].lensDirection}');
      }

      if (_cameras.isNotEmpty) {
        // Проверяем сохраненный индекс камеры
        final savedIndex = _prefs?.getInt('selected_camera_index') ?? 0;
        _selectedCameraIndex = savedIndex < _cameras.length ? savedIndex : 0;

        await _initializeCamera();
      } else {
        print('No cameras available');
        _showErrorSnackbar('No cameras found');
      }
    } catch (e) {
      print('Error initializing cameras: $e');
      _showErrorSnackbar('Error initializing cameras: $e');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      // Освобождаем предыдущий контроллер
      if (_cameraController != null) {
        await _cameraController!.dispose();
        _cameraController = null;
      }

      if (_cameras.isEmpty) {
        print('No cameras available for initialization');
        return;
      }

      print('Initializing camera ${_selectedCameraIndex}: ${_cameras[_selectedCameraIndex].name}');

      _cameraController = CameraController(
        _cameras[_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: true,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {});
        print('Camera initialized successfully');
      }
    } catch (e) {
      print('Error initializing camera: $e');
      _showErrorSnackbar('Error initializing camera: $e');
    }
  }

  // Обновленная функция подключения к WebSocket
  void _connectToCameraStream(String examinationId) {
    try {
      _webSocketChannel = WebSocketChannel.connect(
        Uri.parse('ws://127.0.0.1:8000/ws/camera/$examinationId'),
      );

      _webSocketChannel!.stream.listen((message) {
        try {
          final data = jsonDecode(message);
          final detections = data['detections'] as List<dynamic>? ?? [];

          final newDetections = detections
              .map((det) => DetectionBox.fromJson(det))
              .toList();

          setState(() {
            _currentDetections = newDetections;
          });

          // Сохраняем детекции с точным временем во время записи
          if (_isRecording && _recordingStartTime != null) {
            final currentTime = DateTime.now();
            final relativeTime = currentTime.difference(_recordingStartTime!);

            for (final detection in newDetections) {
              final preciseDetection = DetectionBox(
                x1: detection.x1,
                y1: detection.y1,
                x2: detection.x2,
                y2: detection.y2,
                label: detection.label,
                confidence: detection.confidence,
                timestamp: relativeTime, // Точное относительное время
              );
              _allDetections.add(preciseDetection);
            }
          }
        } catch (e) {
          print('Error parsing detection data: $e');
        }
      });
    } catch (e) {
      print('Failed to connect to WebSocket: $e');
    }
  }

  // Функция для переключения детекции
  void _toggleDetection() {
    setState(() {
      _isDetectionEnabled = !_isDetectionEnabled;
      if (!_isDetectionEnabled) {
        _currentDetections.clear();
      }
    });
  }

  Future<void> _initializeSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _defaultSaveFolder = _prefs?.getString('default_save_folder');
      _selectedVideoDeviceId = _prefs?.getString('selected_video_device_id');
      _selectedAudioDeviceId = _prefs?.getString('selected_audio_device_id');
    });
  }




  Future<String> _getTempOutputFilePath() async {
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/recording_$timestamp.mp4';
  }


  Future<void> _startRecording() async {
    if (_isRecording || _cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (widget.startCaptured != null) {
      widget.startCaptured!();
    }

    _recordingStartTime = DateTime.now();
    _allDetections.clear();

    try {
      await _cameraController!.startVideoRecording();
      setState(() => _isRecording = true);
      print('Recording started');
    } catch (e) {
      print('Error starting recording: $e');
      _showErrorSnackbar('Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || _cameraController == null) return;

    setState(() => _isRecording = false);

    try {
      final videoFile = await _cameraController!.stopVideoRecording();
      print('Recording stopped, file: ${videoFile.path}');

      await _saveRecordedFile(videoFile.path);
    } catch (e) {
      print('Error stopping recording: $e');
      _showErrorSnackbar('Failed to stop recording: $e');
    }
  }

  Future<void> _saveRecordedFile(String tempFilePath) async {
    try {
      // Проверяем существование файла
      final tempFile = File(tempFilePath);
      if (!await tempFile.exists()) {
        print('❌ Temp file does not exist: $tempFilePath');
        _showErrorSnackbar('Recording file not found');
        return;
      }

      // Получаем директорию для сохранения
      String? saveDir = _defaultSaveFolder;
      if (saveDir == null || saveDir.isEmpty) {
        saveDir = await FilePicker.platform.getDirectoryPath();
        if (saveDir == null || saveDir.isEmpty) {
          print('User cancelled folder selection');
          return;
        }
        await _prefs?.setString('default_save_folder', saveDir);
      }

      // Создаем имя файла
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'recording_$timestamp.mp4';
      final destination = path.join(saveDir, fileName);

      // Копируем файл с обработкой детекций
      try {
        if (_allDetections.isNotEmpty) {
          await _addDetectionsToVideo(tempFilePath, destination);
        } else {
          await tempFile.copy(destination);
        }

        print('✅ Video saved to: $destination');

        // Загружаем видео на сервер, если есть examinationId
        if (widget.examinationId != null) {
          await _uploadVideoToServer(destination);
        }

        if (widget.onVideoCaptured != null) {
          widget.onVideoCaptured!(destination, _allDetections);
        }

        _showSuccessSnackbar('Video saved successfully', saveDir);
      } catch (e) {
        print('❌ Error processing video: $e');
        _showErrorSnackbar('Error processing video: $e');
      }
    } catch (e) {
      print('❌ Failed to save recording: $e');
      _showErrorSnackbar('Failed to save recording: $e');
    } finally {
      _allDetections.clear();
    }
  }

  void _showSuccessSnackbar(String message, String? directory) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        action: directory != null ? SnackBarAction(
          label: 'Open Folder',
          onPressed: () => _openFolder(directory),
        ) : null,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _uploadVideoToServer(String filePath) async {
    if (widget.examinationId == null) return;

    try {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(width: 10),
              Text('Uploading video to server...'),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 30),
        ),
      );

      final videoId = await ApiService.uploadVideoToExamination(
        widget.examinationId!,
        filePath,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();

      if (videoId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload video'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ Error uploading video: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


// Основной метод для добавления детекций с точными временными метками
  Future<void> _addDetectionsToVideo(String inputPath, String outputPath) async {
    try {
      if (_allDetections.isEmpty) {
        await File(inputPath).copy(outputPath);
        return;
      }

      print('Processing ${_allDetections.length} detections...');

      // Для кроссплатформенной обработки можно использовать
      // простое копирование файла и отдельное сохранение метаданных детекций
      await File(inputPath).copy(outputPath);

      // Сохраняем детекции в отдельный JSON файл для последующей обработки
      await _saveDetectionsMetadata(outputPath);

      print('✅ Video saved with detection metadata');
    } catch (e) {
      print('❌ Error processing video: $e');
      await File(inputPath).copy(outputPath);
      rethrow;
    }
  }

  Future<void> _saveDetectionsMetadata(String videoPath) async {
    try {
      final metadataPath = videoPath.replaceAll('.mp4', '_detections.json');
      final detectionsData = _allDetections.map((detection) => {
        'x1': detection.x1,
        'y1': detection.y1,
        'x2': detection.x2,
        'y2': detection.y2,
        'label': detection.label,
        'confidence': detection.confidence,
        'timestamp': detection.timestamp.inMilliseconds,
      }).toList();

      await File(metadataPath).writeAsString(jsonEncode(detectionsData));
      print('Detection metadata saved to: $metadataPath');
    } catch (e) {
      print('Error saving detection metadata: $e');
    }
  }

// Метод для улучшения точности временных меток при записи
  void _recordDetectionWithPreciseTime(DetectionBox detection) {
    // Получаем текущее время записи относительно начала
    final recordingStart = _recordingStartTime; // Нужно добавить эту переменную
    final currentTime = DateTime.now();
    final relativeTime = currentTime.difference(recordingStart!);

    // Создаем детекцию с точным временем
    final preciseDetection = DetectionBox(
      x1: detection.x1,
      y1: detection.y1,
      x2: detection.x2,
      y2: detection.y2,
      label: detection.label,
      confidence: detection.confidence,
      timestamp: relativeTime, // Используем относительное время
    );

    if (_isRecording) {
      _allDetections.add(preciseDetection);
    }
  }

  Future<void> _openFolder(String folderPath) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', [folderPath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [folderPath]);
      }
    } catch (e) {
      print('Failed to open folder: $e');
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Camera:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _cameras.isEmpty
                  ? const Text('No cameras available')
                  : DropdownButton<int>(
                isExpanded: true,
                value: _selectedCameraIndex,
                items: _cameras.asMap().entries.map((entry) {
                  final camera = entry.value;
                  final direction = camera.lensDirection == CameraLensDirection.front
                      ? 'Front'
                      : camera.lensDirection == CameraLensDirection.back
                      ? 'Back'
                      : 'External';
                  return DropdownMenuItem<int>(
                    value: entry.key,
                    child: Text('${camera.name} ($direction)'),
                  );
                }).toList(),
                onChanged: (index) {
                  if (index != null) {
                    setState(() => _selectedCameraIndex = index);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Кнопка для повторного поиска камер
              ElevatedButton(
                onPressed: () async {
                  await _initializeCameras();
                  setState(() {});
                },
                child: const Text('Refresh Cameras'),
              ),
              const SizedBox(height: 16),

              const Text('Save Folder:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _defaultSaveFolder?.isNotEmpty == true
                          ? _defaultSaveFolder!
                          : 'Not set (will prompt when saving)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final folder = await FilePicker.platform.getDirectoryPath();
                      if (folder != null) {
                        setState(() => _defaultSaveFolder = folder);
                      }
                    },
                    child: const Text('Browse'),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _saveSettings();
              await _initializeCamera();
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    await _prefs?.setString('default_save_folder', _defaultSaveFolder ?? '');
    await _prefs?.setInt('selected_camera_index', _selectedCameraIndex);
  }

  Future<bool> _checkPermissions() async {
    final cameraStatus = await Permission.camera.status;
    final microphoneStatus = await Permission.microphone.status;

    return cameraStatus.isGranted && microphoneStatus.isGranted;
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _webSocketChannel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(
        children: [
          // Video preview с наложением детекции
          Expanded(
            flex: 1,
            child: RepaintBoundary(
              key: widget.screenshotKey,
              child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    maxHeight: widget.height != null ? widget.height! - 80 : double.infinity,
                  ),
                  child: AspectRatio(
                    aspectRatio: widget.aspectRatio,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            // Основное видео
                            if (_cameraController != null && _cameraController!.value.isInitialized)
                              CameraPreview(_cameraController!)
                            else
                              const Center(child: CircularProgressIndicator()),
                            // Наложение детекции
                            if (_isDetectionEnabled && _currentDetections.isNotEmpty)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: DetectionOverlayPainter(
                                    detections: _currentDetections,
                                    videoSize: Size(
                                      widget.videoWidth.toDouble(),
                                      widget.videoHeight.toDouble(),
                                    ),
                                  ),
                                ),
                              ),
                            // Индикатор статуса детекции
                            if (widget.examinationId != null)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _isDetectionEnabled ? Colors.green : Colors.grey,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _isDetectionEnabled ? Icons.visibility : Icons.visibility_off,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _isDetectionEnabled ? 'AI ON' : 'AI OFF',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ),
          ),
          const SizedBox(height: 8),
          // Элементы управления
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(_isRecording ? Icons.radio_button_checked : Icons.fiber_manual_record),
                    label: Text(_isRecording ? "Recording..." : "Start Recording"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRecording ? Color(0xFFD9D9D9) : Color(0xFF00ACAB),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 36),
                    ),
                    onPressed: _isRecording ? null : _startRecording,
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.stop),
                    label: const Text("Stop Recording"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade800,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 36),
                    ),
                    onPressed: _isRecording ? _stopRecording : null,
                  ),
                  const SizedBox(width: 12),
                  // Кнопка переключения детекции
                  if (widget.examinationId != null)
                    ElevatedButton.icon(
                      icon: Icon(_isDetectionEnabled ? Icons.visibility : Icons.visibility_off),
                      label: Text(_isDetectionEnabled ? "AI ON" : "AI OFF"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isDetectionEnabled ? Colors.green : Colors.grey,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(80, 36),
                      ),
                      onPressed: _toggleDetection,
                    ),
                  const SizedBox(width: 12),
                  IconButton(
                    color: Color(0xFF00ACAB),
                    icon: const Icon(Icons.settings),
                    onPressed: _showSettingsDialog,
                    tooltip: 'Settings',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}