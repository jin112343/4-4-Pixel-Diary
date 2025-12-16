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
              onTap: () => _showColorPickerDialog(context, ref, selectedColor),
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
              onPressed: () => _showColorPickerDialog(context, ref, selectedColor),
              icon: const Icon(Icons.palette),
              label: const Text('もっと'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // プリセットカラー（クイックアクセス）
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
                    // キーボードを閉じてから色を選択
                    FocusScope.of(context).unfocus();
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
  void _showColorPickerDialog(
    BuildContext context,
    WidgetRef ref,
    Color currentColor,
  ) {
    // キーボードを閉じてからダイアログを表示
    FocusScope.of(context).unfocus();
    showDialog<void>(
      context: context,
      builder: (context) => _ColorPickerDialog(
        initialColor: currentColor,
        onColorSelected: (color) {
          ref.read(homeViewModelProvider.notifier).selectColor(color);
        },
      ),
    );
  }
}

/// カラーピッカーダイアログ（タブ式・flutter_colorpicker活用）
class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({
    required this.initialColor,
    required this.onColorSelected,
  });

  final Color initialColor;
  final void Function(Color) onColorSelected;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _selectedColor = widget.initialColor;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onColorChanged(Color color) {
    setState(() {
      _selectedColor = color;
    });
  }

  String _colorToHex(Color color) {
    final r = ((color.r * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0');
    final g = ((color.g * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0');
    final b = ((color.b * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0');
    return '#${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('いろをえらぶ'),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: 450,
        child: Column(
          children: [
            // 選択中の色プレビュー
            Container(
              height: 40,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: _selectedColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey),
              ),
              child: Center(
                child: Text(
                  _colorToHex(_selectedColor),
                  style: TextStyle(
                    color: _selectedColor.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // タブバー
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(icon: Icon(Icons.circle_outlined, size: 18), text: 'ホイール'),
                Tab(icon: Icon(Icons.tune, size: 18), text: 'RGB'),
                Tab(icon: Icon(Icons.grid_view, size: 18), text: 'パレット'),
                Tab(icon: Icon(Icons.color_lens, size: 18), text: 'マテリアル'),
              ],
            ),

            // タブコンテンツ
            // スワイプでのタブ切り替えを無効化（スライダー操作と干渉するため）
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // カラーホイール（HUEリングピッカー）
                  _ColorWheelTab(
                    color: _selectedColor,
                    onColorChanged: _onColorChanged,
                  ),

                  // RGBスライダー
                  _RGBSliderTab(
                    color: _selectedColor,
                    onColorChanged: _onColorChanged,
                  ),

                  // パレットグリッド
                  _PaletteGridTab(
                    selectedColor: _selectedColor,
                    onColorSelected: _onColorChanged,
                  ),

                  // マテリアルカラー
                  _MaterialColorTab(
                    selectedColor: _selectedColor,
                    onColorSelected: _onColorChanged,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onColorSelected(_selectedColor);
            Navigator.of(context).pop();
          },
          child: const Text('えらぶ'),
        ),
      ],
    );
  }
}

/// カラーホイールタブ（HUEリングピッカー）
class _ColorWheelTab extends StatelessWidget {
  const _ColorWheelTab({
    required this.color,
    required this.onColorChanged,
  });

  final Color color;
  final void Function(Color) onColorChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: HueRingPicker(
        pickerColor: color,
        onColorChanged: onColorChanged,
        enableAlpha: false,
        displayThumbColor: true,
      ),
    );
  }
}

/// RGBスライダータブ（flutter_colorpicker の SlidePicker）
class _RGBSliderTab extends StatelessWidget {
  const _RGBSliderTab({
    required this.color,
    required this.onColorChanged,
  });

  final Color color;
  final void Function(Color) onColorChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: SlidePicker(
        pickerColor: color,
        onColorChanged: onColorChanged,
        enableAlpha: false,
        showParams: true,
        showIndicator: true,
        indicatorBorderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

/// パレットグリッドタブ（BlockPicker）
class _PaletteGridTab extends StatelessWidget {
  const _PaletteGridTab({
    required this.selectedColor,
    required this.onColorSelected,
  });

  final Color selectedColor;
  final void Function(Color) onColorSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: BlockPicker(
        pickerColor: selectedColor,
        onColorChanged: onColorSelected,
        availableColors: ColorConstants.paletteGridColors,
        layoutBuilder: (context, colors, child) {
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 6,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            children: colors.map((color) => child(color)).toList(),
          );
        },
        itemBuilder: (color, isCurrentColor, changeColor) {
          return GestureDetector(
            onTap: changeColor,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isCurrentColor ? Colors.blue : Colors.grey.shade400,
                  width: isCurrentColor ? 3 : 1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// マテリアルカラータブ
class _MaterialColorTab extends StatelessWidget {
  const _MaterialColorTab({
    required this.selectedColor,
    required this.onColorSelected,
  });

  final Color selectedColor;
  final void Function(Color) onColorSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: MaterialPicker(
        pickerColor: selectedColor,
        onColorChanged: onColorSelected,
        enableLabel: true,
      ),
    );
  }
}
