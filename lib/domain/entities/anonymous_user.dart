import 'package:freezed_annotation/freezed_annotation.dart';

part 'anonymous_user.freezed.dart';
part 'anonymous_user.g.dart';

/// 匿名ユーザーエンティティ
/// 個人情報は一切保存しない
@freezed
class AnonymousUser with _$AnonymousUser {
  const factory AnonymousUser({
    /// デバイス固有のUUID
    required String deviceId,

    /// ニックネーム（任意、最大5文字）
    String? nickname,

    /// プレミアムグリッド購入済みか
    @Default(false) bool hasPremiumGrid,

    /// 作成日時
    required DateTime createdAt,

    /// 最終アクティブ日時
    DateTime? lastActiveAt,

    /// 設定
    @Default(UserSettings()) UserSettings settings,
  }) = _AnonymousUser;

  factory AnonymousUser.fromJson(Map<String, dynamic> json) =>
      _$AnonymousUserFromJson(json);
}

/// ユーザー設定
@freezed
class UserSettings with _$UserSettings {
  const factory UserSettings({
    /// ダークモード
    @Default(false) bool isDarkMode,

    /// システムテーマに従う
    @Default(true) bool useSystemTheme,

    /// 通知有効
    @Default(true) bool notificationsEnabled,

    /// Bluetooth有効
    @Default(false) bool bluetoothEnabled,

    /// 自動交換モード
    @Default(false) bool autoExchangeMode,
  }) = _UserSettings;

  factory UserSettings.fromJson(Map<String, dynamic> json) =>
      _$UserSettingsFromJson(json);
}
