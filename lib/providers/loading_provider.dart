import 'package:flutter_riverpod/flutter_riverpod.dart';

/// グローバルローディング状態プロバイダー
final loadingProvider = StateNotifierProvider<LoadingNotifier, bool>(
  (ref) => LoadingNotifier(),
);

/// ローディング状態Notifier
class LoadingNotifier extends StateNotifier<bool> {
  LoadingNotifier() : super(false);

  /// ローディング開始
  void show() {
    state = true;
  }

  /// ローディング終了
  void hide() {
    state = false;
  }

  /// ローディング状態をトグル
  void toggle() {
    state = !state;
  }
}
