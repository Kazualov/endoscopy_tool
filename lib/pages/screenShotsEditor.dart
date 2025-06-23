import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

// ────────────────────────────────────────────────────────────────────────
//  HOW TO USE THIS WIDGET OFF‑LINE
// ────────────────────────────────────────────────────────────────────────
// 1.  Add your font once in **pubspec.yaml** (Nunito in this example):
//
//     flutter:
//       fonts:
//         - family: Nunito
//           fonts:
//             - asset: assets/fonts/Nunito-Medium.ttf
//               weight: 400
//
// 2.  Place the TTF file at `assets/fonts/Nunito-Medium.ttf` and run
//     `flutter pub get`.
//
// 3.  In your `main.dart` launch the editor however you like, e.g.:
//
//     void main() {
//       runApp(
//         MaterialApp(
//           debugShowCheckedModeBanner: false,
//           theme: ThemeData(
//             useMaterial3: true,
//             fontFamily: 'Nunito',
//             colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
//           ),
//           // IMPORTANT:  supply *real* images – NOT assets you don't have.
//           home: ScreenshotEditor(
//             screenshot: FileImage(File('/absolute/path/to/main.png')),
//             otherScreenshots: [
//               FileImage(File('/absolute/path/to/thumb1.png')),
//               FileImage(File('/absolute/path/to/thumb2.png')),
//             ],
//           ),
//         ),
//       );
//     }
//
// That’s it — no `assets/images/sample.png` are referenced anywhere below,
// so the engine won’t complain about missing assets.
// ────────────────────────────────────────────────────────────────────────

class ScreenshotEditor extends StatefulWidget {
  /// Screenshot that is currently opened for editing.
  final ImageProvider screenshot;

  /// Thumbnails of other screenshots in the series.
  final List<ImageProvider> otherScreenshots;

  const ScreenshotEditor({
    super.key,
    required this.screenshot,
    required this.otherScreenshots,
  });

  @override
  State<ScreenshotEditor> createState() => _ScreenshotEditorState();
}

class _ScreenshotEditorState extends State<ScreenshotEditor> {
  int selectedTool = 0; // 0‑rect, 1‑eraser, 2‑pen
  int selectedColorIndex = 0;

  // Future<void> saveExampleFile(file ) async {
  //   final dir = await getApplicationDocumentsDirectory();
  //   final file = File('${dir.path}/my_image.png');
  //
  //   // Например, скопировать существующий файл туда:
  //   await File('/Users/egornava/Pictures/screenshots/photo/Screenshot 2025-05-21 at 18.52.41.png').copy(file.path);
  //
  //   // Теперь можно использовать его без ошибок доступа:
  //   final image = FileImage(file);
  // }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceVariant,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLeftSidebar(theme),
            Expanded(child: _buildEditingStage()),
            _buildRightSidebar(theme),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Left toolbar (tools + palette + history)
  // ────────────────────────────────────────────────────────────
  Widget _buildLeftSidebar(ThemeData theme) {
    const toolIcons = [
      Icons.crop_square, // rectangle selection
      Icons.auto_fix_off, // eraser placeholder
      Icons.edit, // pen
    ];

    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(blurRadius: 8, offset: Offset(0, 2), color: Colors.black26),
        ],
      ),
      child: Column(
        children: [
          _ToolbarButton(
            icon: Icons.arrow_back,
            onTap: () => Navigator.maybePop(context),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < toolIcons.length; ++i)
            _ToolbarButton(
              icon: toolIcons[i],
              isActive: selectedTool == i,
              onTap: () => setState(() => selectedTool = i),
            ),
          const SizedBox(height: 24),
          _buildPalette(),
          const Spacer(),
          _ToolbarButton(icon: Icons.undo, onTap: _onUndo),
          _ToolbarButton(icon: Icons.redo, onTap: _onRedo),
        ],
      ),
    );
  }

  Widget _buildPalette() {
    const colors = [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(colors.length, (i) {
        return GestureDetector(
          onTap: () => setState(() => selectedColorIndex = i),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors[i],
              shape: BoxShape.circle,
              border: Border.all(
                color: i == selectedColorIndex ? Colors.white : Colors.transparent,
                width: 3,
              ),
            ),
          ),
        );
      }),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Central editing stage (placeholder)
  // ────────────────────────────────────────────────────────────
  Widget _buildEditingStage() {
    return Center(
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image(image: widget.screenshot, fit: BoxFit.contain),
              Positioned.fill(
                child: IgnorePointer(child: CustomPaint(painter: _DemoGridPainter())),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Right sidebar with thumbnails
  // ────────────────────────────────────────────────────────────
  Widget _buildRightSidebar(ThemeData theme) {
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(blurRadius: 8, offset: Offset(0, 2), color: Colors.black26),
        ],
      ),
      child: ListView.builder(
        itemCount: widget.otherScreenshots.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              // TODO: switch active screenshot
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade400, width: 2),
              ),
              clipBehavior: Clip.hardEdge,
              child: Image(
                image: widget.otherScreenshots[index],
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // History callbacks (stubbed)
  // ────────────────────────────────────────────────────────────
  void _onUndo() {}
  void _onRedo() {}
}

// ──────────────────────────────────────────────────────────────
// Helper widgets & demo painter
// ──────────────────────────────────────────────────────────────
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  const _ToolbarButton({
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 24, color: isActive ? Colors.white : theme.iconTheme.color),
      ),
    );
  }
}

class _DemoGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1
      ..color = Colors.grey.shade300;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
