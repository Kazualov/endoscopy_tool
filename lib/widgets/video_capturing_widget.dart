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
  final bool showHeader;
  final bool showDeviceInfo;

  const CameraStreamWidget({
    super.key,
    this.width,
    this.height,
    this.aspectRatio = 16 / 9,
    this.videoWidth = 1280,
    this.videoHeight = 720,
    this.frameRate = 30,
    this.showHeader = true,
    this.showDeviceInfo = true,
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

  List<String> _videoDevices = [];
  List<String> _audioDevices = [];
  int _selectedVideoIndex = 0;
  int _selectedAudioIndex = 0;

  // Settings
  String? _defaultSaveFolder;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _initializeSettings();
    _initializeCamera();
    _listAvailableDevices();

    // TODO: Integrate VOSK to trigger recording via voice
  }

  Future<void> _initializeSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _defaultSaveFolder = _prefs?.getString('default_save_folder');
      _selectedVideoIndex = _prefs?.getInt('selected_video_index') ?? 0;
      _selectedAudioIndex = _prefs?.getInt('selected_audio_index') ?? 0;
    });
  }

  Future<void> _saveSettings() async {
    await _prefs?.setString('default_save_folder', _defaultSaveFolder ?? '');
    await _prefs?.setInt('selected_video_index', _selectedVideoIndex);
    await _prefs?.setInt('selected_audio_index', _selectedAudioIndex);
  }

  Future<void> _listAvailableDevices() async {
    final args = Platform.isWindows
        ? ['-list_devices', 'true', '-f', 'dshow', '-i', 'dummy']
        : ['-f', 'avfoundation', '-list_devices', 'true', '-i', ''];

    try {
      final result = await Process.run('ffmpeg', args, runInShell: true);
      final output = result.stderr.toString();
      final lines = output.split('\n');

      final video = <String>[];
      final audio = <String>[];

      String? mode;
      for (final line in lines) {
        if (line.contains('DirectShow video devices') || line.contains('AVFoundation video devices')) {
          mode = 'video';
        } else if (line.contains('DirectShow audio devices') || line.contains('AVFoundation audio devices')) {
          mode = 'audio';
        } else if (RegExp(r'^\[\d+\]').hasMatch(line.trim())) {
          final match = RegExp(r'^\[(\d+)\] (.+)$').firstMatch(line.trim());
          if (match != null) {
            final index = int.parse(match.group(1)!);
            final name = match.group(2)!;
            if (mode == 'video') {
              video.add('[$index] $name');
            } else if (mode == 'audio') {
              audio.add('[$index] $name');
            }
          }
        }
      }

      setState(() {
        _videoDevices = video;
        _audioDevices = audio;

        // Ensure selected indices are within bounds
        if (_selectedVideoIndex >= _videoDevices.length) {
          _selectedVideoIndex = 0;
        }
        if (_selectedAudioIndex >= _audioDevices.length) {
          _selectedAudioIndex = 0;
        }
      });
    } catch (e) {
      print('Error listing devices: $e');
    }
  }

  Future<void> _initializeCamera() async {
    await _renderer.initialize();

    final constraints = {
      'audio': true,
      'video': {
        'facingMode': 'user',
        'width': widget.videoWidth,
        'height': widget.videoHeight,
        'frameRate': widget.frameRate,
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
        ? '-f avfoundation -pix_fmt uyvy422 -framerate ${widget.frameRate} -video_size ${widget.videoWidth}x${widget.videoHeight} '
        '-i "$_selectedVideoIndex:$_selectedAudioIndex" '
        '-preset ultrafast -crf 23 -r ${widget.frameRate} "$tempPath"'
        : '-f dshow -i video="${_videoDevices[_selectedVideoIndex].replaceAll(RegExp(r'^\[\d+\] '), '')}"'
        ':audio="${_audioDevices[_selectedAudioIndex].replaceAll(RegExp(r'^\[\d+\] '), '')}" '
        '-preset ultrafast -crf 23 -r ${widget.frameRate} "$tempPath"';

    print('Running FFmpeg command:\n$command');

    _ffmpegSession = await FFmpegKit.executeAsync(command, (session) async {
      final returnCode = await session.getReturnCode();
      print('FFmpeg finished with code: $returnCode');

      setState(() {
        _isRecording = false;
        _ffmpegSession = null;
      });

      if (returnCode != null && ReturnCode.isSuccess(returnCode)) {
        _saveRecordedFile(tempPath);
      } else if (returnCode != null && ReturnCode.isCancel(returnCode)) {
        print('Recording was cancelled.');
        _saveRecordedFile(tempPath);
      } else {
        print('Recording failed with code: $returnCode');
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

    // If no default folder is set, prompt user to choose
    if (saveDir == null || saveDir.isEmpty) {
      saveDir = await FilePicker.platform.getDirectoryPath();
      if (saveDir == null) {
        print('User cancelled folder selection.');
        return;
      }
    }

    final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final destination = path.join(saveDir, fileName);

    try {
      await File(tempFilePath).copy(destination);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to: $destination'),
            action: SnackBarAction(
              label: 'Open Folder',
              onPressed: () => _openFolder(saveDir!),
            ),
          ),
        );
      }
    } catch (e) {
      print('Failed to save recording: $e');
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
      builder: (context) => _SettingsDialog(
        videoDevices: _videoDevices,
        audioDevices: _audioDevices,
        selectedVideoIndex: _selectedVideoIndex,
        selectedAudioIndex: _selectedAudioIndex,
        defaultSaveFolder: _defaultSaveFolder,
        onSettingsChanged: (videoIndex, audioIndex, saveFolder) {
          setState(() {
            _selectedVideoIndex = videoIndex;
            _selectedAudioIndex = audioIndex;
            _defaultSaveFolder = saveFolder;
          });
          _saveSettings();
        },
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
    // Calculate the approximate heights of UI elements
    double headerHeight = widget.showHeader ? 40.0 : 0.0;
    double headerSpacing = widget.showHeader ? 8.0 : 0.0;
    double deviceInfoHeight = (widget.showDeviceInfo && _videoDevices.isNotEmpty && _audioDevices.isNotEmpty) ? 90.0 : 0.0;
    double deviceInfoSpacing = (widget.showDeviceInfo && _videoDevices.isNotEmpty && _audioDevices.isNotEmpty) ? 16.0 : 0.0;
    double controlsHeight = 48.0; // Buttons height
    double bottomSpacing = 16.0;
    double recordingStatusHeight = (_outputPath != null && _isRecording) ? 24.0 : 0.0;

    double totalUIHeight = headerHeight + headerSpacing + deviceInfoHeight + deviceInfoSpacing + controlsHeight + bottomSpacing + recordingStatusHeight;

    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        // Calculate available height for video preview
        double availableHeight = widget.height != null ? widget.height! - totalUIHeight : double.infinity;

        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with settings button
              if (widget.showHeader)
                SizedBox(
                  height: headerHeight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Video Capture',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: _showSettingsDialog,
                        tooltip: 'Settings',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                    ],
                  ),
                ),
              if (widget.showHeader) SizedBox(height: headerSpacing),

              // Video preview - flexible sizing
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: widget.height != null ? availableHeight : double.infinity,
                  maxWidth: widget.width ?? double.infinity,
                ),
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
              SizedBox(height: bottomSpacing),

              // Current device info
              if (widget.showDeviceInfo && _videoDevices.isNotEmpty && _audioDevices.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Current Settings:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Video: ${_videoDevices.isNotEmpty ? _videoDevices[_selectedVideoIndex] : 'None'}',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Audio: ${_audioDevices.isNotEmpty ? _audioDevices[_selectedAudioIndex] : 'None'}',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Resolution: ${widget.videoWidth}x${widget.videoHeight} @ ${widget.frameRate}fps',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (_defaultSaveFolder != null && _defaultSaveFolder!.isNotEmpty)
                        Text(
                          'Save to: $_defaultSaveFolder',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              if (widget.showDeviceInfo && _videoDevices.isNotEmpty && _audioDevices.isNotEmpty)
                SizedBox(height: deviceInfoSpacing),

              // Recording controls
              SizedBox(
                height: controlsHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: ElevatedButton.icon(
                        icon: Icon(_isRecording ? Icons.radio_button_checked : Icons.fiber_manual_record),
                        label: Text(_isRecording ? "Recording..." : "Start Recording"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRecording ? Colors.orange : Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: _isRecording ? null : _startRecording,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.stop),
                        label: const Text("Stop Recording"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: _isRecording ? _stopRecording : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (_outputPath != null && _isRecording)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(
                    'Recording in progress...',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        );
      },
    );

    // Apply width and height constraints if provided
    if (widget.width != null || widget.height != null) {
      content = SizedBox(
        width: widget.width,
        height: widget.height,
        child: content,
      );
    }

    return content;
  }
}

class _SettingsDialog extends StatefulWidget {
  final List<String> videoDevices;
  final List<String> audioDevices;
  final int selectedVideoIndex;
  final int selectedAudioIndex;
  final String? defaultSaveFolder;
  final Function(int videoIndex, int audioIndex, String? saveFolder) onSettingsChanged;

  const _SettingsDialog({
    required this.videoDevices,
    required this.audioDevices,
    required this.selectedVideoIndex,
    required this.selectedAudioIndex,
    required this.defaultSaveFolder,
    required this.onSettingsChanged,
  });

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late int _tempVideoIndex;
  late int _tempAudioIndex;
  late String? _tempSaveFolder;

  @override
  void initState() {
    super.initState();
    _tempVideoIndex = widget.selectedVideoIndex;
    _tempAudioIndex = widget.selectedAudioIndex;
    _tempSaveFolder = widget.defaultSaveFolder;
  }

  Future<void> _chooseSaveFolder() async {
    final folder = await FilePicker.platform.getDirectoryPath();
    if (folder != null) {
      setState(() {
        _tempSaveFolder = folder;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Device Selection
            const Text(
              'Video Device:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _tempVideoIndex,
                  items: List.generate(widget.videoDevices.length, (i) {
                    return DropdownMenuItem(
                      value: i,
                      child: Text(
                        widget.videoDevices[i],
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _tempVideoIndex = val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Audio Device Selection
            const Text(
              'Audio Device:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _tempAudioIndex,
                  items: List.generate(widget.audioDevices.length, (i) {
                    return DropdownMenuItem(
                      value: i,
                      child: Text(
                        widget.audioDevices[i],
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _tempAudioIndex = val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Save Folder Selection
            const Text(
              'Default Save Folder:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _tempSaveFolder?.isEmpty == false
                          ? _tempSaveFolder!
                          : 'No folder selected (will prompt each time)',
                      style: TextStyle(
                        color: _tempSaveFolder?.isEmpty == false
                            ? Colors.black
                            : Colors.grey.shade600,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _chooseSaveFolder,
                    child: const Text('Browse'),
                  ),
                ],
              ),
            ),
            if (_tempSaveFolder?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _tempSaveFolder = null;
                  });
                },
                child: const Text('Clear'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSettingsChanged(
              _tempVideoIndex,
              _tempAudioIndex,
              _tempSaveFolder,
            );
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}