import 'package:flutter/material.dart';

/// ドット絵表示ウィジェット
class PixelArtDisplay extends StatelessWidget {
  final List<int> pixels;
  final int gridSize;

  const PixelArtDisplay({
    super.key,
    required this.pixels,
    this.gridSize = 4,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PixelArtPainter(
        pixels: pixels,
        gridSize: gridSize,
      ),
    );
  }
}

class _PixelArtPainter extends CustomPainter {
  final List<int> pixels;
  final int gridSize;

  _PixelArtPainter({
    required this.pixels,
    required this.gridSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / gridSize;

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final index = i * gridSize + j;
        final colorValue = index < pixels.length ? pixels[index] : 0xFFFFFFFF;

        final paint = Paint()
          ..color = Color(colorValue)
          ..style = PaintingStyle.fill;

        final rect = Rect.fromLTWH(
          j * cellSize,
          i * cellSize,
          cellSize,
          cellSize,
        );

        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PixelArtPainter oldDelegate) {
    return oldDelegate.pixels != pixels || oldDelegate.gridSize != gridSize;
  }
}
