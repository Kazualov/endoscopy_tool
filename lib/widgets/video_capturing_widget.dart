import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:image/image.dart' as img;

// Импорты из оригинального кода
// import 'package:endoscopy_tool/widgets/screenshot_button_widget.dart';
// import '../modules/ApiService.dart';

/// Модель события фриза камеры
class FreezeEvent {
  final bool isFrozen;
  final Uint8List? screenshot;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const FreezeEvent({
    required this.isFrozen,
    this.screenshot,
    required this.timestamp,
    this.metadata,
  });

  String? get screenshotBase64 {
    if (screenshot == null) return null;
    return base64Encode(screenshot!);
  }

  int? get screenshotSize => screenshot?.length;

  @override
  String toString() {
    return 'FreezeEvent{isFrozen: $isFrozen, hasScreenshot: ${screenshot != null}, screenshotSize: ${screenshotSize ?? 0}, timestamp: $timestamp}';
  }
}

/// Детектор фризов камеры
class FreezeDetector {
  final double threshold;
  final Duration interval;

  bool _isRunning = false;
  bool? _lastFreezeState;
  Uint8List? _lastScreenshot;
  Uint8List? _previousFrame;

  final StreamController<FreezeEvent> _freezeStreamController =
  StreamController<FreezeEvent>.broadcast();

  FreezeDetector({
    this.threshold = 5.0,
    this.interval = const Duration(seconds: 1),
  });

  Stream<FreezeEvent> get freezeStream => _freezeStreamController.stream;
  bool get isRunning => _isRunning;
  Uint8List? get lastScreenshot => _lastScreenshot;
  bool? get lastFreezeState => _lastFreezeState;

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    print('Freeze detector started');
  }

  void stop() {
    _isRunning = false;
    print('Freeze detector stopped');
  }

  Future<void> processFrame(Uint8List frameBytes) async {
    if (!_isRunning) return;

    try {
      if (_previousFrame == null) {
        _previousFrame = frameBytes;
        return;
      }

      final bool isFrozen = await _isFrameFrozen(_previousFrame!, frameBytes);

      if (isFrozen != _lastFreezeState) {
        _lastFreezeState = isFrozen;

        if (isFrozen) {
          _lastScreenshot = frameBytes;
        } else {
          _lastScreenshot = null;
        }

        _freezeStreamController.add(FreezeEvent(
          isFrozen: isFrozen,
          screenshot: _lastScreenshot,
          timestamp: DateTime.now(),
          metadata: {
            'threshold': threshold,
            'frameSize': frameBytes.length,
          },
        ));
      }

      _previousFrame = frameBytes;

    } catch (e) {
      debugPrint('Error during freeze detection: $e');
    }
  }

  Future<bool> _isFrameFrozen(Uint8List frame1, Uint8List frame2) async {
    try {
      final img.Image? image1 = img.decodeImage(frame1);
      final img.Image? image2 = img.decodeImage(frame2);

      if (image1 == null || image2 == null) {
        return false;
      }

      final img.Image resized1 = img.copyResize(image1, width: 320, height: 240);
      final img.Image resized2 = img.copyResize(image2, width: 320, height: 240);

      int totalPixels = resized1.width * resized1.height;
      int differentPixels = 0;

      for (int y = 0; y < resized1.height; y++) {
        for (int x = 0; x < resized1.width; x++) {
          final pixel1 = resized1.getPixel(x, y);
          final pixel2 = resized2.getPixel(x, y);

          final rDiff = (pixel1.r - pixel2.r).abs();
          final gDiff = (pixel1.g - pixel2.g).abs();
          final bDiff = (pixel1.b - pixel2.b).abs();

          if (rDiff > 10 || gDiff > 10 || bDiff > 10) {
            differentPixels++;
          }
        }
      }

      final double percentDiff = (differentPixels / totalPixels) * 100;
      return percentDiff < threshold;

    } catch (e) {
      debugPrint('Error comparing frames: $e');
      return false;
    }
  }

  void dispose() {
    stop();
    _freezeStreamController.close();
  }
}

// Класс для хранения данных о детекции (из оригинального кода)
class DetectionBox {
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final String label;
  final double confidence;
  final Duration timestamp;

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
}

// CustomPainter для отрисовки прямоугольников детекции (из оригинального кода)
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

    final scaleX = size.width / videoSize.width;
    final scaleY = size.height / videoSize.height;

    for (var detection in detections) {
      final left = detection.x1 * scaleX;
      final top = detection.y1 * scaleY;
      final right = detection.x2 * scaleX;
      final bottom = detection.y2 * scaleY;

      final paint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final rect = Rect.fromLTRB(left, top, right, bottom);
      canvas.drawRect(rect, paint);

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

      final textOffset = Offset(
        left,
        (top - textPainter.height - 2).clamp(0, size.height - textPainter.height),
      );

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
  final Function(FreezeEvent)? onFreezeDetected; // Новый callback для фризов

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
    required this.screenshotKey,
    this.onFreezeDetected, // Добавляем callback
  });

  @override
  State<CameraStreamWidget> createState() => _CameraStreamWidgetState();
}

