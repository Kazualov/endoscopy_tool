import 'dart:io';
import 'dart:ui';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

// ──────────────────────────────────────────────────────────────────────
//  Enhanced Screenshot Editor – with drag, resize, and stroke width
//  • Rectangle, Pen, Eraser
//  • Drag and resize shapes
//  • Stroke width adjustment
//  • Color palette
//  • Undo / Redo
//  • Zoom & Pan support
// ──────────────────────────────────────────────────────────────────────

enum Tool { rect, pen, eraser, select, circle, arrow }
enum EraserMode { pixel, shape }

// Handle types for rectangle resizing
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

abstract class _Mark {
  final Paint paint;
  bool selected = false;

  _Mark(Color color, double strokeWidth) : paint = Paint()
    ..color = color
    ..strokeWidth = strokeWidth
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  void draw(Canvas canvas);
  void drawSelection(Canvas canvas); // Draw selection indicators
  bool hit(Offset point); // for shape eraser and selection
  _Mark? erasePixel(Offset point, double radius); // for pixel eraser
  void move(Offset delta); // Move the shape
  Rect getBounds(); // Get bounding rectangle
  List<ResizeHandle> getResizeHandles(); // Get resize handles (for rectangles)
  void resize(HandleType handle, Offset newPosition); // Resize shape
}

class _RectMark extends _Mark {
  Rect rect;

  _RectMark(this.rect, Color c, double strokeWidth) : super(c, strokeWidth);

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
  _Mark? erasePixel(Offset point, double radius) {
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

class _PathMark extends _Mark {
  final Path path;
  final List<Offset> points; // Store original points for pixel erasing

  _PathMark(this.path, Color c, double strokeWidth, this.points) : super(c, strokeWidth);

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

    return _PathMark(newPath, paint.color, paint.strokeWidth, newPoints);
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

class _CircleMark extends _Mark {
  Rect rect; // Используем rect для определения границ круга

  _CircleMark(this.rect, Color c, double strokeWidth) : super(c, strokeWidth);

  @override
  void draw(Canvas canvas) {
    final center = rect.center;
    final radius = (rect.width < rect.height ? rect.width : rect.height) / 2;
    canvas.drawCircle(center, radius, paint);
  }

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
    final center = rect.center;
    final radius = (rect.width < rect.height ? rect.width : rect.height) / 2;
    final distance = (p - center).distance;
    const tolerance = 8.0;
    return (distance >= radius - tolerance && distance <= radius + tolerance);
  }

  @override
  _Mark? erasePixel(Offset point, double radius) {
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
      default:
      // Круг не поддерживает изменение размера по краям
        break;
    }
  }
}

// 3. Добавьте новый класс для стрелки
class _ArrowMark extends _Mark {
  Offset start;
  Offset end;

  _ArrowMark(this.start, this.end, Color c, double strokeWidth) : super(c, strokeWidth);

  @override
  void draw(Canvas canvas) {
    // Рисуем линию
    canvas.drawLine(start, end, paint);

    // Рисуем наконечник стрелки
    _drawArrowHead(canvas);
  }

