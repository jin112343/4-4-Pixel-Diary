import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/utils/content_filter.dart';
import '../../../core/utils/logger.dart';
import '../../../domain/entities/anonymous_user.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/moderation_provider.dart';
import '../../../services/auth/anonymous_auth_service.dart';
import '../../../services/moderation/moderation_service.dart';

part 'settings_view_model.freezed.dart';

/// 設定画面の状態
@freezed
class SettingsState with _$SettingsState {
  const factory SettingsState({
    /// 現在のユーザー
    AnonymousUser? user,

    /// ローディング中かどうか
    @Default(false) bool isLoading,

    /// エラーメッセージ
    String? errorMessage,

    /// 成功メッセージ
    String? successMessage,
  }) = _SettingsState;
}

/// 設定画面のViewModel
class SettingsViewModel extends StateNotifier<SettingsState> {
  SettingsViewModel(this._authService, this._moderationService)
      : super(const SettingsState()) {
    _loadUser();
  }

  final AnonymousAuthService _authService;
  final ModerationService _moderationService;

  /// ユーザー情報を読み込む
  Future<void> _loadUser() async {
    state = state.copyWith(isLoading: true);
    try {
      final user = await _authService.initialize();
      state = state.copyWith(
        isLoading: false,
        user: user,
      );
    } catch (e, stackTrace) {
      logger.e('Failed to load user', error: e, stackTrace: stackTrace);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'ユーザー情報の読み込みに失敗しました',
      );
    }
  }

  /// ニックネームを更新
  Future<void> updateNickname(String? nickname) async {
    // 空の場合はそのまま更新（ニックネーム削除）
    if (nickname == null || nickname.isEmpty) {
      await _updateNicknameInternal(null);
      return;
    }

    // 文字数チェック
    if (nickname.length > 5) {
      state = state.copyWith(errorMessage: 'ニックネームは5文字以内で入力してください');
      return;
    }

    // ステップ1: ローカルフィルタ（事前チェック）
    final localCheck = ContentFilter.check(nickname);
    if (!localCheck.isClean && localCheck.maxSeverity >= 4) {
      state = state.copyWith(
        errorMessage: localCheck.message.isNotEmpty
            ? localCheck.message
            : '不適切な表現が含まれています',
      );
      logger.w('Nickname blocked (Local): 事前チェック検出 - $nickname');
      return;
    }

    // ステップ2: AIモデレーション（Perspective API）
    try {
      final moderationResult = await _moderationService.moderate(nickname);
      if (!moderationResult.isAllowed) {
        state = state.copyWith(errorMessage: moderationResult.userMessage);
        logger.w(
          'Nickname blocked (AI): ${moderationResult.blockReason} - $nickname',
        );
        return;
      }
    } catch (e) {
      // AIモデレーションが失敗してもローカルチェックが通っていれば続行
      logger.w('AIモデレーション失敗、ローカルチェックのみで続行: $e');
    }

    await _updateNicknameInternal(nickname);
  }

  /// ニックネーム更新の内部処理
  Future<void> _updateNicknameInternal(String? nickname) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final updatedUser = await _authService.updateNickname(nickname);
      state = state.copyWith(
        isLoading: false,
        user: updatedUser,
        successMessage: 'ニックネームを更新しました',
      );
    } catch (e, stackTrace) {
      logger.e('Failed to update nickname', error: e, stackTrace: stackTrace);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'ニックネームの更新に失敗しました',
      );
    }
  }

  /// 設定を更新
  Future<void> updateSettings(UserSettings settings) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final updatedUser = await _authService.updateSettings(settings);
      state = state.copyWith(
        isLoading: false,
        user: updatedUser,
      );
    } catch (e, stackTrace) {
      logger.e('Failed to update settings', error: e, stackTrace: stackTrace);
      state = state.copyWith(
        isLoading: false,
        errorMessage: '設定の更新に失敗しました',
      );
    }
  }

  /// 通知設定を切り替え
  Future<void> toggleNotifications(bool enabled) async {
    final currentSettings = state.user?.settings ?? const UserSettings();
    await updateSettings(currentSettings.copyWith(notificationsEnabled: enabled));
  }

  /// Bluetooth設定を切り替え
  Future<void> toggleBluetooth(bool enabled) async {
    final currentSettings = state.user?.settings ?? const UserSettings();
    await updateSettings(currentSettings.copyWith(bluetoothEnabled: enabled));
  }

  /// テーマモードを更新
  Future<void> updateThemeMode(ThemeMode mode) async {
    final currentSettings = state.user?.settings ?? const UserSettings();
    final newSettings = switch (mode) {
      ThemeMode.system => currentSettings.copyWith(
          useSystemTheme: true,
        ),
      ThemeMode.light => currentSettings.copyWith(
          useSystemTheme: false,
          isDarkMode: false,
        ),
      ThemeMode.dark => currentSettings.copyWith(
          useSystemTheme: false,
          isDarkMode: true,
        ),
    };
    await updateSettings(newSettings);
  }

  /// ThemeModeを取得
  ThemeMode getThemeMode() {
    final settings = state.user?.settings ?? const UserSettings();
    if (settings.useSystemTheme) {
      return ThemeMode.system;
    }
    return settings.isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  /// エラーをクリア
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// 成功メッセージをクリア
  void clearSuccess() {
    state = state.copyWith(successMessage: null);
  }

  /// すべてのデータを削除
  Future<void> deleteAllData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _authService.deleteAllData();
      state = state.copyWith(
        isLoading: false,
        user: null,
        successMessage: 'すべてのデータを削除しました',
      );
    } catch (e, stackTrace) {
      logger.e('Failed to delete all data', error: e, stackTrace: stackTrace);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'データの削除に失敗しました',
      );
    }
  }
}

/// 設定ViewModelプロバイダー
final settingsViewModelProvider =
    StateNotifierProvider<SettingsViewModel, SettingsState>((ref) {
  final authService = ref.watch(authServiceProvider);
  final moderationService = ref.watch(moderationServiceProvider);
  return SettingsViewModel(authService, moderationService);
});
