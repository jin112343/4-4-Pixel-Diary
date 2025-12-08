import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/color_constants.dart';

/// 現在選択中の色
final selectedColorProvider = StateProvider<Color>((ref) => Colors.black);

/// キャンバスのピクセルデータ
final pixelsProvider = StateProvider<List<Color>>((ref) {
  return List.filled(
    AppConstants.defaultPixelCount,
    ColorConstants.defaultCanvasColor,
  );
});

/// ドット絵キャンバス
class PixelCanvas extends ConsumerWidget {
  const PixelCanvas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pixels = ref.watch(pixelsProvider);
    final selectedColor = ref.watch(selectedColorProvider);
    const gridSize = AppConstants.defaultGridSize;

    return AspectRatio(
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
            crossAxisCount: gridSize,
          ),
          itemCount: pixels.length,
          itemBuilder: (context, index) {
            return _PixelCell(
              index: index,
              color: pixels[index],
              selectedColor: selectedColor,
            );
          },
        ),
      ),
    );
  }
}

/// 1つのピクセルセル
class _PixelCell extends ConsumerWidget {
  const _PixelCell({
    required this.index,
    required this.color,
    required this.selectedColor,
  });

  final int index;
  final Color color;
  final Color selectedColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        // 選択中の色で塗る
        final pixels = ref.read(pixelsProvider.notifier);
        final currentPixels = List<Color>.from(ref.read(pixelsProvider));
        currentPixels[index] = selectedColor;
        pixels.state = currentPixels;
      },
      onLongPress: () {
        // 長押しで消す（白に戻す）
        final pixels = ref.read(pixelsProvider.notifier);
        final currentPixels = List<Color>.from(ref.read(pixelsProvider));
        currentPixels[index] = ColorConstants.defaultCanvasColor;
        pixels.state = currentPixels;
      },
      child: Container(
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: ColorConstants.gridLineColor,
            width: 0.5,
          ),
        ),
      ),
    );
  }
}