  void _drawArrowHead(Canvas canvas) {
    final arrowPaint = Paint()
      ..color = paint.color
      ..strokeWidth = paint.strokeWidth
      ..style = PaintingStyle.fill;

    // Вычисляем направление стрелки
    final direction = end - start;
    final length = direction.distance;

    if (length == 0) return;

    final unitVector = direction / length;
    final arrowLength = 20.0;
    final arrowAngle = 0.5; // радианы

    // Точки для наконечника стрелки
    final arrowBack = end - unitVector * arrowLength;
    final perpendicular = Offset(-unitVector.dy, unitVector.dx);

    final arrowPoint1 = arrowBack + perpendicular * arrowLength * 0.3;
    final arrowPoint2 = arrowBack - perpendicular * arrowLength * 0.3;

    // Рисуем наконечник
    final arrowPath = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(arrowPoint1.dx, arrowPoint1.dy)
      ..lineTo(arrowPoint2.dx, arrowPoint2.dy)
      ..close();

    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  void drawSelection(Canvas canvas) {
    if (!selected) return;

    // Draw selection border around arrow bounds
    final bounds = getBounds();
    final selectionPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(bounds.inflate(5), selectionPaint);

    // Draw handles at start and end
    final handlePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    const handleSize = 8.0;
    canvas.drawRect(
        Rect.fromCenter(center: start, width: handleSize, height: handleSize),
        handlePaint
    );
    canvas.drawRect(
        Rect.fromCenter(center: end, width: handleSize, height: handleSize),
        handlePaint
    );
  }

  @override
  bool hit(Offset p) {
    const tolerance = 12.0;
    return _distanceToLineSegment(p, start, end) < tolerance;
  }

  @override
  _Mark? erasePixel(Offset point, double radius) {
    return hit(point) ? null : this;
  }

  @override
  void move(Offset delta) {
    start = start + delta;
    end = end + delta;
  }

  @override
  Rect getBounds() {
    return Rect.fromPoints(start, end);
  }

  @override
  List<ResizeHandle> getResizeHandles() {
    const handleSize = 8.0;
    return [
      ResizeHandle(
          Rect.fromCenter(center: start, width: handleSize, height: handleSize),
          HandleType.topLeft // Используем как start point
      ),
      ResizeHandle(
          Rect.fromCenter(center: end, width: handleSize, height: handleSize),
          HandleType.bottomRight // Используем как end point
      ),
    ];
  }

  @override
  void resize(HandleType handle, Offset newPosition) {
    switch (handle) {
      case HandleType.topLeft:
        start = newPosition;
        break;
      case HandleType.bottomRight:
        end = newPosition;
        break;
      default:
        break;
    }
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

class ScreenshotEditorState extends State<ScreenshotEditor> with TickerProviderStateMixin {
  late ImageProvider _activeScreenshot;
  late List<ImageProvider> _otherScreenshots;
  // Tools & palette
  Tool _tool = Tool.rect;
  EraserMode _eraserMode = EraserMode.shape;
  int _colorIx = 0;
  double _strokeWidth = 3.0;
  final _colors = [Colors.red, Colors.green, Colors.blue];

  // Marks & history
  final List<_Mark> _marks = [];
  final List<List<_Mark>> _undoStack = [];
  final List<List<_Mark>> _redoStack = [];

  // In‑progress drawing
  Rect? _draftRect;
  Path? _draftPath;
  List<Offset> _draftPoints = []; // For storing path points
  Offset? _rectStart;

  // Selection and dragging
  _Mark? _selectedMark;
  bool _isDragging = false;
  bool _isResizing = false;
  HandleType? _resizeHandle;
  Offset? _dragStart;
  Offset? _circleStart;
  Offset? _arrowStart;
  Offset? _draftArrowEnd;

  // Transform controls
  late TransformationController _transformController;

  // Keys
  final GlobalKey _repaintKey = GlobalKey();

  Color get _currentColor => _colors[_colorIx];

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _activeScreenshot = widget.screenshot;
    _otherScreenshots = List.from(widget.otherScreenshots);
  }


  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _switchToScreenshot(int index) {
    setState(() {
      final newActive = _otherScreenshots.removeAt(index);
      _otherScreenshots.add(_activeScreenshot);
      _activeScreenshot = newActive;
    });
  }


  void _pushUndo() {
    _undoStack.add(List.of(_marks));
    _redoStack.clear();
  }

  void _onUndo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(List.of(_marks));
    setState(() {
      _marks.clear();
      _marks.addAll(_undoStack.removeLast());
      _selectedMark = null;
    });
  }

  void _onRedo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(List.of(_marks));
    setState(() {
      _marks.clear();
      _marks.addAll(_redoStack.removeLast());
      _selectedMark = null;
    });
  }

  // Coordinate transformation
  Offset _screenToImageCoords(Offset screenPoint, Size canvasSize) {
    final matrix = _transformController.value;
    final invertedMatrix = Matrix4.inverted(matrix);
    final vector = Vector4(screenPoint.dx, screenPoint.dy, 0, 1);
    final transformed = invertedMatrix.transform(vector);
    return Offset(transformed.x, transformed.y);
  }

