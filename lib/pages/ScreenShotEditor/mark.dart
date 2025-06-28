import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/material.dart';

enum Tool { rect, pen, eraser, select }
enum EraserMode { pixel, shape }

abstract class Mark {
  final Paint paint;
  bool selected = false;

  Mark(Color color, double strokeWidth) : paint = Paint()
    ..color = color
    ..strokeWidth = strokeWidth
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  void draw(ui.Canvas canvas);
  void drawSelection(ui.Canvas canvas);
  bool hit(Offset point);
  Mark? erasePixel(Offset point, double radius);
  void move(Offset delta);
  Rect getBounds();
  List<ResizeHandle> getResizeHandles();
  void resize(HandleType handle, Offset newPosition);
}

class RectMark extends Mark {
  Rect rect;

  RectMark(this.rect, Color c, double strokeWidth) : super(c, strokeWidth);

  @override
  void draw(Canvas canvas) => canvas.drawRect(rect, paint);

  @override
  void drawSelection(Canvas canvas) {
    if (!selected) return;

    // Draw selection border
    final selectionPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(rect.inflate(5), selectionPaint);

    // Draw resize handles
    final handles = getResizeHandles();
    final handlePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    for (final handle in handles) {
      canvas.drawRect(handle.rect, handlePaint);
    }
  }

  @override
  bool hit(Offset p) {
    // Check if point is on the rectangle border (not inside)
    final tolerance = 8.0;
    final outerRect = rect.inflate(tolerance);
    final innerRect = rect.deflate(tolerance);
    return outerRect.contains(p) && !innerRect.contains(p);
  }

  @override
  Mark? erasePixel(Offset point, double radius) {
    // For rectangles, we don't support pixel erasing - only shape erasing
    return hit(point) ? null : this;
  }

  @override
  void move(Offset delta) {
    rect = rect.translate(delta.dx, delta.dy);
  }

  @override
  Rect getBounds() => rect;

  @override
  List<ResizeHandle> getResizeHandles() {
    const handleSize = 8.0;
    final handles = <ResizeHandle>[];

    // Corner handles
    handles.add(ResizeHandle(
        Rect.fromCenter(center: rect.topLeft, width: handleSize, height: handleSize),
        HandleType.topLeft
    ));
    handles.add(ResizeHandle(
        Rect.fromCenter(center: rect.topRight, width: handleSize, height: handleSize),
        HandleType.topRight
    ));
    handles.add(ResizeHandle(
        Rect.fromCenter(center: rect.bottomLeft, width: handleSize, height: handleSize),
        HandleType.bottomLeft
    ));
    handles.add(ResizeHandle(
        Rect.fromCenter(center: rect.bottomRight, width: handleSize, height: handleSize),
        HandleType.bottomRight
    ));

    // Edge handles
    handles.add(ResizeHandle(
        Rect.fromCenter(center: Offset(rect.center.dx, rect.top), width: handleSize, height: handleSize),
        HandleType.top
    ));
    handles.add(ResizeHandle(
        Rect.fromCenter(center: Offset(rect.center.dx, rect.bottom), width: handleSize, height: handleSize),
        HandleType.bottom
    ));
    handles.add(ResizeHandle(
        Rect.fromCenter(center: Offset(rect.left, rect.center.dy), width: handleSize, height: handleSize),
        HandleType.left
    ));
    handles.add(ResizeHandle(
        Rect.fromCenter(center: Offset(rect.right, rect.center.dy), width: handleSize, height: handleSize),
        HandleType.right
    ));

    return handles;
  }

  @override
  void resize(HandleType handle, Offset newPosition) {
    switch (handle) {
      case HandleType.topLeft:
        rect = Rect.fromLTRB(newPosition.dx, newPosition.dy, rect.right, rect.bottom);
        break;
      case HandleType.topRight:
        rect = Rect.fromLTRB(rect.left, newPosition.dy, newPosition.dx, rect.bottom);
        break;
      case HandleType.bottomLeft:
        rect = Rect.fromLTRB(newPosition.dx, rect.top, rect.right, newPosition.dy);
        break;
      case HandleType.bottomRight:
        rect = Rect.fromLTRB(rect.left, rect.top, newPosition.dx, newPosition.dy);
        break;
      case HandleType.top:
        rect = Rect.fromLTRB(rect.left, newPosition.dy, rect.right, rect.bottom);
        break;
      case HandleType.bottom:
        rect = Rect.fromLTRB(rect.left, rect.top, rect.right, newPosition.dy);
        break;
      case HandleType.left:
        rect = Rect.fromLTRB(newPosition.dx, rect.top, rect.right, rect.bottom);
        break;
      case HandleType.right:
        rect = Rect.fromLTRB(rect.left, rect.top, newPosition.dx, rect.bottom);
        break;
    }
  }
}

