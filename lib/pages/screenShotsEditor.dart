import 'dart:io';
import 'dart:ui';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

// ──────────────────────────────────────────────────────────────────────
//  Screenshot Editor – v2
//  • Rectangle, Pen, Eraser
//  • Color palette
//  • Undo / Redo
//  • Save annotated image  → call  `await editorKey.currentState!.save()`
// ──────────────────────────────────────────────────────────────────────
enum Tool { rect, pen, eraser }

abstract class _Mark {
  final Paint paint;
  _Mark(Color color) : paint = Paint()
    ..color = color
    ..strokeWidth = 3
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  void draw(Canvas canvas);
  bool hit(Offset point); // for eraser
}

class _RectMark extends _Mark {
  Rect rect;
  _RectMark(this.rect, Color c) : super(c);
  @override
  void draw(Canvas canvas) => canvas.drawRect(rect, paint);
  @override
  bool hit(Offset p) => rect.inflate(6).contains(p);
}

class _PathMark extends _Mark {
  final Path path;
  _PathMark(this.path, Color c) : super(c);
  @override
  void draw(Canvas canvas) => canvas.drawPath(path, paint);
  @override
  bool hit(Offset p) {
    final pathMetrics = path.computeMetrics();
    for (final m in pathMetrics) {
      final pos = m.getTangentForOffset(m.length * 0.5)?.position ?? Offset.zero;
      if ((pos - p).distance < 8) return true;
    }
    return false;
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
  int _colorIx = 0;
  final _colors = [Colors.red, Colors.green, Colors.blue, Colors.orange, Colors.purple];

  // Marks & history
  final List<_Mark> _marks = [];
  final List<List<_Mark>> _undoStack = [];
  final List<List<_Mark>> _redoStack = [];

  // In‑progress drawing
  Rect? _draftRect;
  Path? _draftPath;

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

  // Erase first mark under point
  void _eraseAt(Offset p) {
    for (int i = _marks.length - 1; i >= 0; --i) {
      if (_marks[i].hit(p)) {
        _pushUndo();
        setState(() => _marks.removeAt(i));
        break;
      }
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
            _ToolBtn(
              icon: icons[i],
              active: _tool.index == i,
              onTap: () => setState(() => _tool = Tool.values[i]),
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
                  _draftRect = Rect.fromPoints(local, local);
                  break;
                case Tool.pen:
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
                    _draftRect = Rect.fromPoints(_draftRect!.topLeft, local);
                    break;
                  case Tool.pen:
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
                if (_draftRect != null) _marks.add(_RectMark(_draftRect!, _currentColor));
                if (_draftPath != null) _marks.add(_PathMark(_draftPath!, _currentColor));
              }
              _draftRect = null;
              _draftPath = null;
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
                  ..style = PaintingStyle.stroke,
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
  ui.Image? _bgImage;

  _StagePainter(this.bg, this.marks, {this.draftRect, this.draftPath, required this.draftPaint});

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
  const _ToolBtn({required this.icon, required this.onTap, this.active = false});
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
      child: Icon(icon, size: 24, color: active ? Colors.white : Theme.of(context).iconTheme.color),
    ),
  );
}
