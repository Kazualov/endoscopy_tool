import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:endoscopy_tool/modules/ApiService.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

import 'package:endoscopy_tool/pages/patient_library.dart';
import 'package:endoscopy_tool/widgets/screenshot_button_widget.dart';
import 'package:endoscopy_tool/widgets/video_capturing_widget.dart';
import '../modules/detection_models.dart';
import '../modules/VoiceCommandService.dart';
import '../widgets/ScreenShotsEditorDialog.dart';
import '../widgets/video_player_widget.dart';

// Enum to define different video modes
enum VideoMode {
  uploaded,    // Video uploaded from file
  camera       // Live camera capture
}

// Модель для хранения данных скриншота
class ScreenshotItem {
  final String screenshotId;
  final String filename;
  final String filePath;
  final String timestampInVideo; // Формат: "mm:ss.mmm"
  final Duration timestampDuration; // Точное время в миллисекундах
  final Uint8List? imageBytes;

  ScreenshotItem({
    required this.screenshotId,
    required this.filename,
    required this.filePath,
    required this.timestampInVideo,
    required this.timestampDuration,
    this.imageBytes,
  });

  // Фабричный метод для создания из JSON
  factory ScreenshotItem.fromJson(Map<String, dynamic> json) {
    final timestampStr = json['timestamp_in_video'] ?? '0:00.000';
    final timestampDuration = _parseDurationWithMs(timestampStr);

    return ScreenshotItem(
      screenshotId: json['screenshot_id'].toString(),
      filename: json['filename'] ?? '',
      filePath: json['file_path'] ?? '',
      timestampInVideo: timestampStr,
      timestampDuration: timestampDuration,
    );
  }

  // Статический метод для парсинга времени с миллисекундами
  static Duration _parseDurationWithMs(String timeString) {
    final parts = timeString.split(':');
    if (parts.length != 2) return Duration.zero;

    final minutes = int.tryParse(parts[0]) ?? 0;
    final secondsAndMs = parts[1].split('.');
    final seconds = int.tryParse(secondsAndMs[0]) ?? 0;
    final milliseconds = secondsAndMs.length > 1 ? int.tryParse(secondsAndMs[1]) ?? 0 : 0;

    return Duration(minutes: minutes, seconds: seconds, milliseconds: milliseconds);
  }
}


class DetectionSegmentMarker {
  final Duration startTime;
  final Duration endTime;
  final String label;
  final double confidence;
  final int detectionCount;
  final String type;

  DetectionSegmentMarker({
    required this.startTime,
    required this.endTime,
    required this.label,
    required this.confidence,
    required this.detectionCount,
    required this.type,
  });
}

class MainPage extends StatelessWidget {
  final String? videoPath;
  final VideoMode initialMode;
  final String? examinationId;

  const MainPage({
    super.key,
    this.videoPath,
    this.initialMode = VideoMode.camera,
    this.examinationId,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainPageLayout(
        videoPath: videoPath,
        initialMode: initialMode,
        examinationId: examinationId,
      ),
    );
  }
}

class MainPageLayout extends StatefulWidget {
  final String? videoPath;
  final VideoMode initialMode;
  final String? examinationId;

  const MainPageLayout({
    super.key,
    this.videoPath,
    this.initialMode = VideoMode.camera,
    this.examinationId,
  });

  @override
  _MainPageLayoutState createState() => _MainPageLayoutState();
}

class _MainPageLayoutState extends State<MainPageLayout> {
  final GlobalKey _screenshotKey = GlobalKey();
  final GlobalKey<ScreenshotButtonState> screenshotButtonKey = GlobalKey();

  //Flag to trigger vosk
  bool flag = false;

  File? _convertedFile;
  bool _isLoading = false;
  String? _loadingMessage;

  // Константы для API
  static const String BASE_URL = 'http://127.0.0.1:8000';

  // Параметры видео для покадровой навигации
  double _videoFps = 10.0; // FPS по умолчанию
  Duration get _frameStep => Duration(milliseconds: (1000 / _videoFps).round());

  // Screenshot management
  List<ScreenshotItem> screenshots = [];
  List<DetectionBox> _allDetections = [];
  List<DetectionSegment> _detectionSegments = [];

