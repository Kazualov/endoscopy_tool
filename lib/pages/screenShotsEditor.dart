import 'dart:io';
import 'dart:ui';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

// ──────────────────────────────────────────────────────────────────────
//  Screenshot Editor – v2
//  • Rectangle, Pen, Eraser
//  • Color palette
//  • Undo / Redo
//  • Save annotated image  → call  `await editorKey.currentState!.save()`
// ──────────────────────────────────────────────────────────────────────
enum Tool { rect, pen, eraser }
enum EraserMode { pixel, shape }

abstract class _Mark {
  final Paint paint;
  _Mark(Color color) : paint = Paint()
    ..color = color
    ..strokeWidth = 3
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  void draw(Canvas canvas);
  bool hit(Offset point); // for shape eraser
  _Mark? erasePixel(Offset point, double radius); // for pixel eraser
}

class _RectMark extends _Mark {
  Rect rect;
  _RectMark(this.rect, Color c) : super(c);

  @override
  void draw(Canvas canvas) => canvas.drawRect(rect, paint);

  @override
  bool hit(Offset p) {
    // Check if point is on the rectangle border (not inside)
    final tolerance = 8.0;
    final outerRect = rect.inflate(tolerance);
    final innerRect = rect.deflate(tolerance);
    return outerRect.contains(p) && !innerRect.contains(p);
  }

  @override
  _Mark? erasePixel(Offset point, double radius) {
    // For rectangles, we don't support pixel erasing - only shape erasing
    return hit(point) ? null : this;
  }
}

class _PathMark extends _Mark {
  final Path path;
  final List<Offset> points; // Store original points for pixel erasing

  _PathMark(this.path, Color c, this.points) : super(c);

  @override
  void draw(Canvas canvas) => canvas.drawPath(path, paint);

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
  _Mark? erasePixel(Offset point, double radius) {
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

    return _PathMark(newPath, paint.color, newPoints);
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

class ScreenshotEditor extends StatefulWidget {
  final ImageProvider screenshot;
  final List<ImageProvider> otherScreenshots;
  const ScreenshotEditor({
    super.key,
    required this.screenshot,
    required this.otherScreenshots,
  });

  @override
  State<ScreenshotEditor> createState() => ScreenshotEditorState();
}

class ScreenshotEditorState extends State<ScreenshotEditor> {
  // Tools & palette
  Tool _tool = Tool.rect;
  EraserMode _eraserMode = EraserMode.shape;
  int _colorIx = 0;
  final _colors = [Colors.red, Colors.green, Colors.blue, Colors.orange, Colors.purple];

  // Marks & history
  final List<_Mark> _marks = [];
  final List<List<_Mark>> _undoStack = [];
  final List<List<_Mark>> _redoStack = [];

  // In‑progress drawing
  Rect? _draftRect;
  Path? _draftPath;
  List<Offset> _draftPoints = []; // For storing path points
  Offset? _rectStart;

  // Keys
  final GlobalKey _repaintKey = GlobalKey();

  Color get _currentColor => _colors[_colorIx];

  void _pushUndo() {
    _undoStack.add(List.of(_marks));
    _redoStack.clear();
  }

  void _onUndo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(List.of(_marks));
    setState(() => _marks
      ..clear()
      ..addAll(_undoStack.removeLast()));
  }

  void _onRedo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(List.of(_marks));
    setState(() => _marks
      ..clear()
      ..addAll(_redoStack.removeLast()));
  }

  // Erase based on current eraser mode
  void _eraseAt(Offset p) {
    if (_eraserMode == EraserMode.shape) {
      _eraseShape(p);
    } else {
      _erasePixel(p);
    }
  }

  // Erase first mark under point (original behavior)
  void _eraseShape(Offset p) {
    for (int i = _marks.length - 1; i >= 0; --i) {
      if (_marks[i].hit(p)) {
        _pushUndo();
        setState(() => _marks.removeAt(i));
        break;
      }
    }
  }

  // Pixel-based erasing
  void _erasePixel(Offset p) {
    const eraserRadius = 15.0;
    bool hasChanges = false;
    _pushUndo();

    setState(() {
      final List<_Mark> newMarks = [];

      for (final mark in _marks) {
        final result = mark.erasePixel(p, eraserRadius);
        if (result != null) {
          newMarks.add(result);
          if (result != mark) hasChanges = true;
        } else {
          hasChanges = true;
        }
      }

      if (hasChanges) {
        _marks.clear();
        _marks.addAll(newMarks);
      }
    });
  }

  // Toggle eraser mode on double tap when eraser is selected
  void _toggleEraserMode() {
    if (_tool == Tool.eraser) {
      setState(() {
        _eraserMode = _eraserMode == EraserMode.shape
            ? EraserMode.pixel
            : EraserMode.shape;
      });
    }
  }

