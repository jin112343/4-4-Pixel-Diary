/// Exception基底クラス
abstract class AppException implements Exception {
  const AppException(this.message, [this.code]);

  final String message;
  final String? code;

  @override
  String toString() => 'AppException: $message (code: $code)';
}

/// サーバー例外
class ServerException extends AppException {
  const ServerException(super.message, [super.code]);
}

/// ネットワーク例外
class NetworkException extends AppException {
  const NetworkException([
    super.message = 'ネットワークに接続できません',
    super.code,
  ]);
}

/// キャッシュ例外
class CacheException extends AppException {
  const CacheException([
    super.message = 'データの保存に失敗しました',
    super.code,
  ]);
}

/// バリデーション例外
class ValidationException extends AppException {
  const ValidationException(super.message, [super.code]);
}

/// 認証例外
class AuthException extends AppException {
  const AuthException([
    super.message = '認証に失敗しました',
    super.code,
  ]);
}

/// Bluetooth例外
class BluetoothException extends AppException {
  const BluetoothException([
    super.message = 'Bluetooth通信に失敗しました',
    super.code,
  ]);
}
