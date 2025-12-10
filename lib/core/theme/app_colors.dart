import 'package:flutter/material.dart';

/// アプリケーションカラー
class AppColors {
  AppColors._();

  /// プライマリカラー
  static const Color primary = Color(0xFF6366F1);

  /// セカンダリカラー
  static const Color secondary = Color(0xFFF472B6);

  /// アクセントカラー
  static const Color accent = Color(0xFF34D399);

  /// 背景色（ライト）
  static const Color backgroundLight = Color(0xFFF8FAFC);

  /// 背景色（ダーク）
  static const Color backgroundDark = Color(0xFF0F172A);

  /// サーフェス色（ライト）
  static const Color surfaceLight = Colors.white;

  /// サーフェス色（ダーク）
  static const Color surfaceDark = Color(0xFF1E293B);

  /// エラー色
  static const Color error = Color(0xFFEF4444);

  /// 成功色
  static const Color success = Color(0xFF22C55E);

  /// 警告色
  static const Color warning = Color(0xFFF59E0B);

  /// テキスト色（ライト）
  static const Color textPrimaryLight = Color(0xFF1E293B);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textTertiaryLight = Color(0xFF94A3B8);

  /// テキスト色（ダーク）
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textTertiaryDark = Color(0xFF64748B);

  /// ボーダー色
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFF334155);

  /// 共通カラー（テーマ非依存またはゲッター経由）
  static Color get textSecondary => textSecondaryLight;
  static Color get textTertiary => textTertiaryLight;
  static Color get divider => borderLight;
}
