class DetectionSegment {
  final Duration startTime;
  final Duration endTime;
  final String label;
  final double maxConfidence;
  final int detectionCount;

  DetectionSegment({
    required this.startTime,
    required this.endTime,
    required this.label,
    required this.maxConfidence,
    required this.detectionCount,
  });

  Duration get duration => endTime - startTime;
}