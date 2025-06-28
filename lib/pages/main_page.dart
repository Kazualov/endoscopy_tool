import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:endoscopy_tool/widgets/screenshot_button_widget.dart';


import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

import 'package:endoscopy_tool/pages/patient_library.dart';
import 'package:endoscopy_tool/widgets/video_player_widget.dart'; // New media_kit-based version

import '../main.dart';
import '../widgets/VoiceCommandService.dart';
import 'package:endoscopy_tool/widgets/screenshot_button_widget.dart';

import '../widgets/ScreenShotsEditorDialog.dart';

// Модель для хранения данных скриншота
class ScreenshotItem {
  final String screenshotId; // ID скриншота из базы данных
  final String filename;
  final String filePath;
  final String timestampInVideo;
  final Uint8List? imageBytes;

  ScreenshotItem({
    required this.screenshotId,
    required this.filename,
    required this.filePath,
    required this.timestampInVideo,
    this.imageBytes,
  });

  // Фабричный метод для создания из JSON
  factory ScreenshotItem.fromJson(Map<String, dynamic> json) {
    return ScreenshotItem(
      screenshotId: json['screenshot_id'].toString(),
      filename: json['filename'] ?? '',
      filePath: json['file_path'] ?? '',
      timestampInVideo: json['timestamp_in_video'] ?? '0:00',
    );
  }
}

class MainPage extends StatelessWidget {
  final String videoPath;
  final String examinationId; // Добавляем ID осмотра

  const MainPage({
    super.key,
    required this.videoPath,
    required this.examinationId,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainPageLayout(
        videoPath: videoPath,
        examinationId: examinationId,
      ),
    );
  }
}

class MainPageLayout extends StatefulWidget {
  final String videoPath;
  final String examinationId;

  const MainPageLayout({
    super.key,
    required this.videoPath,
    required this.examinationId,
  });

  @override
  _MainPageLayoutState createState() => _MainPageLayoutState();
}

class _MainPageLayoutState extends State<MainPageLayout> {
  final GlobalKey _screenshotKey = GlobalKey();
  final GlobalKey<ScreenshotButtonState> screenshotButtonKey = GlobalKey();

  File? _convertedFile;
  bool _isLoading = true;
  String? _loadingMessage;

  // Константы для API
  static const String BASE_URL = 'http://127.0.0.1:8000';

  List<ScreenshotItem> screenshots = [];

  late final Player _player;
  late final VideoController _videoController;

