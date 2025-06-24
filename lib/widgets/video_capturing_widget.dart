import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

import 'package:path/path.dart' as path;

class CameraStreamWidget extends StatefulWidget {
  const CameraStreamWidget({super.key});

  @override
  State<CameraStreamWidget> createState() => _CameraStreamWidgetState();
}

class _CameraStreamWidgetState extends State<CameraStreamWidget> {
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  MediaStream? _mediaStream;
  bool _isRecording = false;
  String? _outputPath;
  FFmpegSession? _ffmpegSession;

  @override
  void initState() {
    super.initState();
    _initializeCamera();

    // TODO: Initialize VOSK and listen for voice commands to start/stop recording
  }

  Future<void> _initializeCamera() async {
    await _renderer.initialize();

    final constraints = {
      'audio': true,
      'video': {
        'facingMode': 'user',
        'width': 1280,
        'height': 720,
        'frameRate': 30,
      },
    };

    try {
      final stream = await navigator.mediaDevices.getUserMedia(constraints);
      _renderer.srcObject = stream;
      setState(() {
        _mediaStream = stream;
      });
    } catch (e) {
      print('Error accessing camera: $e');
    }
  }

  Future<String> _getTempOutputFilePath() async {
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/recording_$timestamp.mp4';
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;

    final tempPath = await _getTempOutputFilePath();
    _outputPath = tempPath;

    setState(() => _isRecording = true);

    final command = Platform.isMacOS
        ? '-f avfoundation -pix_fmt uyvy422 -framerate 30 -video_size 1280x720 '
        '-i "0:0" -preset ultrafast -crf 23 -r 30 "$tempPath"'
        : '-f gdigrab -framerate 30 -video_size 1280x720 '
        '-i desktop -preset ultrafast -crf 23 -r 30 "$tempPath"';

    print('Running FFmpeg command:\n$command');

    _ffmpegSession = await FFmpegKit.executeAsync(command, (session) async {
      final returnCode = await session.getReturnCode();
      print('FFmpeg finished with code: $returnCode');

      setState(() {
        _isRecording = false;
        _ffmpegSession = null;
      });

      if (returnCode != null && ReturnCode.isSuccess(returnCode)) {
        _promptUserToSaveFile(tempPath);
      } else if (returnCode != null && ReturnCode.isCancel(returnCode)) {
        print('Recording was cancelled.');
        _promptUserToSaveFile(tempPath);
      } else {
        print('Recording failed with code: $returnCode');
      }
    });

    // TODO: Trigger start recording via voice command
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || _ffmpegSession == null) return;

    await _ffmpegSession!.cancel();
    print('Recording manually stopped.');

    // TODO: Trigger stop recording via voice command
  }

  Future<void> _promptUserToSaveFile(String tempFilePath) async {
    final saveDir = await FilePicker.platform.getDirectoryPath();

    if (saveDir == null) {
      print('User cancelled folder selection.');
      return;
    }

    final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final destination = path.join(saveDir, fileName);

    try {
      await File(tempFilePath).copy(destination);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to: $destination')),
        );
      }
    } catch (e) {
      print('Failed to save recording: $e');
    }
  }

  @override
  void dispose() {
    _mediaStream?.getTracks().forEach((track) => track.stop());
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: Colors.black,
            child: RTCVideoView(
              _renderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.fiber_manual_record),
              label: const Text("Start Recording"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: _isRecording ? null : _startRecording,
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.stop),
              label: const Text("Stop Recording"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade800,
                foregroundColor: Colors.white,
              ),
              onPressed: _isRecording ? _stopRecording : null,
            ),
          ],
        ),
        if (_outputPath != null)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Text(
              'Recording to temp: $_outputPath',
              style: const TextStyle(color: Colors.green, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
