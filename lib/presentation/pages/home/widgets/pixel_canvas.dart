import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/color_constants.dart';
import '../home_view_model.dart';

/// ドット絵キャンバス
class PixelCanvas extends ConsumerWidget {
  const PixelCanvas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeViewModelProvider);
    final pixels = homeState.pixels;
    final gridSize = homeState.gridSize;

    if (pixels.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

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
              selectedColor: homeState.selectedColor,
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
        ref.read(homeViewModelProvider.notifier).setPixelColor(
              index,
              selectedColor,
            );
      },
      onLongPress: () {
        // 長押しで消す（白に戻す）
        ref.read(homeViewModelProvider.notifier).setPixelColor(
              index,
              ColorConstants.defaultCanvasColor,
            );
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
