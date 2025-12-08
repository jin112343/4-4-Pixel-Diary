import 'package:flutter/material.dart';

/// カラー定数
class ColorConstants {
  ColorConstants._();

  /// クイックアクセス用プリセットカラー（横スクロール表示用）
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

  /// パレット式グリッド用カラー（6x8 = 48色）
  static const List<Color> paletteGridColors = [
    // 行1: グレースケール
    Color(0xFF000000), Color(0xFF333333), Color(0xFF666666), Color(0xFF999999),
    Color(0xFFCCCCCC), Color(0xFFFFFFFF),
    // 行2: 赤系
    Color(0xFF330000), Color(0xFF660000), Color(0xFF990000), Color(0xFFCC0000),
    Color(0xFFFF0000), Color(0xFFFF6666),
    // 行3: オレンジ・黄系
    Color(0xFF663300), Color(0xFFCC6600), Color(0xFFFF9900), Color(0xFFFFCC00),
    Color(0xFFFFFF00), Color(0xFFFFFF99),
    // 行4: 緑系
    Color(0xFF003300), Color(0xFF006600), Color(0xFF009900), Color(0xFF00CC00),
    Color(0xFF00FF00), Color(0xFF99FF99),
    // 行5: シアン・青系
    Color(0xFF003333), Color(0xFF006666), Color(0xFF009999), Color(0xFF00CCCC),
    Color(0xFF00FFFF), Color(0xFF0066FF),
    // 行6: 青系
    Color(0xFF000033), Color(0xFF000066), Color(0xFF000099), Color(0xFF0000CC),
    Color(0xFF0000FF), Color(0xFF6666FF),
    // 行7: 紫系
    Color(0xFF330033), Color(0xFF660066), Color(0xFF990099), Color(0xFFCC00CC),
    Color(0xFFFF00FF), Color(0xFFFF99FF),
    // 行8: ピンク・茶系
    Color(0xFF663333), Color(0xFF996666), Color(0xFFCC9999), Color(0xFFFFCCCC),
    Color(0xFF8B4513), Color(0xFFD2691E),
  ];

  /// デフォルトキャンバス色（透明/白）
  static const Color defaultCanvasColor = Colors.white;

  /// グリッド線の色
  static const Color gridLineColor = Color(0xFFE0E0E0);
}
