import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

class CameraStreamWidget extends StatefulWidget {
  final double? width;
  final double? height;
  final double aspectRatio;
  final int videoWidth;
  final int videoHeight;
  final int frameRate;
  final Function(String)? onVideoCaptured; // Add callback for captured video

  const CameraStreamWidget({
    super.key,
    this.width,
    this.height,
    this.aspectRatio = 16 / 9,
    this.videoWidth = 1280,
    this.videoHeight = 720,
    this.frameRate = 30,
    this.onVideoCaptured, // Add callback parameter
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

  @override
  void initState() {
    super.initState();
    _initializeSettings();
    _listAvailableDevices();
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

        // Set defaults only if not already set
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
    await _ffmpegSession!.cancel();
    print('Recording manually stopped.');
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

      // Call the callback to open the captured video immediately
      if (widget.onVideoCaptured != null) {
        widget.onVideoCaptured!(destination);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video captured and opened: ${fileName}'),
            backgroundColor: const Color(0xFF00ACAB),
            action: SnackBarAction(
              label: 'Open Folder',
              onPressed: () => _openFolder(saveDir!),
            ),
          ),
        );
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

              // Save Folder Selection
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
              _initializeCamera(); // Reinitialize with new devices
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(
        children: [
          // Video preview
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
                  child: RTCVideoView(
                    _renderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 1),
          // Recording controls
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