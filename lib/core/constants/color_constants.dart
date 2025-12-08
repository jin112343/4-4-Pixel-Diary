import 'package:flutter/material.dart';

/// カラー定数
class ColorConstants {
  ColorConstants._();

  /// プリセットカラーパレット
  static const List<Color> presetColors = [
    Colors.black,
    Colors.white,
    Color(0xFFFF0000), // 赤
    Color(0xFFFF7F00), // オレンジ
    Color(0xFFFFFF00), // 黄
    Color(0xFF00FF00), // 緑
    Color(0xFF0000FF), // 青
    Color(0xFF4B0082), // 藍
    Color(0xFF9400D3), // 紫
    Color(0xFFFF69B4), // ピンク
    Color(0xFF8B4513), // 茶
    Color(0xFF808080), // グレー
    Color(0xFF00FFFF), // シアン
    Color(0xFFFFD700), // ゴールド
    Color(0xFFFFC0CB), // 薄ピンク
    Color(0xFF98FB98), // 薄緑
  ];

  /// デフォルトキャンバス色（透明/白）
  static const Color defaultCanvasColor = Colors.white;

  /// グリッド線の色
  static const Color gridLineColor = Color(0xFFE0E0E0);
}
