import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// カラーピッカーダイアログ（タブ式）
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

  // RGB値
  late int _red;
  late int _green;
  late int _blue;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedColor = widget.initialColor;
    _red = _selectedColor.red;
    _green = _selectedColor.green;
    _blue = _selectedColor.blue;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateColorFromRGB() {
    setState(() {
      _selectedColor = Color.fromARGB(255, _red, _green, _blue);
    });
  }

  void _selectColor(Color color) {
    setState(() {
      _selectedColor = color;
      _red = color.red;
      _green = color.green;
      _blue = color.blue;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('いろをえらぶ'),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            // 選択中の色プレビュー
            Container(
              height: 50,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _selectedColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey),
              ),
              child: Center(
                child: Text(
                  '#${_selectedColor.value.toRadixString(16).substring(2).toUpperCase()}',
                  style: TextStyle(
                    color: _selectedColor.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // タブバー
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'RGB'),
                Tab(text: 'パレット'),
              ],
            ),

            // タブコンテンツ
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // RGBスライダー
                  _RGBSliderTab(
                    red: _red,
                    green: _green,
                    blue: _blue,
                    onRedChanged: (value) {
                      _red = value;
                      _updateColorFromRGB();
                    },
                    onGreenChanged: (value) {
                      _green = value;
                      _updateColorFromRGB();
                    },
                    onBlueChanged: (value) {
                      _blue = value;
                      _updateColorFromRGB();
                    },
                  ),

                  // パレットグリッド
                  _PaletteGridTab(
                    selectedColor: _selectedColor,
                    onColorSelected: _selectColor,
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

/// RGBスライダータブ
class _RGBSliderTab extends StatelessWidget {
  const _RGBSliderTab({
    required this.red,
    required this.green,
    required this.blue,
    required this.onRedChanged,
    required this.onGreenChanged,
    required this.onBlueChanged,
  });

  final int red;
  final int green;
  final int blue;
  final void Function(int) onRedChanged;
  final void Function(int) onGreenChanged;
  final void Function(int) onBlueChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          // Rスライダー
          _ColorSlider(
            label: 'R',
            value: red,
            color: Colors.red,
            onChanged: onRedChanged,
          ),
          const SizedBox(height: 16),

          // Gスライダー
          _ColorSlider(
            label: 'G',
            value: green,
            color: Colors.green,
            onChanged: onGreenChanged,
          ),
          const SizedBox(height: 16),

          // Bスライダー
          _ColorSlider(
            label: 'B',
            value: blue,
            color: Colors.blue,
            onChanged: onBlueChanged,
          ),
        ],
      ),
    );
  }
}

/// カラースライダー
class _ColorSlider extends StatelessWidget {
  const _ColorSlider({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final int value;
  final Color color;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              thumbColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.3),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 255,
              divisions: 255,
              onChanged: (v) => onChanged(v.toInt()),
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value.toString().padLeft(3, '0'),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }
}

/// パレットグリッドタブ
class _PaletteGridTab extends StatelessWidget {
  const _PaletteGridTab({
    required this.selectedColor,
    required this.onColorSelected,
  });

  final Color selectedColor;
  final void Function(Color) onColorSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: ColorConstants.paletteGridColors.length,
        itemBuilder: (context, index) {
          final color = ColorConstants.paletteGridColors[index];
          final isSelected = color == selectedColor;

          return GestureDetector(
            onTap: () => onColorSelected(color),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey.shade400,
                  width: isSelected ? 3 : 1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
