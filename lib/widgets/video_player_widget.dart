import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final VideoPlayerController controller;
  const VideoPlayerWidget({super.key, required this.controller});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _controller.initialize().then((_) {
      setState(() {});
    });

    _controller.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    super.dispose();
    // Do not dispose the controller here, because MainPage owns it.
  }

  String _formatDuration(Duration position) {
    final minutes = position.inMinutes.toString().padLeft(2, '0');
    final seconds = (position.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_controller.value.isInitialized)
          AspectRatio(
            aspectRatio: 16/10,
            //aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          )
        else
          const Center(child: CircularProgressIndicator()),

        //const SizedBox(),

        // Play/Pause Button
        if (_controller.value.isInitialized)
          IconButton(
          icon: Icon(
            color: Color(0xFF00ACAB),
            _controller.value.isPlaying ? Icons.pause : Icons.play_arrow_rounded,
            size: 60,
          ),
          onPressed: () {
            setState(() {
              _controller.value.isPlaying
                  ? _controller.pause()
                  : _controller.play();
            });
          },
        ),

        // Timeline (Progress Bar)
        if (_controller.value.isInitialized)
          Column(
            children: [
              Slider(
                activeColor: Color(0xFF00ACAB),
                min: 0,
                max: _controller.value.duration.inMilliseconds.toDouble(),
                value: _controller.value.position.inMilliseconds.clamp(
                  0,
                  _controller.value.duration.inMilliseconds,
                ).toDouble(),
                onChanged: (value) {
                  _controller.seekTo(Duration(milliseconds: value.toInt()));
                },
              ),

              // Current time / total time
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(_controller.value.position)),
                    Text(_formatDuration(_controller.value.duration)),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}
