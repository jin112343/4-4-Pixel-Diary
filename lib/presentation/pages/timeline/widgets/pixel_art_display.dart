import 'package:flutter/material.dart';

/// ドット絵表示ウィジェット
class PixelArtDisplay extends StatelessWidget {
  const PixelArtDisplay({
    super.key,
    required this.pixels,
    this.gridSize = 4,
  });

  final List<int> pixels;
  final int gridSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: _PixelArtPainter(
          pixels: pixels,
          gridSize: gridSize,
        ),
      ),
    );
  }
}

class _PixelArtPainter extends CustomPainter {
  _PixelArtPainter({
    required this.pixels,
    required this.gridSize,
  });

  final List<int> pixels;
  final int gridSize;

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / gridSize;

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final index = i * gridSize + j;
        final colorValue = index < pixels.length ? pixels[index] : 0xFFFFFFFF;

        // 24ビット値（0xRRGGBB）の場合はアルファ値を追加
        final actualColor =
            colorValue <= 0xFFFFFF ? colorValue | 0xFF000000 : colorValue;

        final paint = Paint()
          ..color = Color(actualColor)
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
