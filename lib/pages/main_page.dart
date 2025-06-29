import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

import 'package:endoscopy_tool/pages/patient_library.dart';
import 'package:endoscopy_tool/widgets/video_player_widget.dart';
import 'package:endoscopy_tool/widgets/screenshot_button_widget.dart';
import 'package:endoscopy_tool/widgets/video_capturing_widget.dart';

// Enum to define different video modes
enum VideoMode {
  uploaded,    // Video uploaded from file
  camera       // Live camera capture
}

class MainPage extends StatelessWidget {
  final String? videoPath;
  final VideoMode initialMode;

  const MainPage({
    super.key,
    this.videoPath,
    this.initialMode = VideoMode.camera
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainPageLayout(
        videoPath: videoPath,
        initialMode: initialMode,
      ),
    );
  }
}

class MainPageLayout extends StatefulWidget {
  final String? videoPath;
  final VideoMode initialMode;

  const MainPageLayout({
    super.key,
    this.videoPath,
    this.initialMode = VideoMode.camera,
  });

  @override
  _MainPageLayoutState createState() => _MainPageLayoutState();
}

class _MainPageLayoutState extends State<MainPageLayout> {
  final GlobalKey _screenshotKey = GlobalKey();
  File? _convertedFile;
  bool _isLoading = false;
  String? _loadingMessage;

  List<String> items = ["0:00"];

  // Video mode state
  late VideoMode _currentMode;
  String? _currentVideoPath;

  // Video player components (only used in uploaded mode)
  Player? _player;
  VideoController? _videoController;

  @override
  void initState() {
    super.initState();

    // Set initial mode from constructor
    _currentMode = widget.initialMode;
    _currentVideoPath = widget.videoPath;

    // Initialize based on the initial mode
    if (_currentMode == VideoMode.uploaded && _currentVideoPath != null) {
      _initializeVideoPlayer();
    }
  }

  void _initializeVideoPlayer() {
    _player = Player();
    _videoController = VideoController(_player!);
    _prepareAndPlay(_currentVideoPath!);
  }

  // Method to switch to upload video mode
  Future<void> _switchToUploadMode() async {
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

      // Dispose previous player if exists
      _disposeVideoPlayer();

      // Initialize new player
      _initializeVideoPlayer();
    }
  }

  // Method to switch to camera mode
  void _switchToCameraMode() {
    setState(() {
      _currentMode = VideoMode.camera;
      _currentVideoPath = null;
    });

    // Dispose video player when switching to camera
    _disposeVideoPlayer();
  }

  // Method to handle captured video file - opens it immediately
  void _onVideoCaptured(String capturedVideoPath) {
    setState(() {
      _currentMode = VideoMode.uploaded;
      _currentVideoPath = capturedVideoPath;
    });

    // Dispose previous player if exists
    _disposeVideoPlayer();

    // Initialize player with captured video
    _initializeVideoPlayer();

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Video captured and loaded: ${capturedVideoPath.split('/').last}'),
        backgroundColor: const Color(0xFF00ACAB),
      ),
    );
  }

  void _disposeVideoPlayer() {
    _player?.dispose();
    _player = null;
    _videoController = null;
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

    await _player!.open(Media(playableFile.path));
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
    if (_player != null) {
      final duration = _parseDuration(timeString);
      _player!.seek(duration);
    }
  }

  Duration _parseDuration(String timeString) {
    final parts = timeString.split(":");
    final minutes = int.parse(parts[0]);
    final seconds = int.parse(parts[1]);
    return Duration(minutes: minutes, seconds: seconds);
  }

  void exportText() {}

  // Build the video area widget based on current mode
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
        return _player != null
            ? VideoPlayerWidget(player: _player!)
            : const Center(child: Text("Video player not initialized"));

      case VideoMode.camera:
        return CameraStreamWidget(
          aspectRatio: 16 / 9,
          videoWidth: 1280,
          videoHeight: 720,
          frameRate: 30,
          onVideoCaptured: _onVideoCaptured, // Pass callback to handle captured video
        );
    }
  }

  // Build the control buttons in the sidebar
  Widget _buildControlButtons() {
    return Column(
      children: [
        // Screenshot button (only available when video is loaded)
        if (_currentMode == VideoMode.uploaded || _currentMode == VideoMode.camera)
          ScreenshotButton(screenshotKey: _screenshotKey),

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
              MaterialPageRoute(builder: (context) => EndoscopistApp()),
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
    );
  }

  @override
  void dispose() {
    _disposeVideoPlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar List (show when in uploaded or camera mode)
          if (_currentMode == VideoMode.uploaded || _currentMode == VideoMode.camera)
            Container(
              height: screenSize.height,
              width: 200,
              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(20),
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
                            child: Text(
                              timeString,
                              style: const TextStyle(
                                fontSize: 24,
                                fontFamily: 'Nunito',
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
              width: (_currentMode == VideoMode.uploaded || _currentMode == VideoMode.camera)
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