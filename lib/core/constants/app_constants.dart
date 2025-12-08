/// アプリケーション定数
class AppConstants {
  AppConstants._();

  /// アプリ名
  static const String appName = '4×4 Pixel Diary';

  /// バージョン
  static const String version = '1.0.0';

  /// グリッドサイズ
  static const int defaultGridSize = 4;
  static const int premiumGridSize = 5;

  /// タイトル最大文字数
  static const int maxTitleLength = 5;

  /// コメント最大文字数
  static const int maxCommentLength = 50;

  /// ニックネーム最大文字数
  static const int maxNicknameLength = 5;

  /// ピクセル数（4×4）
  static const int defaultPixelCount = 16;

  /// ピクセル数（5×5）
  static const int premiumPixelCount = 25;

  /// アルバム1ページあたりの件数
  static const int albumPageSize = 20;

  /// タイムライン1ページあたりの件数
  static const int timelinePageSize = 20;

  /// Bluetooth交換のリトライ回数
  static const int bleRetryCount = 3;

  /// API タイムアウト（秒）
  static const int apiTimeoutSeconds = 10;
}
