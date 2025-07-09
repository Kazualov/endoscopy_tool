import 'package:endoscopy_tool/widgets/video_capturing_widget.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../modules/detection_models.dart';

// Класс для представления интервала детекций
class DetectionInterval {
  final Duration startTime;
  final Duration endTime;
  final String label;
  final double maxConfidence;
  final int detectionCount;

  DetectionInterval({
    required this.startTime,
    required this.endTime,
    required this.label,
    required this.maxConfidence,
    required this.detectionCount,
  });

  Duration get duration => endTime - startTime;
}

// Утилитный класс для группировки детекций
class DetectionGrouper {
  // Максимальный промежуток между детекциями для их объединения (в секундах)
  static const int maxGapSeconds = 1;

  // Группируем детекции в интервалы
  static List<DetectionInterval> groupDetections(List<DetectionBox> detections) {
    if (detections.isEmpty) return [];

    // Сортируем детекции по времени
    final sortedDetections = List<DetectionBox>.from(detections);
    sortedDetections.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Группируем по меткам
    final Map<String, List<DetectionBox>> detectionsByLabel = {};
    for (final detection in sortedDetections) {
      detectionsByLabel.putIfAbsent(detection.label, () => []).add(detection);
    }

    final List<DetectionInterval> intervals = [];

    // Создаем интервалы для каждой метки
    for (final entry in detectionsByLabel.entries) {
      final label = entry.key;
      final labelDetections = entry.value;

      intervals.addAll(_createIntervalsForLabel(label, labelDetections));
    }

    // Сортируем интервалы по времени начала
    intervals.sort((a, b) => a.startTime.compareTo(b.startTime));

    return intervals;
  }

