import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
// Add this import

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
  });

  @override
  State<CameraStreamWidget> createState() => _CameraStreamWidgetState();
}

class _CameraStreamWidgetState extends State<CameraStreamWidget> {
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  MediaStream? _mediaStream;
  bool _isRecording = false;
  String? _outputPath;
  FFmpegSession? _ffmpegSession;

  List<MediaDeviceInfo> _videoDevices = [];
  List<MediaDeviceInfo> _audioDevices = [];
  String? _selectedVideoDeviceId;
  String? _selectedAudioDeviceId;
  String? _defaultSaveFolder;
  SharedPreferences? _prefs;

  // Добавляем переменные для детекции
  WebSocketChannel? _webSocketChannel;
  List<DetectionBox> _currentDetections = [];
  List<DetectionBox> _allDetections = [];
  bool _isDetectionEnabled = false;
  DateTime? _recordingStartTime;

  @override
  void initState() {
    super.initState();
    _initializeSettings();
    _listAvailableDevices();

    // Подключаемся к WebSocket если есть examination ID
    if (widget.examinationId != null) {
      _connectToCameraStream(widget.examinationId!);
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

  Future<void> _saveSettings() async {
    await _prefs?.setString('default_save_folder', _defaultSaveFolder ?? '');
    await _prefs?.setString('selected_video_device_id', _selectedVideoDeviceId ?? '');
    await _prefs?.setString('selected_audio_device_id', _selectedAudioDeviceId ?? '');
  }

  Future<void> _listAvailableDevices() async {
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      setState(() {
        _videoDevices = devices.where((device) => device.kind == 'videoinput').toList();
        _audioDevices = devices.where((device) => device.kind == 'audioinput').toList();

        if (_selectedVideoDeviceId == null && _videoDevices.isNotEmpty) {
          _selectedVideoDeviceId = _videoDevices.first.deviceId;
        }
        if (_selectedAudioDeviceId == null && _audioDevices.isNotEmpty) {
          _selectedAudioDeviceId = _audioDevices.first.deviceId;
        }
      });

      await Future.delayed(const Duration(milliseconds: 300));
      await _initializeCamera();
    } catch (e) {
      print('Error listing devices: $e');
      setState(() {
        _selectedVideoDeviceId = null;
        _selectedAudioDeviceId = null;
      });
      await _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    await _renderer.initialize();

    final constraints = {
      'audio': _selectedAudioDeviceId != null,
      'video': {
        'deviceId': _selectedVideoDeviceId,
        'width': widget.videoWidth,
        'height': widget.videoHeight,
        'frameRate': widget.frameRate,
      },
    };

    try {
      _mediaStream?.getTracks().forEach((track) => track.stop());
      final stream = await navigator.mediaDevices.getUserMedia(constraints);
      _renderer.srcObject = stream;
      setState(() => _mediaStream = stream);
    } catch (e) {
      print('Error accessing camera: $e');
      if (_selectedVideoDeviceId != null) {
        setState(() => _selectedVideoDeviceId = null);
        await _initializeCamera();
      }
    }
  }

  Future<String> _getTempOutputFilePath() async {
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/recording_$timestamp.mp4';
  }

  String? _getFFmpegVideoInput() {
    if (_selectedVideoDeviceId == null) return null;

    final device = _videoDevices.firstWhere(
          (d) => d.deviceId == _selectedVideoDeviceId,
      orElse: () => MediaDeviceInfo(deviceId: '', label: '', kind: '', groupId: ''),
    );

    if (Platform.isWindows) {
      return device.label;
    } else if (Platform.isMacOS) {
      for (int i = 0; i < _videoDevices.length; i++) {
        if (_videoDevices[i].deviceId == _selectedVideoDeviceId) {
          return i.toString();
        }
      }
    }

    return null;
  }

  // Also consider updating your _startRecording method for better Windows compatibility:

  Future<void> _startRecording() async {
    if (_isRecording) return;

    if (widget.startCaptured != null) {
      widget.startCaptured!();
    }

    // Save recording start time
    _recordingStartTime = DateTime.now();
    _allDetections.clear();

    final tempPath = await _getTempOutputFilePath();
    _outputPath = tempPath;

    final videoInput = _getFFmpegVideoInput();

    if (videoInput == null) {
      print("No valid FFmpeg-compatible camera input.");
      return;
    }

    // Improved Windows command with better compatibility
    final command = Platform.isMacOS
        ? '-f avfoundation -framerate ${widget.frameRate} '
        '-video_size ${widget.videoWidth}x${widget.videoHeight} '
        '-i "$videoInput" -c:v libx264 -preset ultrafast -crf 23 '
        '-pix_fmt yuv420p "$tempPath"'
        : '-f dshow -i video="$videoInput" -nostdin '
        '-hide_banner -loglevel error ' // Reduce verbose output on Windows
        '-c:v libx264 -preset ultrafast -crf 23 '
        '-r ${widget.frameRate} -y "$tempPath"'; // -y to overwrite existing files

    print('Running FFmpeg command:\n$command');

    setState(() => _isRecording = true);

    try {
      _ffmpegSession = await FFmpegKit.executeAsync(command, (session) async {
        final returnCode = await session.getReturnCode();
        print('FFmpeg finished with code: $returnCode');

        // Always update UI state
        if (mounted) {
          setState(() {
            _isRecording = false;
            _ffmpegSession = null;
          });
        }

        if (!File(tempPath).existsSync()) {
          print("⚠️ FFmpeg did not produce a file at: $tempPath");
          return;
        }

        print("✅ File created: $tempPath");

        // Check if recording was successful
        if (returnCode != null && (ReturnCode.isSuccess(returnCode) || returnCode.getValue() == 255)) {
          if (File(tempPath).existsSync()) {
            print('Saving captured recording...');
            await _saveRecordedFile(tempPath);
          } else {
            print('Temp file not found after capture.');
          }
        } else {
          print('Recording failed with code: $returnCode');
          try {
            if (File(tempPath).existsSync()) {
              await File(tempPath).delete();
            }
          } catch (e) {
            print('Delete failed: $e');
          }
        }
      });
    } catch (e) {
      print('❌ Error starting recording: $e');
      setState(() {
        _isRecording = false;
        _ffmpegSession = null;
      });
      _showErrorSnackbar('Failed to start recording: $e');
    }
  }

  // Replace your current _stopRecording method with this improved version:

  Future<void> _stopRecording() async {
    if (!_isRecording || _ffmpegSession == null) return;

    print('Stopping recording...');

    // Set recording state to false immediately to prevent UI issues
    setState(() {
      _isRecording = false;
    });

    try {
      final session = _ffmpegSession;
      _ffmpegSession = null;

      if (Platform.isWindows) {
        // Windows-specific approach
        print('Windows: Attempting to cancel FFmpeg session...');

        // Try to cancel the session first
        await session!.cancel();

        // Give FFmpeg time to process the cancel signal
        await Future.delayed(const Duration(milliseconds: 1500));

        // Force kill ffmpeg processes on Windows
        try {
          // Kill all ffmpeg.exe processes
          await Process.run('taskkill', ['/F', '/IM', 'ffmpeg.exe'], runInShell: true);
          print('✅ Windows: FFmpeg processes terminated');
        } catch (e) {
          print('⚠️ Windows: Could not kill ffmpeg processes: $e');
        }

        // Also try to kill any hanging processes
        try {
          await Process.run('taskkill', ['/F', '/IM', 'ffmpeg_kit_flutter.exe'], runInShell: true);
        } catch (e) {
          // Ignore this error as the process might not exist
        }

      } else if (Platform.isMacOS) {
        // macOS-specific approach
        print('macOS: Attempting to cancel FFmpeg session...');
        await session!.cancel();

        // Give some time for graceful shutdown
        await Future.delayed(const Duration(milliseconds: 500));

        // Optional: kill ffmpeg processes on macOS if needed
        try {
          await Process.run('pkill', ['-f', 'ffmpeg'], runInShell: true);
          print('✅ macOS: FFmpeg processes terminated');
        } catch (e) {
          print('⚠️ macOS: Could not kill ffmpeg processes: $e');
        }
      }

      print('✅ Recording stopped successfully');

    } catch (e) {
      print('❌ Error while stopping FFmpeg session: $e');

      // Fallback: Force kill on any platform
      if (Platform.isWindows) {
        try {
          await Process.run('taskkill', ['/F', '/IM', 'ffmpeg.exe'], runInShell: true);
        } catch (fallbackError) {
          print('❌ Fallback kill failed: $fallbackError');
        }
      } else {
        try {
          await Process.run('pkill', ['-f', 'ffmpeg'], runInShell: true);
        } catch (fallbackError) {
          print('❌ Fallback kill failed: $fallbackError');
        }
      }
    }

    // Ensure UI is updated
    if (mounted) {
      setState(() {
        _isRecording = false;
        _ffmpegSession = null;
      });
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

      print('Processing ${_allDetections.length} detections with precise timing...');

      // Сортируем детекции по времени
      _allDetections.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Рассчитываем продолжительность показа каждой детекции
      // Если детекции приходят каждые 3 кадра при 30 FPS, то это каждые 0.1 секунды
      final detectionDuration = 3.0 / widget.frameRate; // ~0.1 секунды для 30 FPS

      final allFilters = <String>[];

      // Создаем фильтры для каждой детекции с точным временем
      for (final detection in _allDetections) {
        final startTime = detection.timestamp.inMilliseconds / 1000.0;
        final endTime = startTime + detectionDuration;

        // Drawbox фильтр
        allFilters.add(detection.toFFmpegDrawbox(startTime: startTime, endTime: endTime));
        // Drawtext фильтр
        allFilters.add(detection.toFFmpegDrawtext(startTime: startTime, endTime: endTime));
      }

      final filterComplex = allFilters.join(',');
      final command = '-i "$inputPath" -vf "$filterComplex" -c:v libx264 -preset ultrafast -crf 23 -c:a copy "$outputPath"';

      print('Running FFmpeg command with ${allFilters.length} filters');
      print('Detection duration: ${detectionDuration}s');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        print('✅ Video with precise detections processed successfully');
      } else {
        final logs = await session.getFailStackTrace();
        print('❌ FFmpeg error (code ${returnCode?.getValue()}): $logs');

        // Fallback: try without text labels
        await _addDetectionsToVideoBoxesOnly(inputPath, outputPath);
      }
    } catch (e) {
      print('❌ Error in precise FFmpeg processing: $e');
      await File(inputPath).copy(outputPath);
      rethrow;
    }
  }

// Метод только с прямоугольниками (без текста) с точным временем
  Future<void> _addDetectionsToVideoBoxesOnly(String inputPath, String outputPath) async {
    try {
      print('Trying boxes-only approach with precise timing...');

      final detectionDuration = 3.0 / widget.frameRate;
      final boxFilters = <String>[];

      // Создаем только drawbox фильтры с точным временем
      for (final detection in _allDetections) {
        final startTime = detection.timestamp.inMilliseconds / 1000.0;
        final endTime = startTime + detectionDuration;

        boxFilters.add(detection.toFFmpegDrawbox(startTime: startTime, endTime: endTime));
      }

      final filterComplex = boxFilters.join(',');
      final command = '-i "$inputPath" -vf "$filterComplex" -c:v libx264 -preset ultrafast -crf 23 -c:a copy "$outputPath"';

      print('Running boxes-only FFmpeg command with precise timing');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        print('✅ Video with precise detection boxes processed successfully');
      } else {
        final logs = await session.getFailStackTrace();
        print('❌ Boxes-only FFmpeg error (code ${returnCode?.getValue()}): $logs');

        // Final fallback: save without detections
        await File(inputPath).copy(outputPath);
      }
    } catch (e) {
      print('❌ Error in boxes-only processing: $e');
      await File(inputPath).copy(outputPath);
      rethrow;
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
              const Text('Video Device:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButton<String>(
                isExpanded: true,
                value: _selectedVideoDeviceId,
                items: _videoDevices.map((device) {
                  return DropdownMenuItem(
                    value: device.deviceId,
                    child: Text(device.label.isNotEmpty ? device.label : 'Camera ${_videoDevices.indexOf(device) + 1}'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedVideoDeviceId = value);
                },
              ),
              const SizedBox(height: 10),

              const Text('Audio Device:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButton<String>(
                isExpanded: true,
                value: _selectedAudioDeviceId,
                items: _audioDevices.map((device) {
                  return DropdownMenuItem(
                    value: device.deviceId,
                    child: Text(device.label.isNotEmpty ? device.label : 'Microphone ${_audioDevices.indexOf(device) + 1}'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedAudioDeviceId = value);
                },
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
            onPressed: () {
              _saveSettings();
              _initializeCamera();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mediaStream?.getTracks().forEach((track) => track.stop());
    _renderer.dispose();
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
                        RTCVideoView(
                          _renderer,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
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