  // Selection logic
  _Mark? _findMarkAt(Offset point) {
    // Search from top to bottom (reverse order)
    for (int i = _marks.length - 1; i >= 0; i--) {
      if (_marks[i].hit(point)) {
        return _marks[i];
      }
    }
    return null;
  }

  ResizeHandle? _findResizeHandle(Offset point) {
    if (_selectedMark == null) return null;

    final handles = _selectedMark!.getResizeHandles();
    for (final handle in handles) {
      if (handle.contains(point)) {
        return handle;
      }
    }
    return null;
  }

  void _selectMark(_Mark? mark) {
    setState(() {
      // Deselect all marks
      for (final m in _marks) {
        m.selected = false;
      }

      // Select new mark
      _selectedMark = mark;
      if (mark != null) {
        mark.selected = true;
      }
    });
  }

  // Erase based on current eraser mode
  void _eraseAt(Offset imagePoint) {
    if (_eraserMode == EraserMode.shape) {
      _eraseShape(imagePoint);
    } else {
      _erasePixel(imagePoint);
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
    // Scale eraser radius based on current zoom level
    final scale = _transformController.value.getMaxScaleOnAxis();
    final eraserRadius = 15.0 / scale;

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

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  // Save composite image to Documents directory, returns path
  Future<String> save() async {
    final boundary = _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image img = await boundary.toImage(pixelRatio: 3);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/annotated_${DateTime.now().millisecondsSinceEpoch}.png');
    print(file);
    await file.writeAsBytes(bytes);
    return file.path;
  }

  // Добавьте кнопку сохранения в ваш UI
  Widget _buildSaveButton(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(8),
      child: FloatingActionButton(
        onPressed: save,
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.save),
      ),
    );
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
      floatingActionButton: _buildSaveButton(theme),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

// ───────────────── Left sidebar ─────────────────
  Widget _buildLeft(ThemeData t) {
    const icons = [
      Icons.crop_square,
      Icons.edit,
      Icons.auto_fix_off,
      Icons.near_me,
      Icons.circle_outlined,
      Icons.arrow_forward,
    ];

    return Container(
      width: 120, // Увеличенная ширина
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(blurRadius: 8, offset: Offset(0, 2), color: Colors.black26),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 48),

          // Инструменты: 2 в ряд
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(icons.length, (i) {
              return GestureDetector(
                onDoubleTap: i == 2 ? _toggleEraserMode : null,
                child: _ToolBtn(
                  icon: icons[i],
                  active: _tool.index == i,
                  onTap: () => setState(() => _tool = Tool.values[i]),
                  subtitle: i == 2 && _tool == Tool.eraser
                      ? (_eraserMode == EraserMode.shape ? 'Shape' : 'Pixel')
                      : null,
                ),
              );
            }),
          ),

          const SizedBox(height: 16),

          // Толщина
          Column(
            children: [
              Text('Width', style: TextStyle(fontSize: 10, color: t.textTheme.bodySmall?.color)),
              RotatedBox(
                quarterTurns: 3,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 1.5,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                  ),
                  child: Slider(
                    value: _strokeWidth,
                    min: 1.0,
                    max: 4.0,
                    divisions: 4,
                    onChanged: (value) => setState(() => _strokeWidth = value),
                  ),
                ),
              ),
              Text('${_strokeWidth.round()}', style: const TextStyle(fontSize: 10)),
            ],
          ),

          const SizedBox(height: 12),

