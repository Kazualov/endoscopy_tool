import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../ScreenShotEditor/mark.dart';
import 'package:flutter/material.dart';

// ───────────────── Painter ─────────────────
class StagePainter extends CustomPainter {
  final ImageProvider bg;
  final List<Mark> marks;
  final Rect? draftRect;
  final Path? draftPath;
  final Paint draftPaint;
  final EraserMode? eraserMode;
  ui.Image? _bgImage;

  StagePainter(this.bg, this.marks, {
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

    // Draw all marks and their selection indicators
    for (final m in marks) {
      m.draw(canvas);
      m.drawSelection(canvas);
    }

    // Draw drafts
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
  bool shouldRepaint(covariant StagePainter old) => true;
}




// ───────────────── Helper ─────────────────
class ToolBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final String? subtitle;

  const ToolBtn({
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