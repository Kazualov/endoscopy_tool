import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

// Модель для пометки скриншота на таймлайне
class ScreenshotMarker {
  final Duration timestamp;
  final String screenshotId;

  ScreenshotMarker({
    required this.timestamp,
    required this.screenshotId,
  });
}

class VideoPlayerWidget extends StatefulWidget {
  final Player player;
  final List<ScreenshotMarker> screenshotMarkers; // Добавляем список пометок
  final Function(Duration)? onMarkerTap; // Колбэк для клика по пометке

  const VideoPlayerWidget({
    super.key,
    required this.player,
    this.screenshotMarkers = const [],
    this.onMarkerTap,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late final Player _player;
  late final VideoController _videoController;

  @override
  void initState() {
    super.initState();
    _player = widget.player;
    _videoController = VideoController(_player);
  }

  @override
  void dispose() {
    // DO NOT dispose the player here if it's managed externally.
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // Создаем кастомный слайдер с пометками скриншотов
  Widget _buildTimelineSlider(Duration position, Duration duration) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Стандартные отступы слайдера Material Design
        const double sliderHorizontalPadding = 24.0;
        const double thumbRadius = 8.0;

        // Доступная ширина для трека слайдера
        final double trackWidth = constraints.maxWidth - (sliderHorizontalPadding * 2);

        return Container(
          height: 50,
          child: Stack(
            children: [
              // Основной слайдер
              Positioned(
                left: 0,
                right: 0,
                top: 15,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 6.0,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
                  ),
                  child: Slider(
                    activeColor: const Color(0xFF00ACAB),
                    inactiveColor: Colors.grey[300],
                    min: 0,
                    max: duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                    value: position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble(),
                    onChanged: (value) {
                      _player.seek(Duration(milliseconds: value.toInt()));
                    },
                  ),
                ),
              ),

              // Пометки скриншотов
              ...widget.screenshotMarkers.map((marker) {
                if (duration.inMilliseconds == 0) return const SizedBox.shrink();

                // Точный расчет позиции пометки
                final double markerRatio = marker.timestamp.inMilliseconds / duration.inMilliseconds;
                final double markerLeftPosition = sliderHorizontalPadding + (trackWidth * markerRatio) - 2; // -2 для центрирования линии (ширина 4px)

                return Positioned(
                  left: markerLeftPosition,
                  top: 21,
                  child: GestureDetector(
                    onTap: () {
                      // Переходим к позиции скриншота
                      _player.seek(marker.timestamp);
                      widget.onMarkerTap?.call(marker.timestamp);
                    },
                    child: Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Color(0xFF01a3a2),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: _player.streams.position,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = _player.state.duration;

        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Video(controller: _videoController, controls: NoVideoControls),
            ),

            IconButton(
              icon: Icon(
                color: const Color(0xFF00ACAB),
                _player.state.playing ? Icons.pause : Icons.play_arrow_rounded,
                size: 60,
              ),
              onPressed: () {
                setState(() {
                  _player.state.playing ? _player.pause() : _player.play();
                });
              },
            ),

            // Кастомный таймлайн с пометками
            _buildTimelineSlider(position, duration),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(position)),
                  Text(_formatDuration(duration)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}