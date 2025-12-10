import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// BLE通信で使用する定数
class BleConstants {
  BleConstants._();

  /// PixelDiaryサービスUUID
  /// カスタムサービスを識別するための一意のID
  static final Guid serviceUuid =
      Guid('4f4d4449-5843-4841-4e47-455f53455256');

  /// 書き込み用キャラクタリスティックUUID
  /// クライアント→サーバーへのデータ送信用
  static final Guid writeCharUuid =
      Guid('4f4d4449-5843-4841-4e47-455f575249');

  /// 読み取り用キャラクタリスティックUUID
  /// サーバー→クライアントへのデータ送信用（Notify）
  static final Guid readCharUuid =
      Guid('4f4d4449-5843-4841-4e47-455f52454144');

  /// アドバタイズ時のプレフィックス
  static const String advertisePrefix = 'PD_';

  /// MTUサイズ（安全な値: 185バイト）
  /// BLE標準の最小MTUは23バイト、最大は517バイト
  /// 185バイトは多くのデバイスでサポートされている安全な値
  static const int mtuSize = 185;

  /// 最小MTUサイズ（BLE標準）
  static const int minMtuSize = 23;

  /// 最大MTUサイズ（BLE仕様上の最大値）
  static const int maxMtuSize = 517;

  /// 接続タイムアウト（秒）
  static const int connectionTimeout = 10;

  /// スキャンタイムアウト（秒）
  static const int scanTimeout = 30;

  /// データ交換タイムアウト（秒）
  static const int exchangeTimeout = 15;

  /// 最大リトライ回数
  static const int maxRetries = 3;

  // ========== Pairing Constants ==========

  /// ペアリング用キャラクタリスティックUUID
  static final Guid pairingCharUuid =
      Guid('4f4d4449-5843-4841-4e47-455f50414952');

  /// ペアリングコードの有効期限（秒）
  static const int pairingCodeValidity = 60;

  /// ペアリングコードの桁数
  static const int pairingCodeLength = 6;

  /// ペアリング確認タイムアウト（秒）
  static const int pairingConfirmTimeout = 30;

  /// ペアリング認証用シークレット（アプリ固有）
  /// 環境変数から読み込み: --dart-define=BLE_PAIRING_SECRET=your_secret
  ///
  /// ⚠️ 警告: 本番環境では必ずBLE_PAIRING_SECRET環境変数を設定してください
  /// デフォルト値は開発時のみ使用され、セキュリティ上推奨されません
  static const String pairingSecret = String.fromEnvironment(
    'BLE_PAIRING_SECRET',
    defaultValue: 'DEVELOPMENT_ONLY_DO_NOT_USE_IN_PRODUCTION',
  );

  /// ペアリングシークレットが本番用かチェック
  static bool get isPairingSecretSecure =>
      pairingSecret != 'DEVELOPMENT_ONLY_DO_NOT_USE_IN_PRODUCTION' &&
      pairingSecret.isNotEmpty;

  /// ペアリング必須かどうか
  /// すれ違い通信では初めて会うユーザーが多いため、デフォルトはfalse推奨
  /// ユーザー設定で変更可能にすることを推奨
  static const bool requirePairing = false;
}