  // Video mode state
  late VideoMode _currentMode;
  String? _currentVideoPath;

  // Video player components (only used in uploaded mode)
  Player? _player;
  VideoController? _videoController;

  // Camera timer for live streaming
  Timer? _cameraTimer;
  DateTime? _cameraStartTime;
  Duration _currentCameraDuration = Duration.zero;

  // Добавить после других переменных состояния
  String? _fullTranscript; // Для хранения полной расшифровки
  StreamSubscription<
      String>? _transcriptSubscription; // Подписка на транскрипцию
  String? transcript;

  // Voice command subscription
  StreamSubscription<String>? _voiceSubscription;

  @override
  void initState() {
    super.initState();
    // Set initial mode from constructor
    _currentMode = widget.initialMode;
    _currentVideoPath = widget.videoPath;

    // Initialize voice command subscription
    _voiceSubscription = voiceService.commandStream.listen((command) {
      print('[MainPageLayout] 🎤 Получена команда: $command');

      if ((command.toLowerCase().contains('скриншот') ||
          command.toLowerCase().contains('screenshot')) && flag == true) {
        print('[MainPageLayout] 🎤 Выполняем скриншот...');
        screenshotButtonKey.currentState?.captureAndSaveScreenshot(context);
      }
    }, onError: (error) {
      print('[MainPageLayout] ❌ Ошибка в потоке команд: $error');
    });

// Подписка на транскрипцию
    _transcriptSubscription =
        voiceService.transcriptStream.listen((transcript) {
          print('[MainPageLayout] 📝 Получена полная транскрипция: ${transcript
              .length} символов');
          setState(() {
            _fullTranscript = transcript;
          });
        }, onError: (error) {
          print('[MainPageLayout] ❌ Ошибка в потоке транскрипции: $error');
        });

    // Initialize based on the initial mode
    if (_currentMode == VideoMode.uploaded && _currentVideoPath != null) {
      _initializeVideoPlayer();
    }
    // Load existing screenshots if examination ID is provided
    if (widget.examinationId != null) {
      _loadExistingScreenshots();
    }
  }

  void _initializeVideoPlayer() {
    print(
        '_initializeVideoPlayer: детекций перед инициализацией: ${_allDetections
            .length}');

    flag = false;
    _player = Player();
    _videoController = VideoController(_player!);
    _prepareAndPlay(_currentVideoPath!);

    print(
        '_initializeVideoPlayer: детекций после инициализации: ${_allDetections
            .length}');
  }

  // Покадровая навигация
  void _seekFrameForward() {
    if (_currentMode == VideoMode.uploaded && _player != null) {
      final currentPosition = _player!.state.position;
      final newPosition = currentPosition + _frameStep;
      _player!.seek(newPosition);
    }
  }

  void _seekFrameBackward() {
    if (_currentMode == VideoMode.uploaded && _player != null) {
      final currentPosition = _player!.state.position;
      final newPosition = currentPosition - _frameStep;
      if (newPosition >= Duration.zero) {
        _player!.seek(newPosition);
      } else {
        _player!.seek(Duration.zero);
      }
    }
  }

  // Точная навигация по времени (с миллисекундами)
  void _seekToExactTime(Duration duration) {
    if (_currentMode == VideoMode.uploaded && _player != null) {
      _player!.seek(duration);
    }
  }

