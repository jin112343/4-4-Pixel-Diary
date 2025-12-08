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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('とどいたよ！'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ピクセルアート表示
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: ColorConstants.gridLineColor,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: pixelArt.gridSize,
                ),
                itemCount: pixelArt.pixels.length,
                itemBuilder: (context, index) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Color(pixelArt.pixels[index] | 0xFF000000),
                      border: Border.all(
                        color: ColorConstants.gridLineColor,
                        width: 0.5,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // タイトル
          if (pixelArt.title.isNotEmpty)
            Text(
              pixelArt.title,
              style: Theme.of(context).textTheme.titleMedium,
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
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: onDismiss,
          child: const Text('とじる'),
        ),
      ],
    );
  }
}