          // Палитра
          ...List.generate(_colors.length, (i) {
            final isSelected = i == _colorIx;
            return GestureDetector(
              onTap: () => setState(() => _colorIx = i),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                width: isSelected ? 45 : 32,
                height: isSelected ? 45 : 32,
                decoration: BoxDecoration(
                  color: _colors[i],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
            );
          }),

          const Spacer(),

          _ToolBtn(icon: Icons.zoom_out_map, onTap: _resetZoom, subtitle: 'Reset'),

          // Нижние кнопки в ряд
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ToolBtn(icon: Icons.undo, onTap: _onUndo),
              _ToolBtn(icon: Icons.redo, onTap: _onRedo),
            ],
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }



  // ───────────────── Stage ─────────────────
  Widget _buildStage() {
    return Center(
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: ClipRect(
          child: InteractiveViewer(
            transformationController: _transformController,
            minScale: 0.5,
            maxScale: 5.0,
            boundaryMargin: const EdgeInsets.all(100),
            child: RepaintBoundary(
              key: _repaintKey,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: (d) {
                      final imagePoint = _screenToImageCoords(d.localPosition, constraints.biggest);

                      switch (_tool) {
                        case Tool.rect:
                          _rectStart = imagePoint;
                          _draftRect = Rect.fromPoints(imagePoint, imagePoint);
                          break;
                        case Tool.pen:
                          _draftPoints = [imagePoint];
                          _draftPath = Path()..moveTo(imagePoint.dx, imagePoint.dy);
                          break;
                        case Tool.eraser:
                          _eraseAt(imagePoint);
                          break;
                        case Tool.circle:  // Добавлено
                          _circleStart = imagePoint;
                          _draftRect = Rect.fromPoints(imagePoint, imagePoint);
                          break;
                        case Tool.arrow:   // Добавлено
                          _arrowStart = imagePoint;
                          break;
                        case Tool.select:
                        // Check for resize handle first
                          final handle = _findResizeHandle(imagePoint);
                          if (handle != null) {
                            _isResizing = true;
                            _resizeHandle = handle.type;
                            _pushUndo();
                          } else {
                            // Check for mark selection
                            final mark = _findMarkAt(imagePoint);
                            if (mark != null && mark == _selectedMark) {
                              // Start dragging selected mark
                              _isDragging = true;
                              _dragStart = imagePoint;
                              _pushUndo();
                            } else {
                              // Select new mark or deselect
                              _selectMark(mark);
                              if (mark != null) {
                                _isDragging = true;
                                _dragStart = imagePoint;
                                _pushUndo();
                              }
                            }
                          }
                          break;
                      }
                    },
                    onPanUpdate: (d) {
                      final imagePoint = _screenToImageCoords(d.localPosition, constraints.biggest);
                      setState(() {
                        switch (_tool) {
                          case Tool.rect:
                            if (_rectStart != null) {
                              _draftRect = Rect.fromPoints(_rectStart!, imagePoint);
                            }
                            break;
                          case Tool.circle:  // Добавлено
                            if (_circleStart != null) {
                              _draftRect = Rect.fromPoints(_circleStart!, imagePoint);
                            }
                            break;
                          case Tool.arrow:   // Добавлено
                            if (_arrowStart != null) {
                              // Сохраняем конечную точку для рисования стрелки
                              _draftArrowEnd = imagePoint;
                            }
                            break;
                          case Tool.pen:
                            _draftPoints.add(imagePoint);
                            _draftPath!.lineTo(imagePoint.dx, imagePoint.dy);
                            break;
                          case Tool.eraser:
                            _eraseAt(imagePoint);
                            break;
                          case Tool.select:
                            if (_isResizing && _selectedMark != null && _resizeHandle != null) {
                              _selectedMark!.resize(_resizeHandle!, imagePoint);
                            } else if (_isDragging && _selectedMark != null && _dragStart != null) {
                              final delta = imagePoint - _dragStart!;
                              _selectedMark!.move(delta);
                              _dragStart = imagePoint;
                            }
                            break;
                        }
                      });
                    },
                    onPanEnd: (_) {
                      if (_draftRect != null || _draftPath != null || _arrowStart != null) {
                        _pushUndo();
                        if (_draftRect != null) {
                          if (_tool == Tool.rect) {
                            _marks.add(_RectMark(_draftRect!, _currentColor, _strokeWidth));
                          } else if (_tool == Tool.circle) {
                            _marks.add(_CircleMark(_draftRect!, _currentColor, _strokeWidth));
                          }
                        }
                        if (_arrowStart != null && _draftArrowEnd != null) {
                          _marks.add(_ArrowMark(_arrowStart!, _draftArrowEnd!, _currentColor, _strokeWidth));
                        }
                        if (_draftPath != null && _draftPoints.length > 1) {
                          _marks.add(_PathMark(_draftPath!, _currentColor, _strokeWidth, List.of(_draftPoints)));
                        }
                      }

                      // Reset all interaction states
                      _draftRect = null;
                      _draftPath = null;
                      _draftPoints.clear();
                      _rectStart = null;
                      _circleStart = null;    // Добавлено
                      _arrowStart = null;     // Добавлено
                      _draftArrowEnd = null;  // Добавлено
                      _isDragging = false;
                      _isResizing = false;
                      _resizeHandle = null;
                      _dragStart = null;
                    },
                    child: CustomPaint(
                      size: constraints.biggest,
                      painter: _StagePainter(
                        _activeScreenshot,
                        _marks,
                        draftRect: _draftRect,
                        draftPath: _draftPath,
                        draftPaint: Paint()
                          ..color = _currentColor
                          ..strokeWidth = _strokeWidth
                          ..style = PaintingStyle.stroke
                          ..strokeCap = StrokeCap.round,
                        eraserMode: _tool == Tool.eraser ? _eraserMode : null,
                        currentTool: _tool,              // Добавлено
                        draftArrowStart: _arrowStart,    // Добавлено
                        draftArrowEnd: _draftArrowEnd,   // Добавлено
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
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
      itemCount: _otherScreenshots.length,
      itemBuilder: (c, i) => GestureDetector(
        onTap: () => _switchToScreenshot(i),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade400, width: 2),
          ),
          clipBehavior: Clip.hardEdge,
          child: Image(image: _otherScreenshots[i], fit: BoxFit.cover),
        ),
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
  final Tool? currentTool;           // Добавлено
  final Offset? draftArrowStart;     // Добавлено
  final Offset? draftArrowEnd;
  ui.Image? _bgImage;

  _StagePainter(this.bg, this.marks, {
    this.draftRect,
    this.draftPath,
    required this.draftPaint,
    this.eraserMode,
    this.currentTool,              // Добавлено
    this.draftArrowStart,          // Добавлено
    this.draftArrowEnd,
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

    // Draw all marks and their selection indicators
    for (final m in marks) {
      m.draw(canvas);
      m.drawSelection(canvas);
    }

    // Draw drafts
    if (draftRect != null) {
      if (currentTool == Tool.rect) {
        canvas.drawRect(draftRect!, draftPaint);
      } else if (currentTool == Tool.circle) {
        final center = draftRect!.center;
        final radius = (draftRect!.width < draftRect!.height ? draftRect!.width : draftRect!.height) / 2;
        canvas.drawCircle(center, radius, draftPaint);
      }
    }

    if (draftArrowStart != null && draftArrowEnd != null) {
      // Рисуем линию
      canvas.drawLine(draftArrowStart!, draftArrowEnd!, draftPaint);

      // Рисуем наконечник стрелки (аналогично _ArrowMark._drawArrowHead)
      final direction = draftArrowEnd! - draftArrowStart!;
      final length = direction.distance;

      if (length > 0) {
        final unitVector = direction / length;
        final arrowLength = 20.0;
        final arrowBack = draftArrowEnd! - unitVector * arrowLength;
        final perpendicular = Offset(-unitVector.dy, unitVector.dx);

        final arrowPoint1 = arrowBack + perpendicular * arrowLength * 0.3;
        final arrowPoint2 = arrowBack - perpendicular * arrowLength * 0.3;

        final arrowPath = Path()
          ..moveTo(draftArrowEnd!.dx, draftArrowEnd!.dy)
          ..lineTo(arrowPoint1.dx, arrowPoint1.dy)
          ..lineTo(arrowPoint2.dx, arrowPoint2.dy)
          ..close();

        final arrowPaint = Paint()
          ..color = draftPaint.color
          ..strokeWidth = draftPaint.strokeWidth
          ..style = PaintingStyle.fill;

        canvas.drawPath(arrowPath, arrowPaint);
      }
    }

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