  // Методы для работы с таймером камеры
  void _startCameraTimer() {
    flag = true;
    _cameraStartTime = DateTime.now();
    _currentCameraDuration = Duration.zero;

    _cameraTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentMode == VideoMode.camera) {
        setState(() {
          _currentCameraDuration = DateTime.now().difference(_cameraStartTime!);
        });
      }
    });
  }

  void _stopCameraTimer() {
    _cameraTimer?.cancel();
    _cameraTimer = null;
    _cameraStartTime = null;
    _currentCameraDuration = Duration.zero;
  }

  void _resetCameraTimer() {
    _stopCameraTimer();
    _startCameraTimer();
  }

  void handleDetection(Map<String, dynamic> detection) {
    final label = detection['label'];
    final confidence = detection['confidence'];
    // print(label);
  }


  // Method to switch to upload video mode
  Future<void> _switchToUploadMode() async {
    // Stop camera timer when switching to upload mode
    _stopCameraTimer();

    // Pick a video file
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _currentMode = VideoMode.uploaded;
        _currentVideoPath = result.files.single.path;
      });

      ApiService.connectToVideoWebSocket(examinationId: widget.examinationId!,
          videoPath: _currentVideoPath!,
          onDetection: handleDetection);

      // Dispose previous player if exists
      _disposeVideoPlayer();

      // Initialize new player
      _initializeVideoPlayer();
      flag = false;
    }
  }

  // Method to switch to camera mode
  void _switchToCameraMode() {
    setState(() {
      _currentMode = VideoMode.camera;
      _currentVideoPath = null;
    });
    flag = true;
    // Dispose video player when switching to camera
    _disposeVideoPlayer();
  }

