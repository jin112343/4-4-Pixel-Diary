import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/logger.dart';
import '../data/datasources/local/local_storage.dart';
import 'app_providers.dart';

/// テーマモードプロバイダー
/// ローカルストレージからテーマ設定を読み込み、永続化する
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) {
    final localStorage = ref.watch(localStorageProvider);
    return ThemeModeNotifier(localStorage);
  },
);

/// テーマモード管理クラス
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._localStorage) : super(ThemeMode.system) {
    _loadTheme();
  }

  final LocalStorage _localStorage;

  /// ローカルストレージからテーマを読み込む
  Future<void> _loadTheme() async {
    try {
      final user = _localStorage.getUser();
      if (user != null) {
        if (user.settings.useSystemTheme) {
          state = ThemeMode.system;
        } else {
          state = user.settings.isDarkMode ? ThemeMode.dark : ThemeMode.light;
        }
        logger.i('Theme loaded: $state');
      }
    } catch (e, stackTrace) {
      logger.e('Failed to load theme', error: e, stackTrace: stackTrace);
    }
  }

  /// テーマモードを設定
  void setThemeMode(ThemeMode mode) {
    state = mode;
    logger.i('Theme changed: $mode');
  }
}
