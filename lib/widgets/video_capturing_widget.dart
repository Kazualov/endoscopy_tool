import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CameraStreamWidget extends StatefulWidget {
  const CameraStreamWidget({Key? key}) : super(key: key);

  @override
  State<CameraStreamWidget> createState() => _CameraStreamWidgetState();
}

class _CameraStreamWidgetState extends State<CameraStreamWidget> {
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  MediaStream? _mediaStream;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    // TODO: Initialize VOSK and microphone input for audio commands.
  }

  Future<void> _initializeCamera() async {
    await _renderer.initialize();

    // List all media devices
    final devices = await navigator.mediaDevices.enumerateDevices();
    for (final d in devices) {
      print('Device: ${d.label}, kind: ${d.kind}, id: ${d.deviceId}');
    }

    final Map<String, dynamic> constraints = {
      'audio': false,
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


  @override
  void dispose() {
    _mediaStream?.getTracks().forEach((track) => track.stop());
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.black,
        child: RTCVideoView(
          _renderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      ),
    );
  }
}
