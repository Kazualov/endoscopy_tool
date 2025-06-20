import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

import 'package:endoscopy_tool/pages/patient_library.dart';
import 'package:endoscopy_tool/widgets/video_player_widget.dart';
import 'package:endoscopy_tool/widgets/screenshot_button_widget.dart';

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
  VideoPlayerController? _videoController;
  final GlobalKey _screenshotKey = GlobalKey();
  File? _convertedFile;
  bool _isLoading = true;
  String? _loadingMessage;

  List<String> items = ["0:06", "0:12", "0:00"];

  @override
  void initState() {
    super.initState();
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

    _videoController = VideoPlayerController.file(playableFile);
    await _videoController!.initialize();
    _videoController!.addListener(() {
      if (mounted) setState(() {});
    });

    setState(() {
      _isLoading = false;
    });
  }

  Future<File?> _convertToMp4(File inputFile) async {
    final tempDir = await getTemporaryDirectory();
    final outputPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.mp4';

    // Fast remux only (no re-encode)
    final command = '-i "${inputFile.path}" -c copy "$outputPath"';
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return File(outputPath);
    } else {
      print('FFmpeg failed: ${await session.getAllLogsAsString()}');
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
    _videoController?.seekTo(duration);
  }

  Duration _parseDuration(String timeString) {
    final parts = timeString.split(":");
    final minutes = int.parse(parts[0]);
    final seconds = int.parse(parts[1]);
    return Duration(minutes: minutes, seconds: seconds);
  }

  void exportText() {}

  @override
  void dispose() {
    _videoController?.dispose();
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
          // Sidebar List
          Container(
            height: screenSize.height,
            width: 200,
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),

            decoration: BoxDecoration(
              color: Color(0xFFD9D9D9),
              borderRadius: BorderRadius.circular(20)
            ),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final timeString = items[index];
                return GestureDetector(
                  onTap: () => _seekToTimecode(timeString),
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
                        ),
                        Center(
                          child: Container(
                            child: Text(
                              timeString,
                              style: const TextStyle(
                                fontSize: 24,
                                fontFamily: 'Nunito',
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
                borderRadius: BorderRadius.circular(20),
                child: _videoController!.value.isInitialized
                    ? VideoPlayerWidget(controller: _videoController!)
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),

          // Navigation & Screenshot
          Container(
            margin: EdgeInsetsGeometry.symmetric(vertical: 5, horizontal: 5),
              decoration: BoxDecoration(
                color: Color(0xFFD9D9D9),
                borderRadius: BorderRadius.circular(20)
              ),
              
              child: Column(
                children: [
                  ScreenshotButton(screenshotKey: _screenshotKey),
                  IconButton(
                    onPressed: exportText,
                    icon: const Icon(
                      Icons.import_export_rounded,
                      color: Color(0xFF00ACAB),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => EndoscopistApp()),
                      );
                    },
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF00ACAB)),
                  ),
                ],
              )
          )

        ],
      ),
    );
  }
}