  // Save composite image to Documents directory, returns path
  Future<String> save() async {
    final boundary = _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image img = await boundary.toImage(pixelRatio: 3);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/annotated_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceVariant,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLeft(theme),
            Expanded(child: _buildStage()),
            _buildRight(theme),
          ],
        ),
      ),
    );
  }

  // ───────────────── Left sidebar ─────────────────
  Widget _buildLeft(ThemeData t) {
    const icons = [Icons.crop_square, Icons.auto_fix_off, Icons.edit];
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
        boxShadow: const [BoxShadow(blurRadius: 8, offset: Offset(0, 2), color: Colors.black26)],
      ),
      child: Column(
        children: [
          const SizedBox(height: 48),
          for (int i = 0; i < icons.length; ++i)
            GestureDetector(
              onDoubleTap: i == 1 ? _toggleEraserMode : null, // Double tap on eraser to toggle mode
              child: _ToolBtn(
                icon: icons[i],
                active: _tool.index == i,
                onTap: () => setState(() => _tool = Tool.values[i]),
                subtitle: i == 1 && _tool == Tool.eraser
                    ? (_eraserMode == EraserMode.shape ? 'Shape' : 'Pixel')
                    : null,
              ),
            ),
          const SizedBox(height: 24),
          // Palette
          ...List.generate(_colors.length, (i) => GestureDetector(
            onTap: () => setState(() => _colorIx = i),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _colors[i],
                shape: BoxShape.circle,
                border: Border.all(color: i == _colorIx ? Colors.white : Colors.transparent, width: 3),
              ),
            ),
          )),
          const Spacer(),
          _ToolBtn(icon: Icons.undo, onTap: _onUndo),
          _ToolBtn(icon: Icons.redo, onTap: _onRedo),
        ],
      ),
    );
  }

  // ───────────────── Stage ─────────────────
  Widget _buildStage() {
    return Center(
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: RepaintBoundary(
          key: _repaintKey,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (d) {
              final local = _eventPos(d.localPosition);
              switch (_tool) {
                case Tool.rect:
                  _rectStart = local;
                  _draftRect = Rect.fromPoints(local, local);
                  break;
                case Tool.pen:
                  _draftPoints = [local];
                  _draftPath = Path()..moveTo(local.dx, local.dy);
                  break;
                case Tool.eraser:
                  _eraseAt(local);
                  break;
              }
            },
            onPanUpdate: (d) {
              final local = _eventPos(d.localPosition);
              setState(() {
                switch (_tool) {
                  case Tool.rect:
                    if (_rectStart != null) {
                      _draftRect = Rect.fromPoints(_rectStart!, local);
                    }
                    break;
                  case Tool.pen:
                    _draftPoints.add(local);
                    _draftPath!.lineTo(local.dx, local.dy);
                    break;
                  case Tool.eraser:
                    _eraseAt(local);
                    break;
                }
              });
            },
            onPanEnd: (_) {
              if (_draftRect != null || _draftPath != null) {
                _pushUndo();
                if (_draftRect != null) {
                  _marks.add(_RectMark(_draftRect!, _currentColor));
                }
                if (_draftPath != null && _draftPoints.length > 1) {
                  _marks.add(_PathMark(_draftPath!, _currentColor, List.of(_draftPoints)));
                }
              }
              _draftRect = null;
              _draftPath = null;
              _draftPoints.clear();
              _rectStart = null;
            },
            child: CustomPaint(
              painter: _StagePainter(
                widget.screenshot,
                _marks,
                draftRect: _draftRect,
                draftPath: _draftPath,
                draftPaint: Paint()
                  ..color = _currentColor
                  ..strokeWidth = 3
                  ..style = PaintingStyle.stroke
                  ..strokeCap = StrokeCap.round,
                eraserMode: _tool == Tool.eraser ? _eraserMode : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset _eventPos(Offset raw) {
    // GestureDetector delivers local offset inside AspectRatio, fine
    return raw;
  }

  // ───────────────── Right thumbs ─────────────────
  Widget _buildRight(ThemeData t) => Container(
    width: 96,
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: t.colorScheme.surface,
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
      boxShadow: const [BoxShadow(blurRadius: 8, offset: Offset(0, 2), color: Colors.black26)],
    ),
    child: ListView.builder(
      itemCount: widget.otherScreenshots.length,
      itemBuilder: (c, i) => Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400, width: 2),
        ),
        clipBehavior: Clip.hardEdge,
        child: Image(image: widget.otherScreenshots[i], fit: BoxFit.cover),
      ),
    ),
  );
}

// ───────────────── Painter ─────────────────
class _StagePainter extends CustomPainter {
  final ImageProvider bg;
  final List<_Mark> marks;
  final Rect? draftRect;
  final Path? draftPath;
  final Paint draftPaint;
  final EraserMode? eraserMode;
  ui.Image? _bgImage;

  _StagePainter(this.bg, this.marks, {
    this.draftRect,
    this.draftPath,
    required this.draftPaint,
    this.eraserMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background once loaded
    if (_bgImage == null) {
      final stream = bg.resolve(const ImageConfiguration());
      stream.addListener(ImageStreamListener((ImageInfo info, _) {
        _bgImage = info.image;
        // ignore painter param in listener; external repaint
      }));
    }
    if (_bgImage != null) {
      paintBackground(canvas, size);
    }

    for (final m in marks) m.draw(canvas);
    if (draftRect != null) canvas.drawRect(draftRect!, draftPaint);
    if (draftPath != null) canvas.drawPath(draftPath!, draftPaint);
  }

  void paintBackground(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(0, 0, _bgImage!.width.toDouble(), _bgImage!.height.toDouble());
    final fittedSizes = applyBoxFit(BoxFit.contain, src.size, size);
    final output = Alignment.center.inscribe(fittedSizes.destination, Offset.zero & size);
    canvas.drawImageRect(_bgImage!, src, output, Paint());
  }

  @override
  bool shouldRepaint(covariant _StagePainter old) => true;
}

// ───────────────── Helper ─────────────────
class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final String? subtitle;

  const _ToolBtn({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: active ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: active ? Colors.white : Theme.of(context).iconTheme.color),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 10,
                color: active ? Colors.white : Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}