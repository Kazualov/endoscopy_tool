import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

import 'package:endoscopy_tool/pages/patient_library.dart';
import 'package:endoscopy_tool/widgets/video_player_widget.dart';
import 'package:endoscopy_tool/widgets/screenshot_button_widget.dart';

// Модель для хранения данных скриншота
class ScreenshotItem {
  final String timeCode;
  final Uint8List? imageBytes;
  final String? imagePath;

  ScreenshotItem({
    required this.timeCode,
    this.imageBytes,
    this.imagePath,
  });
}

class MainPage extends StatelessWidget {
  final String videoPath;
  const MainPage({super.key, required this.videoPath});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainPageLayout(videoPath: videoPath),
    );
  }
}

class MainPageLayout extends StatefulWidget {
  final String videoPath;

  const MainPageLayout({super.key, required this.videoPath});

  @override
  _MainPageLayoutState createState() => _MainPageLayoutState();
}

class _MainPageLayoutState extends State<MainPageLayout> {
  final GlobalKey _screenshotKey = GlobalKey();
  File? _convertedFile;
  bool _isLoading = true;
  String? _loadingMessage;

  // Заменяем список строк на список объектов ScreenshotItem
  List<ScreenshotItem> screenshots = [
  ];

  late final Player _player;
  late final VideoController _videoController;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);

    _prepareAndPlay(widget.videoPath);
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

  void _seekToTimecode(String timeString) {
    final duration = _parseDuration(timeString);
    _player.seek(duration);
  }

  Duration _parseDuration(String timeString) {
    final parts = timeString.split(":");
    final minutes = int.parse(parts[0]);
    final seconds = int.parse(parts[1]);
    return Duration(minutes: minutes, seconds: seconds);
  }

  // Метод для получения текущего тайм-кода
  String _getCurrentTimeCode() {
    final position = _player.state.position;
    final minutes = position.inMinutes;
    final seconds = position.inSeconds % 60;
    return "${minutes.toString()}:${seconds.toString().padLeft(2, '0')}";
  }

  // Метод для добавления нового скриншота
  Future<void> _addScreenshot(Uint8List imageBytes) async {
    final currentTimeCode = _getCurrentTimeCode();

    setState(() {
      screenshots.add(ScreenshotItem(
        timeCode: currentTimeCode,
        imageBytes: imageBytes,
      ));
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Screenshot added at $currentTimeCode')),
    );
  }

  void exportText() {}

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

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
          // Sidebar List - обновленная панель скриншотов
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
                  onTap: () => _seekToTimecode(screenshot.timeCode),
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
                              screenshot.timeCode,
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
                  screenshotKey: _screenshotKey,
                  onScreenshotTaken: _addScreenshot, // Передаем колбэк
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