//
  // Method to handle captured video file - opens it immediately
  void _onVideoCaptured(String capturedVideoPath,
      {List<DetectionBox>? detections}) {
    print('Video captured and saved: $capturedVideoPath');

    // Сначала останавливаем камеру и очищаем ресурсы
    transcript = voiceService.latestTranscript;
    _stopCameraTimer();


    // Обновляем состояние
    if (mounted) { // Проверяем, что виджет еще в дереве
      setState(() {
        if (detections != null) {
          _allDetections = List.from(detections);
          _detectionSegments = _processDetectionsIntoSegments(_allDetections);
          print('setState: Детекций установлено: ${_allDetections.length}');
        }

        _currentMode = VideoMode.uploaded;
        _currentVideoPath = capturedVideoPath;
      });

      print('После setState: Детекций в _allDetections: ${_allDetections
          .length}');

      flag = false;
      _disposeVideoPlayer();

      // Добавляем задержку для инициализации плеера
      Future.delayed(Duration(milliseconds: 200), () {
        if (mounted) {
          _initializeVideoPlayer();
        }
      });
    }
  }

  List<DetectionSegment> _processDetectionsIntoSegments(
      List<DetectionBox> detections) {
    if (detections.isEmpty) return [];

    // Группируем детекции по типу (label)
    Map<String, List<DetectionBox>> detectionsByLabel = {};
    for (var detection in detections) {
      detectionsByLabel.putIfAbsent(detection.label, () => []).add(detection);
    }

    List<DetectionSegment> segments = [];

    for (var entry in detectionsByLabel.entries) {
      String label = entry.key;
      List<DetectionBox> labelDetections = entry.value;

      // Сортируем по времени
      labelDetections.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      Duration gapThreshold = Duration(seconds: 2);

      Duration? currentSegmentStart;
      Duration? currentSegmentEnd;
      double maxConfidence = 0.0;
      int detectionCount = 0;

      for (int i = 0; i < labelDetections.length; i++) {
        DetectionBox detection = labelDetections[i];

        if (currentSegmentStart == null) {
          // Начинаем новый сегмент
          currentSegmentStart = detection.timestamp;
          currentSegmentEnd = detection.timestamp;
          maxConfidence = detection.confidence;
          detectionCount = 1;
        } else {
          // Проверяем, нужно ли продолжить текущий сегмент или начать новый
          Duration gap = detection.timestamp - currentSegmentEnd!;

          if (gap <= gapThreshold) {
            // Продолжаем текущий сегмент
            currentSegmentEnd = detection.timestamp;
            maxConfidence = math.max(maxConfidence, detection.confidence);
            detectionCount++;
          } else {
            // Сохраняем текущий сегмент и начинаем новый
            segments.add(DetectionSegment(
              startTime: currentSegmentStart,
              endTime: currentSegmentEnd,
              label: label,
              maxConfidence: maxConfidence,
              detectionCount: detectionCount,
            ));

            // Начинаем новый сегмент
            currentSegmentStart = detection.timestamp;
            currentSegmentEnd = detection.timestamp;
            maxConfidence = detection.confidence;
            detectionCount = 1;
          }
        }
      }

      // Не забываем сохранить последний сегмент
      if (currentSegmentStart != null && currentSegmentEnd != null) {
        segments.add(DetectionSegment(
          startTime: currentSegmentStart,
          endTime: currentSegmentEnd,
          label: label,
          maxConfidence: maxConfidence,
          detectionCount: detectionCount,
        ));
      }
    }

    return segments;
  }

  void _disposeVideoPlayer() {
    _player?.dispose();
    _player = null;
    _videoController = null;
  }

  // Метод для загрузки существующих скриншотов
  Future<void> _loadExistingScreenshots() async {
    if (widget.examinationId == null) return;

    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/exams/${widget.examinationId}/screenshots'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> screenshotsJson = json.decode(response.body);
        final List<ScreenshotItem> loadedScreenshots = [];

        for (var screenshotData in screenshotsJson) {
          final screenshotItem = ScreenshotItem.fromJson(screenshotData);

          // Загружаем изображение для каждого скриншота
          final imageBytes = await _loadScreenshotImage(
              screenshotItem.screenshotId);

          loadedScreenshots.add(ScreenshotItem(
            screenshotId: screenshotItem.screenshotId,
            filename: screenshotItem.filename,
            filePath: screenshotItem.filePath,
            timestampInVideo: screenshotItem.timestampInVideo,
            timestampDuration: screenshotItem.timestampDuration,
            imageBytes: imageBytes,
          ));
        }

        setState(() {
          screenshots = loadedScreenshots;
        });
      } else {
        print('Failed to load screenshots: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading screenshots: $e');
    }
  }

  // Метод для загрузки изображения скриншота
  Future<Uint8List?> _loadScreenshotImage(String screenshotId) async {
    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/screenshots/$screenshotId/file'),
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        print('Failed to load screenshot image: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error loading screenshot image: $e');
      return null;
    }
  }

  // Обновленный метод для загрузки скриншота на сервер с точным временем
  Future<String?> _uploadScreenshot(Uint8List imageBytes,
      String timestampInVideo) async {
    if (widget.examinationId == null) return null;

    try {
      final url = '$BASE_URL/exams/${widget.examinationId}/upload_screenshot/';
      print('Uploading screenshot to: $url');

      var request = http.MultipartRequest('POST', Uri.parse(url));

      // Добавляем файл
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: 'screenshot_${DateTime
              .now()
              .millisecondsSinceEpoch}.png',
        ),
      );

      // Добавляем обязательные поля
      request.fields['exam_id'] = widget.examinationId!;
      request.fields['timestamp_in_video'] = timestampInVideo;

      final response = await request.send();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = await response.stream.bytesToString();
        final responseData = json.decode(responseBody);
        return responseData['screenshot_id']?.toString() ??
            responseData['id']?.toString();
      } else {
        print('Failed to upload screenshot: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error uploading screenshot: $e');
      return null;
    }
  }

  Future<void> _prepareAndPlay(String inputPath) async {
    setState(() {
      _isLoading = true;
      _loadingMessage = "Checking video format...";
    });

    final inputFile = File(inputPath);
    final extension = inputFile.path
        .split('.')
        .last
        .toLowerCase();

    File playableFile = inputFile;

    if (extension == 'ts' || extension == 'mkv') {
      setState(() => _loadingMessage = "Converting video to MP4...");
      final mp4File = await _convertToMp4(inputFile);
      if (mp4File != null) {
        playableFile = mp4File;
        _convertedFile = mp4File;
      } else {
        return;
      }
    }

    await _player!.open(Media(playableFile.path));
    setState(() {
      _isLoading = false;
    });
  }

  Future<File?> _convertToMp4(File inputFile) async {
    final tempDir = await getTemporaryDirectory();
    final outputPath = '${tempDir.path}/${DateTime
        .now()
        .millisecondsSinceEpoch}.mp4';

    final command = '-i "${inputFile.path}" -c copy "$outputPath"';
