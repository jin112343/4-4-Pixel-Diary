import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../../../core/constants/color_constants.dart';
import '../home_view_model.dart';

/// カラーパレット
class ColorPalette extends ConsumerWidget {
  const ColorPalette({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedColor = ref.watch(
      homeViewModelProvider.select((state) => state.selectedColor),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 選択中の色表示 & カラーピッカーボタン
        Row(
          children: [
            const Text('いろをえらぶ'),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showColorPicker(context, ref, selectedColor),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selectedColor,
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _showColorPicker(context, ref, selectedColor),
              icon: const Icon(Icons.palette),
              label: const Text('もっと'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // プリセットカラー
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: ColorConstants.presetColors.length,
            itemBuilder: (context, index) {
              final color = ColorConstants.presetColors[index];
              final isSelected = color == selectedColor;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    ref.read(homeViewModelProvider.notifier).selectColor(color);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey,
                        width: isSelected ? 3 : 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// カラーピッカーダイアログを表示
  void _showColorPicker(
    BuildContext context,
    WidgetRef ref,
    Color currentColor,
  ) {
    var pickedColor = currentColor;

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('いろをえらぶ'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: currentColor,
              onColorChanged: (color) {
                pickedColor = color;
              },
              enableAlpha: false,
              hexInputBar: true,
              labelTypes: const [],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(homeViewModelProvider.notifier).selectColor(pickedColor);
                Navigator.of(context).pop();
              },
              child: const Text('えらぶ'),
            ),
          ],
        );
      },
    );
  }
}