  // Создаем интервалы для конкретной метки
  static List<DetectionInterval> _createIntervalsForLabel(
      String label,
      List<DetectionBox> detections,
      ) {
    final List<DetectionInterval> intervals = [];

    if (detections.isEmpty) return intervals;

    Duration currentStart = detections.first.timestamp;
    Duration currentEnd = detections.first.timestamp;
    double maxConfidence = detections.first.confidence;
    int detectionCount = 1;

    for (int i = 1; i < detections.length; i++) {
      final current = detections[i];
      final gap = current.timestamp - currentEnd;

      // Если промежуток больше максимального, завершаем текущий интервал
      if (gap.inSeconds > maxGapSeconds) {
        intervals.add(DetectionInterval(
          startTime: currentStart,
          endTime: currentEnd,
          label: label,
          maxConfidence: maxConfidence,
          detectionCount: detectionCount,
        ));

        // Начинаем новый интервал
        currentStart = current.timestamp;
        currentEnd = current.timestamp;
        maxConfidence = current.confidence;
        detectionCount = 1;
      } else {
        // Расширяем текущий интервал
        currentEnd = current.timestamp;
        maxConfidence = maxConfidence > current.confidence ? maxConfidence : current.confidence;
        detectionCount++;
      }
    }

    // Добавляем последний интервал
    intervals.add(DetectionInterval(
      startTime: currentStart,
      endTime: currentEnd,
      label: label,
      maxConfidence: maxConfidence,
      detectionCount: detectionCount,
    ));

    return intervals;
  }
}

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
  final List<ScreenshotMarker> screenshotMarkers;
  final List<DetectionBox> detections; // Принимаем сырые детекции
  final Function(Duration)? onMarkerTap;
  final Function(DetectionSegment)? onDetectionIntervalTap; // Используем DetectionSegment

  const VideoPlayerWidget({
    super.key,
    required this.player,
    this.screenshotMarkers = const [],
    this.detections = const [],
    this.onMarkerTap,
    this.onDetectionIntervalTap,
  });


  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late final Player _player;
  late final VideoController _videoController;
  late List<DetectionSegment> _detectionSegments;

  @override
  void initState() {
    super.initState();
    _player = widget.player;
    _videoController = VideoController(_player);
    _updateDetectionSegments();
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detections != widget.detections) {
      _updateDetectionSegments();
    }
  }
  void _updateDetectionSegments() {
    print(widget.detections);
    _detectionSegments = _processDetectionsIntoSegments(widget.detections);

    print('Обновлены сегменты детекций: ${_detectionSegments.length}');
  }

  List<DetectionSegment> _processDetectionsIntoSegments(List<DetectionBox> detections) {
    if (detections.isEmpty) return [];

    print('Обрабатываем ${detections.length} детекций');

    // Группируем детекции по типу (label)
    Map<String, List<DetectionBox>> detectionsByLabel = {};
    for (var detection in detections) {
      detectionsByLabel.putIfAbsent(detection.label, () => []).add(detection);
    }

    List<DetectionSegment> segments = [];

    for (var entry in detectionsByLabel.entries) {
      String label = entry.key;
      List<DetectionBox> labelDetections = entry.value;

      // Сортируем по времени
      labelDetections.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Объединяем близкие детекции в сегменты
      Duration gapThreshold = Duration(seconds: 2);

      Duration? currentSegmentStart;
      Duration? currentSegmentEnd;
      double maxConfidence = 0.0;
      int detectionCount = 0;

      for (int i = 0; i < labelDetections.length; i++) {
        DetectionBox detection = labelDetections[i];

        if (currentSegmentStart == null) {
          currentSegmentStart = detection.timestamp;
          currentSegmentEnd = detection.timestamp;
          maxConfidence = detection.confidence;
          detectionCount = 1;
        } else {
          Duration gap = detection.timestamp - currentSegmentEnd!;

          if (gap <= gapThreshold) {
            currentSegmentEnd = detection.timestamp;
            if (detection.confidence > maxConfidence) {
              maxConfidence = detection.confidence;
            }
            detectionCount++;
          } else {
            // Сохраняем текущий сегмент
            segments.add(DetectionSegment(
              startTime: currentSegmentStart,
              endTime: currentSegmentEnd,
              label: label,
              maxConfidence: maxConfidence,
              detectionCount: detectionCount,
            ));

            // Начинаем новый сегмент
            currentSegmentStart = detection.timestamp;
            currentSegmentEnd = detection.timestamp;
            maxConfidence = detection.confidence;
            detectionCount = 1;
          }
        }
      }

      // Сохраняем последний сегмент
      if (currentSegmentStart != null && currentSegmentEnd != null) {
        segments.add(DetectionSegment(
          startTime: currentSegmentStart,
          endTime: currentSegmentEnd,
          label: label,
          maxConfidence: maxConfidence,
          detectionCount: detectionCount,
        ));
      }
    }

    print('Создано ${segments.length} сегментов детекций');
    return segments;
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

  // Получаем цвет для метки детекций
  Color _getDetectionColor(String label) {
    switch (label.toLowerCase()) {
      case 'полип':
      case 'polyp':
        return const Color(0xFFFF6B6B);
      case 'опухоль':
      case 'tumor':
        return const Color(0xFFFF8E53);
      default:
        return const Color(0xFFFFD93D);
    }
  }

  // Создаем кастомный слайдер с пометками скриншотов и интервалами детекций
  Widget _buildTimelineSlider(Duration position, Duration duration) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double sliderHorizontalPadding = 24.0;
        final double trackWidth = constraints.maxWidth - (sliderHorizontalPadding * 2);

        return Container(
          height: 80, // Увеличиваем высоту для лучшего отображения
          child: Stack(
            children: [
              // Интервалы детекций
              ..._detectionSegments.map((segment) {
                if (duration.inMilliseconds == 0) return const SizedBox.shrink();

                final double startRatio = segment.startTime.inMilliseconds / duration.inMilliseconds;
                final double endRatio = segment.endTime.inMilliseconds / duration.inMilliseconds;

                final double startPosition = sliderHorizontalPadding + (trackWidth * startRatio);
                final double endPosition = sliderHorizontalPadding + (trackWidth * endRatio);
                final double intervalWidth = (endPosition - startPosition).clamp(8.0, trackWidth);

                return Positioned(
                  left: startPosition,
                  top: 10,
                  child: GestureDetector(
                    onTap: () {
                      print('Клик по сегменту: ${segment.label} в ${segment.startTime}');
                      _player.seek(segment.startTime);
                      widget.onDetectionIntervalTap?.call(segment);
                    },
                    child: Container(
                      width: intervalWidth,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getDetectionColor(segment.label).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Tooltip(
                        message: '${segment.label}: ${segment.detectionCount} детекций\n'
                            'Время: ${_formatDuration(segment.startTime)} - ${_formatDuration(segment.endTime)}\n'
                            'Уверенность: ${(segment.maxConfidence * 100).toStringAsFixed(1)}%',
                        child: Container(),
                      ),
                    ),
                  ),
                );
              }).toList(),

              // Основной слайдер
              Positioned(
                left: 0,
                right: 0,
                top: 35,
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

                final double markerRatio = marker.timestamp.inMilliseconds / duration.inMilliseconds;
                final double markerLeftPosition = sliderHorizontalPadding + (trackWidth * markerRatio) - 2;

                return Positioned(
                  left: markerLeftPosition,
                  top: 41,
                  child: GestureDetector(
                    onTap: () {
                      _player.seek(marker.timestamp);
                      widget.onMarkerTap?.call(marker.timestamp);
                    },
                    child: Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF01a3a2),
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

            // Кастомный таймлайн с пометками и интервалами детекций
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