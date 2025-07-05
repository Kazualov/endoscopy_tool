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

import 'ApiService.dart';

// Класс для хранения данных о детекции
class DetectionBox {
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final String label;
  final double confidence;
  final DateTime timestamp;

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
    return DetectionBox(
      x1: json['x1']?.toDouble() ?? 0.0,
      y1: json['y1']?.toDouble() ?? 0.0,
      x2: json['x2']?.toDouble() ?? 0.0,
      y2: json['y2']?.toDouble() ?? 0.0,
      label: json['label'] ?? '',
      confidence: json['confidence']?.toDouble() ?? 0.0,
      timestamp: DateTime.now(),
    );
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
  final Function(String)? onVideoCaptured;
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
  bool _isDetectionEnabled = false;

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

      _webSocketChannel!.stream.listen(
            (message) {
          try {
            final data = jsonDecode(message);
            final detections = data['detections'] as List<dynamic>? ?? [];

            setState(() {
              _currentDetections = detections
                  .map((det) => DetectionBox.fromJson(det))
                  .toList();
            });

            // Логируем детекции
            for (var detection in _currentDetections) {
              print('Detected: ${detection.label} with confidence ${detection.confidence}');
            }
          } catch (e) {
            print('Error parsing detection data: $e');
          }
        },
        onDone: () {
          print('WebSocket closed');
          setState(() {
            _currentDetections.clear();
          });
        },
        onError: (error) {
          print('WebSocket error: $error');
          setState(() {
            _currentDetections.clear();
          });
        },
      );

      setState(() {
        _isDetectionEnabled = true;
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

  Future<void> _startRecording() async {
    if (_isRecording) return;
    if (widget.startCaptured != null){
      widget.startCaptured!();
    }
    final tempPath = await _getTempOutputFilePath();
    _outputPath = tempPath;

    final videoInput = _getFFmpegVideoInput();

    if (videoInput == null) {
      print("No valid FFmpeg-compatible camera input.");
      return;
    }

    final command = Platform.isMacOS
        ? '-f avfoundation -framerate ${widget.frameRate} '
        '-video_size ${widget.videoWidth}x${widget.videoHeight} '
        '-i "$videoInput" -c:v libx264 -preset ultrafast -crf 23 '
        '-pix_fmt yuv420p "$tempPath"'

        : '-f dshow -i video="$videoInput" '
        '-c:v libx264 -preset ultrafast -crf 23 '
        '-r ${widget.frameRate} "$tempPath"';

    print('Running FFmpeg command:\n$command');

    setState(() => _isRecording = true);

    _ffmpegSession = await FFmpegKit.executeAsync(command, (session) async {
      final returnCode = await session.getReturnCode();
      print('FFmpeg finished with code: $returnCode');

      setState(() {
        _isRecording = false;
        _ffmpegSession = null;
      });
      if (!File(tempPath).existsSync()) {
        print("⚠️ FFmpeg did not produce a file at: $tempPath");
      } else {
        print("✅ File created: $tempPath");
      }
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
          if (File(tempPath).existsSync()) await File(tempPath).delete();
        } catch (e) {
          print('Delete failed: $e');
        }
      }
    });
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || _ffmpegSession == null) return;

    print('Stopping recording...');

    // Update UI immediately - don't wait for FFmpeg to finish
    setState(() {
      _isRecording = false;
    });

    try {
      final sessionToCancel = _ffmpegSession;
      _ffmpegSession = null; // Clear reference immediately

      // Cancel the session
      await sessionToCancel!.cancel();
      print('Recording cancelled successfully.');

    } catch (e) {
      print('Error stopping recording: $e');
    }

    print('Recording stop completed.');
  }

  Future<void> _saveRecordedFile(String tempFilePath) async {
    String? saveDir = _defaultSaveFolder;

    print('Trying to save: $tempFilePath');

    if (!File(tempFilePath).existsSync()) {
      print('❌ File does not exist: $tempFilePath');
      return;
    }

    if (saveDir == null || saveDir.isEmpty) {
      saveDir = await FilePicker.platform.getDirectoryPath();
      if (saveDir == null) {
        print('User cancelled folder selection.');
        return;
      }
      setState(() => _defaultSaveFolder = saveDir);
      await _saveSettings();
    }

    final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final destination = path.join(saveDir, fileName);

    try {
      await File(tempFilePath).copy(destination);
      print('✅ Copied to: $destination');

      if (widget.examinationId != null) {
        print('📤 Uploading video to database...');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text('Uploading video to database...'),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 30),
            ),
          );
        }

        try {
          final videoId = await ApiService.uploadVideoToExamination(
            widget.examinationId!,
            destination,
          );

          if (videoId != null) {
            print('✅ Video uploaded successfully with ID: $videoId');

            if (mounted) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Video captured and uploaded successfully!'),
                  backgroundColor: const Color(0xFF00ACAB),
                  action: SnackBarAction(
                    label: 'Open Folder',
                    onPressed: () => _openFolder(saveDir!),
                  ),
                ),
              );
            }
          } else {
            print('❌ Failed to upload video to database');

            if (mounted) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Video saved locally but failed to upload to database'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        } catch (e) {
          print('❌ Error uploading video: $e');

          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Video saved locally but upload failed: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        print("no ExamId");
      }

      if (widget.onVideoCaptured != null) {
        widget.onVideoCaptured!(destination);
      }

    } catch (e) {
      print('❌ Failed to save recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save recording: $e')),
        );
      }
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
          const SizedBox(height: 1),
          // Элементы управления
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: Icon(_isRecording ? Icons.radio_button_checked : Icons.fiber_manual_record),
                label: Text(_isRecording ? "Recording..." : "Start Recording"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRecording ? Color(0xFFD9D9D9) : Color(0xFF00ACAB),
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
              const SizedBox(width: 16),
              // Кнопка переключения детекции
              if (widget.examinationId != null)
                ElevatedButton.icon(
                  icon: Icon(_isDetectionEnabled ? Icons.visibility : Icons.visibility_off),
                  label: Text(_isDetectionEnabled ? "AI ON" : "AI OFF"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isDetectionEnabled ? Colors.green : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _toggleDetection,
                ),
              const SizedBox(width: 16),
              IconButton(
                color: Color(0xFF00ACAB),
                icon: const Icon(Icons.settings),
                onPressed: _showSettingsDialog,
                tooltip: 'Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }
}