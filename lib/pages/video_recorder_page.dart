import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import 'package:endoscopy_tool/widgets/screenshot_button_widget.dart'; // Make sure path is correct

class VideoRecorderPage extends StatefulWidget {
  const VideoRecorderPage({super.key});

  @override
  State<VideoRecorderPage> createState() => _VideoRecorderPageState();
}

class _VideoRecorderPageState extends State<VideoRecorderPage> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isRecording = false;
  VideoPlayerController? _videoPlayerController;
  String? _lastVideoPath;

  final GlobalKey _screenshotKey = GlobalKey(); // Screenshot target

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    // TODO: Connect voice commands from VOSK here
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    final frontCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
    );

    _controller = CameraController(frontCamera, ResolutionPreset.high);
    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});
  }

  Future<String> _getVideoFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${directory.path}/video_$timestamp.mp4';
  }

  Future<void> _startRecording() async {
    if (!_controller!.value.isInitialized || _isRecording) return;
    final path = await _getVideoFilePath();
    await _controller!.startVideoRecording();
    _isRecording = true;
    _lastVideoPath = path;
    setState(() {});
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || !_controller!.value.isRecordingVideo) return;

    final file = await _controller!.stopVideoRecording();
    _isRecording = false;

    _lastVideoPath = file.path;
    _videoPlayerController = VideoPlayerController.file(File(_lastVideoPath!));
    await _videoPlayerController!.initialize();
    await _videoPlayerController!.play();

    setState(() {});
  }

  Future<void> _takePhoto() async {
    if (!_controller!.value.isInitialized) return;

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${directory.path}/photo_$timestamp.jpg';

    final file = await _controller!.takePicture();
    await file.saveTo(filePath);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Photo saved to $filePath')),
    );
  }

  // Example VOSK command interface (to be linked with Python)
  void onVoiceCommand(String command) {
    switch (command.toLowerCase()) {
      case 'start':
        _startRecording();
        break;
      case 'stop':
        _stopRecording();
        break;
      case 'take a photo':
        _takePhoto();
        break;
      case 'screenshot':
      // You can call ScreenshotButton programmatically if needed
        break;
      default:
        print('Unknown command: $command');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Video Recorder')),
      body: Column(
        children: [
          RepaintBoundary(
            key: _screenshotKey,
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            ),
          ),
          const SizedBox(height: 8),
          if (_videoPlayerController != null)
            Column(
              children: [
                const Text("Last Recorded Video:"),
                AspectRatio(
                  aspectRatio: _videoPlayerController!.value.aspectRatio,
                  child: VideoPlayer(_videoPlayerController!),
                ),
              ],
            ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _isRecording ? null : _startRecording,
                child: const Text('Start'),
              ),
              ElevatedButton(
                onPressed: _isRecording ? _stopRecording : null,
                child: const Text('Stop'),
              ),
              ElevatedButton(
                onPressed: _takePhoto,
                child: const Text('Take Photo'),
              ),
              ScreenshotButton(screenshotKey: _screenshotKey),
            ],
          ),
        ],
      ),
    );
  }
}