class _CameraStreamWidgetState extends State<CameraStreamWidget> {
  bool _isRecording = false;
  String? _outputPath;

  Timer? _frameTimer;
  Timer? _freezeDetectionTimer; // Отдельный таймер для детекции фризов
  bool _isDetectionProcessing = false;

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;

  String? _defaultSaveFolder;
  SharedPreferences? _prefs;
  String? _selectedVideoDeviceId;
  String? _selectedAudioDeviceId;

  // Переменные для детекции объектов
  WebSocketChannel? _webSocketChannel;
  List<DetectionBox> _currentDetections = [];
  List<DetectionBox> _allDetections = [];
  bool _isDetectionEnabled = false;
  DateTime? _recordingStartTime;

  // Переменные для детекции фризов
  late FreezeDetector _freezeDetector;
  StreamSubscription<FreezeEvent>? _freezeSubscription;
  bool _isFreezeDetectionEnabled = false;
  List<FreezeEvent> _freezeEvents = [];

  @override
  void initState() {
    super.initState();
    _initializeFreezeDetector();
    _initializeAsync();
  }

  void _initializeFreezeDetector() {
    _freezeDetector = FreezeDetector(
      threshold: 5.0,
      interval: Duration(milliseconds: 500), // Проверяем каждые 500мс
    );

    _freezeSubscription = _freezeDetector.freezeStream.listen((event) {
      print('Freeze event: $event');

      // Добавляем событие в список для последующего анализа
      _freezeEvents.add(event);

      // Вызываем callback если он предоставлен
      if (widget.onFreezeDetected != null) {
        widget.onFreezeDetected!(event);
      }

      // Сохраняем скриншот при фризе
      if (event.isFrozen && event.screenshot != null) {
        _handleFreezeScreenshot(event);
      }

      // Обновляем UI
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _handleFreezeScreenshot(FreezeEvent freezeEvent) async {
    try {
      print('Processing freeze screenshot: ${freezeEvent.screenshotSize} bytes');

      // Создаем папку для скриншотов фризов если её нет
      final appDir = await getApplicationDocumentsDirectory();
      final freezeScreenshotsDir = Directory('${appDir.path}/freeze_screenshots');
      if (!await freezeScreenshotsDir.exists()) {
        await freezeScreenshotsDir.create(recursive: true);
      }

      // Генерируем имя файла с timestamp
      final timestamp = freezeEvent.timestamp.millisecondsSinceEpoch;
      final fileName = 'freeze_${timestamp}.jpg';
      final filePath = '${freezeScreenshotsDir.path}/$fileName';

      // Сохраняем скриншот
      final file = File(filePath);
      await file.writeAsBytes(freezeEvent.screenshot!);

      print('Freeze screenshot saved: $filePath');

      // Можно добавить уведомление пользователю
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Freeze detected! Screenshot saved.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }

    } catch (e) {
      print('Error saving freeze screenshot: $e');
    }
  }

  void _toggleFreezeDetection() {
    setState(() {
      _isFreezeDetectionEnabled = !_isFreezeDetectionEnabled;

      if (_isFreezeDetectionEnabled) {
        _freezeDetector.start();
        _startFreezeDetectionTimer();
      } else {
        _freezeDetector.stop();
        _freezeDetectionTimer?.cancel();
        _freezeDetectionTimer = null;
      }
    });
  }

  void _startFreezeDetectionTimer() {
    _freezeDetectionTimer = Timer.periodic(
      _freezeDetector.interval,
          (timer) async {
        if (!_isFreezeDetectionEnabled ||
            _cameraController == null ||
            !_cameraController!.value.isInitialized) {
          return;
        }

        try {
          // Захватываем кадр для анализа фризов
          final image = await _cameraController!.takePicture();
          final bytes = await image.readAsBytes();
          await _freezeDetector.processFrame(bytes);

          // Удаляем временный файл
          await File(image.path).delete();
        } catch (e) {
          print('Error processing frame for freeze detection: $e');
        }
      },
    );
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

      _cameras = await availableCameras();
      print('Available cameras: ${_cameras.length}');

      if (_cameras.isNotEmpty) {
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

  Widget _buildCameraPreview() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final isFrontCamera = _cameras[_selectedCameraIndex].lensDirection == CameraLensDirection.front;

    return Transform(
      alignment: Alignment.center,
      transform: isFrontCamera ? Matrix4.rotationY(math.pi) : Matrix4.identity(),
      child: Stack(
        children: [
          CameraPreview(_cameraController!),
          // Overlay для детекций объектов
          if (_currentDetections.isNotEmpty)
            CustomPaint(
              painter: DetectionOverlayPainter(
                detections: _currentDetections,
                videoSize: Size(widget.videoWidth.toDouble(), widget.videoHeight.toDouble()),
              ),
              size: Size.infinite,
            ),
          // Индикатор фриза
          if (_freezeDetector.lastFreezeState == true)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pause, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'FREEZE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _connectToCameraStream(String examinationId) {
    try {
      _webSocketChannel = WebSocketChannel.connect(
        Uri.parse('ws://127.0.0.1:8000/ws/detect/$examinationId'),
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
            _isDetectionProcessing = false;
          });

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
                timestamp: relativeTime,
              );
              _allDetections.add(preciseDetection);
            }
          }
        } catch (e) {
          print('Error parsing detection data: $e');
          _isDetectionProcessing = false;
        }
      }, onError: (error) {
        print('WebSocket error: $error');
        _isDetectionProcessing = false;
      });

      _startFrameCapture();
    } catch (e) {
      print('Failed to connect to WebSocket: $e');
    }
  }

  void _startFrameCapture() {
    _frameTimer = Timer.periodic(Duration(milliseconds: 100), (timer) async {
      if (_isDetectionEnabled &&
          !_isDetectionProcessing &&
          _cameraController != null &&
          _cameraController!.value.isInitialized &&
          _webSocketChannel != null) {
        await _captureAndSendFrame();
      }
    });
  }

  Future<void> _captureAndSendFrame() async {
    try {
      _isDetectionProcessing = true;

      final XFile imageFile = await _cameraController!.takePicture();
      final Uint8List imageBytes = await imageFile.readAsBytes();

      final String base64Image = base64Encode(imageBytes);

      _webSocketChannel!.sink.add(jsonEncode({
        'image': base64Image,
      }));

      await File(imageFile.path).delete();
    } catch (e) {
      print('Error capturing and sending frame: $e');
      _isDetectionProcessing = false;
    }
  }

  void _toggleDetection() {
    setState(() {
      _isDetectionEnabled = !_isDetectionEnabled;
      if (!_isDetectionEnabled) {
        _currentDetections.clear();
        _isDetectionProcessing = false;
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

  Future<void> _startRecording() async {
    if (_isRecording || _cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (widget.startCaptured != null) {
      widget.startCaptured!();
    }

    _recordingStartTime = DateTime.now();
    _allDetections.clear();
    _freezeEvents.clear(); // Очищаем события фризов

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
    if (!_isRecording) return;

    try {
      final XFile videoFile = await _cameraController!.stopVideoRecording();
      setState(() => _isRecording = false);

      // Сохраняем видео с детекциями и информацией о фризах
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${_defaultSaveFolder ?? (await getApplicationDocumentsDirectory()).path}/video_$timestamp.mp4';

      await _processVideoWithMetadata(videoFile.path, outputPath);

      if (widget.onVideoCaptured != null) {
        widget.onVideoCaptured!(outputPath, _allDetections);
      }

      print('Recording stopped and saved: $outputPath');

    } catch (e) {
      print('Error stopping recording: $e');
      _showErrorSnackbar('Failed to stop recording: $e');
    }
  }

  Future<void> _processVideoWithMetadata(String inputPath, String outputPath) async {
    try {
      // Копируем видео
      await File(inputPath).copy(outputPath);

      // Сохраняем метаданные детекций
      if (_allDetections.isNotEmpty) {
        await _saveDetectionsMetadata(outputPath);
      }

      // Сохраняем информацию о фризах
      if (_freezeEvents.isNotEmpty) {
        await _saveFreezeMetadata(outputPath);
      }

      print('✅ Video saved with metadata');
    } catch (e) {
      print('❌ Error processing video: $e');
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

  Future<void> _saveFreezeMetadata(String videoPath) async {
    try {
      final metadataPath = videoPath.replaceAll('.mp4', '_freeze_events.json');
      final freezeData = _freezeEvents.map((event) => {
        'isFrozen': event.isFrozen,
        'timestamp': event.timestamp.millisecondsSinceEpoch,
        'hasScreenshot': event.screenshot != null,
        'screenshotSize': event.screenshotSize,
        'metadata': event.metadata,
      }).toList();

      await File(metadataPath).writeAsString(jsonEncode({
        'freezeEvents': freezeData,
        'totalFreezeEvents': _freezeEvents.length,
        'freezeThreshold': _freezeDetector.threshold,
      }));
      print('Freeze metadata saved to: $metadataPath');
    } catch (e) {
      print('Error saving freeze metadata: $e');
    }
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _freezeDetectionTimer?.cancel();
    _freezeSubscription?.cancel();
    _freezeDetector.dispose();
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
                              _buildCameraPreview()
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
                                      // Добавляем индикатор обработки
                                      if (_isDetectionEnabled && _isDetectionProcessing)
                                        SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      else
                                        Icon(
                                          _isDetectionEnabled ? Icons.visibility : Icons.visibility_off,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _isDetectionEnabled ?
                                        (_isDetectionProcessing ? 'AI...' : 'AI ON') : 'AI OFF',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}