//
    print('Running FFmpeg command: $command');
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      print('FFmpeg conversion succeeded: $outputPath');
      return File(outputPath);
    } else {
      final log = await session.getAllLogsAsString();
      print('FFmpeg failed: $log');
      return null;
    }
  }


  void _seekToTimecode(String timeString) {
    if (_currentMode == VideoMode.uploaded && _player != null) {
      final duration = _parseDurationWithMs(timeString);
      _player!.seek(duration);
    }
    // В режиме камеры переход по таймкоду не имеет смысла, так как это live stream
  }

  // Обновленный метод парсинга с миллисекундами
  Duration _parseDurationWithMs(String timeString) {
    final parts = timeString.split(':');
    if (parts.length != 2) return Duration.zero;

    final minutes = int.tryParse(parts[0]) ?? 0;
    final secondsAndMs = parts[1].split('.');
    final seconds = int.tryParse(secondsAndMs[0]) ?? 0;
    final milliseconds = secondsAndMs.length > 1 ? int.tryParse(
        secondsAndMs[1]) ?? 0 : 0;

    return Duration(
        minutes: minutes, seconds: seconds, milliseconds: milliseconds);
  }
    String _getCurrentTimeCode() {
      if (_currentMode == VideoMode.uploaded && _player != null) {
        // Для загруженного видео используем позицию плеера
        final position = _player!.state.position;
        final minutes = position.inMinutes;
        final seconds = position.inSeconds % 60;
        final milliseconds = position.inMilliseconds % 1000;
        return "${minutes.toString()}:${seconds.toString().padLeft(
            2, '0')}.${milliseconds.toString().padLeft(3, '0')}";
      } else if (_currentMode == VideoMode.camera) {
        // Для камеры используем таймер
        final minutes = _currentCameraDuration.inMinutes;
        final seconds = _currentCameraDuration.inSeconds % 60;
        final milliseconds = _currentCameraDuration.inMilliseconds % 1000;
        return "${minutes.toString()}:${seconds.toString().padLeft(
            2, '0')}.${milliseconds.toString().padLeft(3, '0')}";
      }
      return "0:00.000";
    }
    Future<void> exportText() async {
      if (_fullTranscript == null || _fullTranscript!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Расшифровка обследования еще не готова'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      try {
        // Получаем директорию для сохранения
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'voice_transcript_${DateTime
            .now()
            .millisecondsSinceEpoch}.txt';
        final file = File('${directory.path}/$fileName');

        // Сохраняем транскрипцию в файл
        await file.writeAsString(_fullTranscript!);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Расшифровка сохранена: $fileName'),
            backgroundColor: const Color(0xFF00ACAB),
            action: SnackBarAction(
              label: 'Открыть папку',
              onPressed: () {
                // Можно добавить функцию для открытия папки
                print('Файл сохранен: ${file.path}');
              },
            ),
          ),
        );
      } catch (e) {
        print('Ошибка при сохранении транскрипции: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка при сохранении расшифровки'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

  // Получение текущего времени как Duration
  Duration _getCurrentDuration() {
    if (_currentMode == VideoMode.uploaded && _player != null) {
      return _player!.state.position;
    } else if (_currentMode == VideoMode.camera) {
      return _currentCameraDuration;
    }
    return Duration.zero;
  }

    //-------------------Time Line--------------------------//
    // Метод для преобразования скриншотов в пометки для таймлайна
    List<ScreenshotMarker> _getScreenshotMarkers() {
      return screenshots.map((screenshot) {
        return ScreenshotMarker(
          timestamp: screenshot.timestampDuration,
          screenshotId: screenshot.screenshotId,
        );
      }).toList();
    }

    List<DetectionSegmentMarker> _getDetectionMarkers() {
      return _detectionSegments.map((segment) {
        return DetectionSegmentMarker(
          startTime: segment.startTime,
          endTime: segment.endTime,
          label: segment.label,
          confidence: segment.maxConfidence,
          detectionCount: segment.detectionCount,
          type: 'detection',
        );
      }).toList();
    }

// Обработчик клика по пометке на таймлайне
    void _onMarkerTap(Duration timestamp) {
      if (_currentMode == VideoMode.uploaded && _player != null) {
        _player!.seek(timestamp);
      }
    }

// Обновленный метод _buildVideoArea()
    Widget _buildVideoArea() {
      switch (_currentMode) {
        case VideoMode.uploaded:
          if (_isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF00ACAB)),
                  const SizedBox(height: 5),
                  Text(
                    _loadingMessage ?? "Loading...",
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
            );
          }
          return Stack(
            children: [
              _player != null
                  ? VideoPlayerWidget(
                player: _player!,
                screenshotMarkers: _getScreenshotMarkers(),
                detections: _allDetections,
                onMarkerTap: _onMarkerTap,
                onDetectionIntervalTap: _onDetectionIntervalTap,
              )
                  : const Center(child: Text("Video player not initialized")),

              // Кнопки покадровой навигации
              if (_player != null)
                Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Кнопка "кадр назад"
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 30),
                        child: FloatingActionButton(
                          mini: true,
                          backgroundColor: const Color(0xFF00ACAB),
                          onPressed: _seekFrameBackward,
                          child: const Icon(
                              Icons.skip_previous, color: Colors.white),
                          tooltip: "Кадр назад",
                        ),
                      ),

                      // Кнопка "кадр вперед"
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 30),
                        child: FloatingActionButton(
                          mini: true,
                          backgroundColor: const Color(0xFF00ACAB),
                          onPressed: _seekFrameForward,
                          child: const Icon(
                              Icons.skip_next, color: Colors.white),
                          tooltip: "Кадр вперед",
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );

        case VideoMode.camera:
          return Stack(
            children: [
              CameraStreamWidget(
                aspectRatio: 16 / 9,
                videoWidth: 1280,
                videoHeight: 720,
                frameRate: 30,
                examinationId: widget.examinationId,
                onVideoCaptured: (path, detections) =>
                    _onVideoCaptured(path, detections: detections),
                startCaptured: _startCameraTimer,
              ),
              Positioned(
                bottom: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getCurrentTimeCode(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
      }
    }


    void _onDetectionIntervalTap(DetectionSegment segment) {
      if (_currentMode == VideoMode.uploaded && _player != null) {
        _player!.seek(segment.startTime);
      }
    }

    // Обновленный метод форматирования времени с миллисекундами
    String _formatDurationWithMs(Duration duration) {
      final minutes = duration.inMinutes.toString().padLeft(2, '0');
      final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
      final milliseconds = (duration.inMilliseconds % 1000).toString().padLeft(
          3, '0');
      return '$minutes:$seconds.$milliseconds';
    }

    // Обновленный метод _addScreenshot с точным временем
    Future<void> _addScreenshot(Uint8List imageBytes) async {
      final currentTimestamp = _getCurrentTimeCode();
      final currentDuration = _getCurrentDuration();

      // Сначала добавляем скриншот в локальный список
      setState(() {
        screenshots.add(ScreenshotItem(
          screenshotId: DateTime
              .now()
              .millisecondsSinceEpoch
              .toString(),
          filename: 'screenshot_${DateTime
              .now()
              .millisecondsSinceEpoch}.png',
          filePath: '',
          timestampInVideo: currentTimestamp,
          timestampDuration: currentDuration,
          imageBytes: imageBytes,
        ));
      });

      // Параллельно отправляем на сервер (без блокировки UI)
      if (widget.examinationId != null) {
        _uploadScreenshot(imageBytes, currentTimestamp).then((screenshotId) {
          if (screenshotId != null) {
            print('Screenshot successfully uploaded with ID: $screenshotId');
            // Обновляем ID скриншота после успешной загрузки
            setState(() {
              final index = screenshots.length - 1;
              if (index >= 0) {
                screenshots[index] = ScreenshotItem(
                  screenshotId: screenshotId,
                  filename: screenshots[index].filename,
                  filePath: screenshots[index].filePath,
                  timestampInVideo: screenshots[index].timestampInVideo,
                  timestampDuration: screenshots[index].timestampDuration,
                  imageBytes: screenshots[index].imageBytes,
                );
              }
            });
          } else {
            print('Failed to upload screenshot to server');
          }
        });
      }
    }


//----------------------------------------------------------------------------
    // Build the control buttons in the sidebar
    Widget _buildControlButtons() {
      return Column(
        children: [
          // Screenshot button (only available when video is loaded)
          if (_currentMode == VideoMode.uploaded ||
              _currentMode == VideoMode.camera)
            ScreenshotButton(
              key: screenshotButtonKey,
              screenshotKey: _screenshotKey,
              examId: widget.examinationId,
              onScreenshotTaken: _addScreenshot,
            ),

          // Screenshots editor button
          if (screenshots.isNotEmpty)
            IconButton(
              onPressed: () {
                if (screenshots.isNotEmpty &&
                    screenshots.first.imageBytes != null) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) =>
                        ScreenShotsEditorDialog(
                          screenshot: MemoryImage(
                              screenshots.first.imageBytes!),
                          otherScreenshots: screenshots
                              .skip(1)
                              .where((s) => s.imageBytes != null)
                              .map((s) => MemoryImage(s.imageBytes!))
                              .toList(),
                        ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text(
                        'Нет доступных скриншотов для редактирования')),
                  );
                }
              },
              icon: const Icon(
                Icons.image,
                color: Color(0xFF00ACAB),
              ),
              tooltip: "Edit Screenshots",
            ),

          // Mode switch buttons
          IconButton(
            onPressed: _switchToUploadMode,
            icon: const Icon(
              Icons.video_file,
              color: Color(0xFF00ACAB),
            ),
            tooltip: "Upload Video",
          ),
          IconButton(
            onPressed: _switchToCameraMode,
            icon: const Icon(
              Icons.videocam,
              color: Color(0xFF00ACAB),
            ),
            tooltip: "Capture Video",
          ),

          if (_currentMode == VideoMode.uploaded && _fullTranscript != null &&
              _fullTranscript!.isNotEmpty)
            IconButton(
              onPressed: exportText,
              icon: const Icon(
                Icons.download_rounded,
                color: Color(0xFF00ACAB),
              ),
              tooltip: "Download voice notes",
            ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EndoscopistApp()),
              );
            },
            icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF00ACAB)
            ),
            tooltip: "Back to menu",
          ),
          /*IconButton(
          onPressed: exportText,
          icon: const Icon(
            Icons.settings_rounded,
            color: Color(0xFF00ACAB),
          ),
          tooltip: "Settings",
        ),*/ //Settings??
        ],
      );
    }

    @override
    void dispose() {
      _voiceSubscription?.cancel();
      _stopCameraTimer();
      _transcriptSubscription?.cancel();
      _disposeVideoPlayer();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      Size screenSize = MediaQuery
          .of(context)
          .size;

      return Scaffold(
        backgroundColor: Colors.white,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sidebar List - Updated to show screenshots instead of timecodes
            if (_currentMode == VideoMode.uploaded ||
                _currentMode == VideoMode.camera)
              Container(
                height: screenSize.height,
                width: 200,
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: screenshots.isEmpty
                    ? const Center(
                  child: Text(
                    'No screenshots yet',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                )
                    : ListView.builder(
                  itemCount: screenshots.length,
                  itemBuilder: (context, index) {
                    final screenshot = screenshots[index];
                    return GestureDetector(
                      onTap: () => _seekToTimecode(screenshot.timestampInVideo),
                      child: Container(
                        height: 100,
                        width: 50,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00ACAB),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 100,
                              height: 80,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: screenshot.imageBytes != null
                                  ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  screenshot.imageBytes!,
                                  fit: BoxFit.cover,
                                ),
                              )
                                  : const Icon(
                                Icons.image,
                                color: Colors.grey,
                                size: 40,
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  screenshot.timestampInVideo,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontFamily: 'Nunito',
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Video Area
            RepaintBoundary(
              key: _screenshotKey,
              child: Container(
                height: screenSize.height,
                width: (_currentMode == VideoMode.uploaded ||
                    _currentMode == VideoMode.camera)
                    ? screenSize.width - 260
                    : screenSize.width - 60,
                margin: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF00ACAB), width: 5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: _buildVideoArea(),
                ),
              ),
            ),

            // Navigation & Controls
            Container(
              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: _buildControlButtons(),
            ),
          ],
        ),
      );
    }
  }