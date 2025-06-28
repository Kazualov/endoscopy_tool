import 'dart:io';
import 'dart:ui' as ui;
import 'package:endoscopy_tool/pages/ScreenShotEditor/stage_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

import '../screenShotsEditor.dart';
import 'mark.dart' hide Tool, EraserMode, ResizeHandle;

class ScreenshotEditorState extends State<ScreenshotEditor> with TickerProviderStateMixin {
  late ImageProvider _activeScreenshot;
  late List<ImageProvider> _otherScreenshots;
  // Tools & palette
  Tool tool = Tool.rect;
  EraserMode _eraserMode = EraserMode.shape;
  int _colorIx = 0;
  double _strokeWidth = 3.0;
  final _colors = [Colors.red, Colors.green, Colors.blue];

  // Marks & history
  final List<Mark> Marks = [];
  final List<List<Mark>> _undoStack = [];
  final List<List<Mark>> _redoStack = [];

  // In‑progress drawing
  Rect? _draftRect;
  Path? _draftPath;
  List<Offset> _draftPoints = []; // For storing path points
  Offset? _rectStart;

  // Selection and dragging
  Mark? _selectedMark;
  bool _isDragging = false;
  bool _isResizing = false;
  HandleType? _resizeHandle;
  Offset? _dragStart;

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
    _undoStack.add(List.of(Marks));
    _redoStack.clear();
  }

  void _onUndo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(List.of(Marks));
    setState(() {
      Marks.clear();
      Marks.addAll(_undoStack.removeLast());
      _selectedMark = null;
    });
  }

  void _onRedo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(List.of(Marks));
    setState(() {
      Marks.clear();
      Marks.addAll(_redoStack.removeLast());
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
  Mark? _findMarkAt(Offset point) {
    // Search from top to bottom (reverse order)
    for (int i = Marks.length - 1; i >= 0; i--) {
      if (Marks[i].hit(point)) {
        return Marks[i];
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

  void _selectMark(Mark? mark) {
    setState(() {
      // Deselect all marks
      for (final m in Marks) {
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
    for (int i = Marks.length - 1; i >= 0; --i) {
      if (Marks[i].hit(p)) {
        _pushUndo();
        setState(() => Marks.removeAt(i));
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
      final List<Mark> newMarks = [];

      for (final mark in Marks) {
        final result = mark.erasePixel(p, eraserRadius);
        if (result != null) {
          newMarks.add(result);
          if (result != mark) hasChanges = true;
        } else {
          hasChanges = true;
        }
      }

      if (hasChanges) {
        Marks.clear();
        Marks.addAll(newMarks);
      }
    });
  }

  // Toggle eraser mode on double tap when eraser is selected
  void _toggleEraserMode() {
    if (tool == Tool.eraser) {
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
    const icons = [Icons.crop_square, Icons.edit, Icons.auto_fix_off, Icons.near_me];
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
              onDoubleTap: i == 2 ? _toggleEraserMode : null,
              child: ToolBtn(
                icon: icons[i],
                active: tool.index == i,
                onTap: () => setState(() => tool = Tool.values[i]),
                subtitle: i == 2 && tool == Tool.eraser
                    ? (_eraserMode == EraserMode.shape ? 'Shape' : 'Pixel')
                    : null,
              ),
            ),
          const SizedBox(height: 12),

          // Укороченный слайдер ширины
          SizedBox(
            // ограничение по высоте
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
          ),

          const SizedBox(height: 12),

          // Палитра — выбранный цвет больше
          ...List.generate(_colors.length, (i) {
            final isSelected = i == _colorIx;
            return GestureDetector(
              onTap: () => setState(() => _colorIx = i),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                width: isSelected ? 32 : 20,
                height: isSelected ? 32 :20,
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

          ToolBtn(
            icon: Icons.zoom_out_map,
            onTap: _resetZoom,
            subtitle: 'Reset',
          ),
          const SizedBox(height: 8),

          // Undo и Redo снова друг под другом
          ToolBtn(icon: Icons.undo, onTap: _onUndo),
          ToolBtn(icon: Icons.redo, onTap: _onRedo),
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

                      switch (tool) {
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
                        switch (tool) {
                          case Tool.rect:
                            if (_rectStart != null) {
                              _draftRect = Rect.fromPoints(_rectStart!, imagePoint);
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
                      if (_draftRect != null || _draftPath != null) {
                        _pushUndo();
                        if (_draftRect != null) {
                          Marks.add(RectMark(_draftRect!, _currentColor, _strokeWidth));
                        }
                        if (_draftPath != null && _draftPoints.length > 1) {
                          Marks.add(PathMark(_draftPath!, _currentColor, _strokeWidth, List.of(_draftPoints)));
                        }
                      }

                      // Reset all interaction states
                      _draftRect = null;
                      _draftPath = null;
                      _draftPoints.clear();
                      _rectStart = null;
                      _isDragging = false;
                      _isResizing = false;
                      _resizeHandle = null;
                      _dragStart = null;
                    },
                    child: CustomPaint(
                      size: constraints.biggest,
                      painter: StagePainter(
                        _activeScreenshot,
                        Marks,
                        draftRect: _draftRect,
                        draftPath: _draftPath,
                        draftPaint: Paint()
                          ..color = _currentColor
                          ..strokeWidth = _strokeWidth
                          ..style = PaintingStyle.stroke
                          ..strokeCap = StrokeCap.round,
                        eraserMode: tool == Tool.eraser ? _eraserMode : null,
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
