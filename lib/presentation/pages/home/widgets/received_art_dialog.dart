import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/constants/color_constants.dart';
import '../../../../domain/entities/pixel_art.dart';

/// 受信したアートを表示するダイアログ
class ReceivedArtDialog extends StatelessWidget {
  const ReceivedArtDialog({
    super.key,
    required this.pixelArt,
    required this.onDismiss,
  });

  final PixelArt pixelArt;
  final VoidCallback onDismiss;

  /// Viewportを使わないピクセルグリッドを構築
  Widget _buildPixelGrid(double size) {
    final gridSize = pixelArt.gridSize;
    final cellSize = (size - 4) / gridSize; // size - border width

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(gridSize, (row) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(gridSize, (col) {
            final index = row * gridSize + col;
            final color = index < pixelArt.pixels.length
                ? Color(pixelArt.pixels[index] | 0xFF000000)
                : Colors.white;
            return Container(
              width: cellSize,
              height: cellSize,
              decoration: BoxDecoration(
                color: color,
                border: Border.all(
                  color: ColorConstants.gridLineColor,
                  width: 0.5,
                ),
              ),
            );
          }),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    // 画面サイズに応じてダイアログのサイズを調整
    // 画面幅の70%と画面高さの50%のうち小さい方を使用し、最大280に制限
    final artSize = min(min(screenSize.width * 0.7, screenSize.height * 0.4), 280.0);

    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // タイトル
              Text(
                'とどいたよ！',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              // ピクセルアート表示
              Container(
                width: artSize,
                height: artSize,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: ColorConstants.gridLineColor,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _buildPixelGrid(artSize),
                ),
              ),
              const SizedBox(height: 16),

              // タイトル
              if (pixelArt.title.isNotEmpty)
                Text(
                  pixelArt.title,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),

              const SizedBox(height: 8),

              // 作成者（ニックネーム）
              if (pixelArt.authorNickname != null)
                Text(
                  'by ${pixelArt.authorNickname}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),

              const SizedBox(height: 16),

              // 閉じるボタン
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onDismiss,
                  child: const Text('とじる'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
