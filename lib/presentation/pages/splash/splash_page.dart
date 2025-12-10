import 'package:flutter/material.dart';

/// スプラッシュ画面（起動時のローディング画面）
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primaryContainer,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // アプリアイコン
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: CustomPaint(
                    size: const Size(80, 80),
                    painter: _PixelGridPainter(),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // アプリ名
              Text(
                '4×4 Pixel Diary',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 48),

              // ローディングインジケーター
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                '読み込み中...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 4×4ピクセルグリッド描画
class _PixelGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / 4;
    final paint = Paint()..style = PaintingStyle.fill;

    // サンプルピクセルパターン
    final colors = [
      [Colors.pink, Colors.pink.shade300, Colors.pink.shade300, Colors.pink],
      [
        Colors.pink.shade300,
        Colors.pink.shade100,
        Colors.pink.shade100,
        Colors.pink.shade300
      ],
      [
        Colors.pink.shade300,
        Colors.pink.shade100,
        Colors.pink.shade100,
        Colors.pink.shade300
      ],
      [Colors.pink, Colors.pink.shade300, Colors.pink.shade300, Colors.pink],
    ];

    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 4; col++) {
        paint.color = colors[row][col];
        canvas.drawRect(
          Rect.fromLTWH(
            col * cellSize,
            row * cellSize,
            cellSize,
            cellSize,
          ),
          paint,
        );
      }
    }

    // グリッド線
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1;

    for (var i = 1; i < 4; i++) {
      // 縦線
      canvas.drawLine(
        Offset(i * cellSize, 0),
        Offset(i * cellSize, size.height),
        gridPaint,
      );
      // 横線
      canvas.drawLine(
        Offset(0, i * cellSize),
        Offset(size.width, i * cellSize),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