class PathMark extends Mark {
  final Path path;
  final List<Offset> points; // Store original points for pixel erasing

  PathMark(this.path, Color c, double strokeWidth, this.points) : super(c, strokeWidth);

  @override
  void draw(Canvas canvas) => canvas.drawPath(path, paint);

  @override
  void drawSelection(Canvas canvas) {
    if (!selected) return;

    // Draw selection border around path bounds
    final bounds = getBounds();
    final selectionPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(bounds.inflate(5), selectionPaint);
  }

  @override
  bool hit(Offset p) {
    // Check if point is near any segment of the path
    const tolerance = 12.0;
    for (int i = 0; i < points.length - 1; i++) {
      final start = points[i];
      final end = points[i + 1];
      if (_distanceToLineSegment(p, start, end) < tolerance) {
        return true;
      }
    }
    return false;
  }

  @override
  Mark? erasePixel(Offset point, double radius) {
    // Remove points that are within the eraser radius
    final newPoints = <Offset>[];
    bool hasChanges = false;

    for (final p in points) {
      final distance = (p - point).distance;
      if (distance > radius) {
        newPoints.add(p);
      } else {
        hasChanges = true;
      }
    }

    // If no points left or too few points, return null (delete mark)
    if (newPoints.length < 2) return null;

    // If no changes, return original mark
    if (!hasChanges) return this;

    // Create new path from remaining points
    final newPath = Path();
    if (newPoints.isNotEmpty) {
      newPath.moveTo(newPoints.first.dx, newPoints.first.dy);
      for (int i = 1; i < newPoints.length; i++) {
        newPath.lineTo(newPoints[i].dx, newPoints[i].dy);
      }
    }

    return PathMark(newPath, paint.color, paint.strokeWidth, newPoints);
  }

  @override
  void move(Offset delta) {
    // Move all points
    for (int i = 0; i < points.length; i++) {
      points[i] = points[i] + delta;
    }

    // Recreate path
    path.reset();
    if (points.isNotEmpty) {
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
    }
  }

  @override
  Rect getBounds() {
    if (points.isEmpty) return Rect.zero;

    double minX = points.first.dx;
    double maxX = points.first.dx;
    double minY = points.first.dy;
    double maxY = points.first.dy;

    for (final point in points) {
      minX = minX < point.dx ? minX : point.dx;
      maxX = maxX > point.dx ? maxX : point.dx;
      minY = minY < point.dy ? minY : point.dy;
      maxY = maxY > point.dy ? maxY : point.dy;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  @override
  List<ResizeHandle> getResizeHandles() {
    // Paths don't support resizing, only moving
    return [];
  }

  @override
  void resize(HandleType handle, Offset newPosition) {
    // Paths don't support resizing
  }

  double _distanceToLineSegment(Offset point, Offset start, Offset end) {
    final A = point.dx - start.dx;
    final B = point.dy - start.dy;
    final C = end.dx - start.dx;
    final D = end.dy - start.dy;

    final dot = A * C + B * D;
    final lenSq = C * C + D * D;

    if (lenSq == 0) return (point - start).distance;

    final param = dot / lenSq;

    Offset projection;
    if (param < 0) {
      projection = start;
    } else if (param > 1) {
      projection = end;
    } else {
      projection = Offset(start.dx + param * C, start.dy + param * D);
    }

    return (point - projection).distance;
  }
}



enum HandleType {
  topLeft, topRight, bottomLeft, bottomRight,
  top, bottom, left, right
}

class ResizeHandle {
  final Rect rect;
  final HandleType type;

  ResizeHandle(this.rect, this.type);

  bool contains(Offset point) => rect.contains(point);
}