  StreamSubscription<String>? _voiceSubscription; // 👈 Добавляем подписку

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);

    // 👇 Используем ГЛОБАЛЬНЫЙ экземпляр VoiceService
    _voiceSubscription = voiceService.commandStream.listen((command) {
      print('[MainPageLayout] 🎤 Получена команда: $command');

      if (command.toLowerCase().contains('скриншот') ||
          command.toLowerCase().contains('screenshot')) {
        print('[MainPageLayout] 🎤 Выполняем скриншот...');
        screenshotButtonKey.currentState?.captureAndSaveScreenshot(context);
      }
    });

    _prepareAndPlay(widget.videoPath);
    _loadExistingScreenshots(); // Загружаем существующие скриншоты
  }



  // Метод для загрузки существующих скриншотов
  Future<void> _loadExistingScreenshots() async {
    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/exams/${widget.examinationId}/screenshots'),
        headers: {
          'Content-Type': 'application/json',
          // Добавьте заголовки авторизации если нужно
          // 'Authorization': 'Bearer YOUR_TOKEN',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> screenshotsJson = json.decode(response.body);
        final List<ScreenshotItem> loadedScreenshots = [];

        for (var screenshotData in screenshotsJson) {
          final screenshotItem = ScreenshotItem.fromJson(screenshotData);

          // Загружаем изображение для каждого скриншота
          final imageBytes = await _loadScreenshotImage(screenshotItem.screenshotId);

          loadedScreenshots.add(ScreenshotItem(
            screenshotId: screenshotItem.screenshotId,
            filename: screenshotItem.filename,
            filePath: screenshotItem.filePath,
            timestampInVideo: screenshotItem.timestampInVideo,
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

  // Метод для загрузки изображения скриншота (возвращает binary data)
  Future<Uint8List?> _loadScreenshotImage(String screenshotId) async {
    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/screenshots/$screenshotId/file'),
        headers: {
          // Добавьте заголовки авторизации если нужно
          // 'Authorization': 'Bearer YOUR_TOKEN',
        },
      );

      if (response.statusCode == 200) {
        return response.bodyBytes; // Сразу возвращаем binary данные
      } else {
        print('Failed to load screenshot image: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error loading screenshot image: $e');
      return null;
    }
  }

  // Метод для загрузки скриншота на сервер
  Future<String?> _uploadScreenshot(Uint8List imageBytes, String timestampInVideo) async {
    try {
      final url = '$BASE_URL/exams/${widget.examinationId}/upload_screenshot/';
      print('Uploading screenshot to: $url'); // Отладочная информация

      var request = http.MultipartRequest('POST', Uri.parse(url));

      // Добавляем заголовки авторизации если нужно
      // request.headers['Authorization'] = 'Bearer YOUR_TOKEN';

      // Добавляем файл
      request.files.add(
        http.MultipartFile.fromBytes(
          'file', // название поля для файла
          imageBytes,
          filename: 'screenshot_${DateTime.now().millisecondsSinceEpoch}.png',
        ),
      );

      // Добавляем обязательные поля
      request.fields['exam_id'] = widget.examinationId;
      request.fields['timestamp_in_video'] = timestampInVideo;

      print('Sending request with exam_id: ${widget.examinationId}, timestamp_in_video: $timestampInVideo'); // Отладочная информация

      final response = await request.send();

      print('Response status: ${response.statusCode}'); // Отладочная информация

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = await response.stream.bytesToString();
        print('Response body: $responseBody'); // Отладочная информация
        final responseData = json.decode(responseBody);

        // Возвращаем ID созданного скриншота
        return responseData['screenshot_id']?.toString() ?? responseData['id']?.toString();
      } else {
        print('Failed to upload screenshot: ${response.statusCode}');
        final responseBody = await response.stream.bytesToString();
        print('Error response: $responseBody'); // Отладочная информация
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
    final extension = inputFile.path.split('.').last.toLowerCase();

    File playableFile = inputFile;

    if (extension == 'ts' || extension == 'mkv') {
      setState(() => _loadingMessage = "Converting video to MP4...");
      final mp4File = await _convertToMp4(inputFile);
      if (mp4File != null) {
        playableFile = mp4File;
        _convertedFile = mp4File;
      } else {
        _showError('Video conversion failed');
        return;
      }
    }

    await _player.open(Media(playableFile.path));
    setState(() {
      _isLoading = false;
    });
  }

  Future<File?> _convertToMp4(File inputFile) async {
    final tempDir = await getTemporaryDirectory();
    final outputPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.mp4';

    // ✅ Re-encode video (libx264) & audio (aac) to ensure compatibility
    final command = '-i "${inputFile.path}" -c copy "$outputPath"';

    print('Running FFmpeg command: $command');
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      print('FFmpeg conversion succeeded: $outputPath');
      return File(outputPath);
    } else {
      final log = await session.getAllLogsAsString();
      print('FFmpeg failed: $log');
      _showError("Video conversion failed. Please try a different file.");
      return null;
    }
  }


  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    setState(() {
      _isLoading = false;
    });
  }

  void _seekToTimecode(String timestampInVideo) {
    final duration = _parseDuration(timestampInVideo);
    _player.seek(duration);
  }

  Duration _parseDuration(String timeString) {
    final parts = timeString.split(":");
    final minutes = int.parse(parts[0]);
    final seconds = int.parse(parts[1]);
    return Duration(minutes: minutes, seconds: seconds);
  }

  String _getCurrentTimeCode() {
    final position = _player.state.position;
    final minutes = position.inMinutes;
    final seconds = position.inSeconds % 60;
    return "${minutes.toString()}:${seconds.toString().padLeft(2, '0')}";
  }

  // Обновленный метод для добавления скриншота с сохранением на сервер
  Future<void> _addScreenshot(Uint8List imageBytes) async {
    final currentTimestamp = _getCurrentTimeCode();

    // Сначала добавляем скриншот в локальный список (как было изначально)
    setState(() {
      screenshots.add(ScreenshotItem(
        screenshotId: DateTime.now().millisecondsSinceEpoch.toString(), // временный ID
        filename: 'screenshot_${DateTime.now().millisecondsSinceEpoch}.png',
        filePath: '', // временно пустой
        timestampInVideo: currentTimestamp,
        imageBytes: imageBytes,
      ));
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Screenshot added at $currentTimestamp')),
    );

    // Параллельно отправляем на сервер (без блокировки UI)
    _uploadScreenshot(imageBytes, currentTimestamp).then((screenshotId) {
      if (screenshotId != null) {
        print('Screenshot successfully uploaded with ID: $screenshotId');
        // Можете обновить ID в локальном списке если нужно
        // _updateScreenshotId(currentTimestamp, screenshotId);
      } else {
        print('Failed to upload screenshot to server');
        // Можете показать уведомление об ошибке, но скриншот остается в списке
      }
    });
  }

  void exportText() {}

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? Center(
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
      )
          : Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar List - панель скриншотов
          Container(
            height: screenSize.height,
            width: 200,
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
            decoration: BoxDecoration(
              color: Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: ListView.builder(
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
                          margin: const EdgeInsets.symmetric(horizontal: 10),
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

          // Video Player
          RepaintBoundary(
            key: _screenshotKey,
            child: Container(
              height: screenSize.height,
              width: screenSize.width - 260,
              margin: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF00ACAB), width: 5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: VideoPlayerWidget(player: _player),
              ),
            ),
          ),

          // Navigation & Screenshot
          Container(
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
            decoration: BoxDecoration(
              color: Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                ScreenshotButton(
                  key: screenshotButtonKey,
                  screenshotKey: _screenshotKey,
                  examId: widget.examinationId,
                  onScreenshotTaken: _addScreenshot,
                ),
                IconButton(
                  onPressed: () {
                    if (screenshots.isNotEmpty && screenshots.first.imageBytes != null) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => ScreenShotsEditorDialog(
                          screenshot: MemoryImage(screenshots.first.imageBytes!), // ✅ Правильно
                          otherScreenshots: screenshots
                              .skip(1) // Пропускаем первый скриншот
                              .where((s) => s.imageBytes != null)
                              .map((s) => MemoryImage(s.imageBytes!))
                              .toList(),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Нет доступных скриншотов для редактирования')),
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.image,
                    color: Color(0xFF00ACAB),
                  ),
                ),
                IconButton(
                  onPressed: exportText,
                  icon: const Icon(
                    Icons.download_rounded,
                    color: Color(0xFF00ACAB),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => EndoscopistApp()),
                    );
                  },
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFF00ACAB)),
                ),
                IconButton(
                  onPressed: exportText,
                  icon: const Icon(
                    Icons.settings_rounded,
                    color: Color(0xFF00ACAB),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
