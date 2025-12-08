/// Failure基底クラス
abstract class Failure {
  const Failure(this.message, [this.code]);

  final String message;
  final String? code;

  @override
  String toString() => 'Failure: $message (code: $code)';
}

/// サーバーエラー
class ServerFailure extends Failure {
  const ServerFailure(super.message, [super.code]);
}

/// ネットワークエラー
class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'ネットワークに接続できません',
    super.code,
  ]);
}

/// キャッシュエラー
class CacheFailure extends Failure {
  const CacheFailure([
    super.message = 'データの保存に失敗しました',
    super.code,
  ]);
}

/// バリデーションエラー
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, [super.code]);
}

/// 認証エラー
class AuthFailure extends Failure {
  const AuthFailure([
    super.message = '認証に失敗しました',
    super.code,
  ]);
}

/// Bluetoothエラー
class BluetoothFailure extends Failure {
  const BluetoothFailure([
    super.message = 'Bluetooth通信に失敗しました',
    super.code,
  ]);
}

/// 課金エラー
class PurchaseFailure extends Failure {
  const PurchaseFailure([
    super.message = '購入処理に失敗しました',
    super.code,
  ]);
}

/// 不明なエラー
class UnknownFailure extends Failure {
  const UnknownFailure([
    super.message = '予期しないエラーが発生しました',
    super.code,
  ]);
}
