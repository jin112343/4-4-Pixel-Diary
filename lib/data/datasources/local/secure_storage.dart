import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/utils/logger.dart';

/// セキュアストレージサービス
/// 機密情報（デバイスID、トークンなど）を安全に保存
///
/// セキュリティ設定:
/// - Android: EncryptedSharedPreferences使用（AES-256-GCM暗号化）
/// - iOS: Keychain使用（より厳格なアクセス制御）
///   - first_unlock: デバイス初回ロック解除後にアクセス可能
///   - passcode_set_this_device_only: パスコード設定時のみアクセス可能（推奨）
class SecureStorage {
  SecureStorage()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(
            // Android 6.0以上でEncryptedSharedPreferencesを使用
            encryptedSharedPreferences: true,
            // キーストア設定（セキュリティ強化）
            keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
            storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
          ),
          iOptions: IOSOptions(
            // より厳格なアクセス制御
            // passcode_set_this_device_only: パスコード設定時のみアクセス可能
            // バックアップには含まれない（デバイス固有）
            accessibility: KeychainAccessibility.passcode,
            // iCloud同期を無効化（デバイス固有データ）
            synchronizable: false,
          ),
        );

  static const String _deviceIdKey = 'device_id';
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _signingKeyKey = 'api_signing_key';

  final FlutterSecureStorage _storage;

  // ========== Device ID ==========

  /// デバイスIDを保存
  Future<bool> saveDeviceId(String deviceId) async {
    try {
      await _storage.write(key: _deviceIdKey, value: deviceId);
      logger.d('Device ID saved');
      return true;
    } catch (e, stackTrace) {
      logger.e('Failed to save device ID', error: e, stackTrace: stackTrace);
      // エラーでもアプリは続行可能（次回起動時に再生成される）
      return false;
    }
  }

  /// デバイスIDを取得
  Future<String?> getDeviceId() async {
    try {
      return await _storage.read(key: _deviceIdKey);
    } catch (e, stackTrace) {
      logger.e('Failed to get device ID', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// デバイスIDを削除
  Future<void> deleteDeviceId() async {
    try {
      await _storage.delete(key: _deviceIdKey);
    } catch (e, stackTrace) {
      logger.e('Failed to delete device ID', error: e, stackTrace: stackTrace);
    }
  }

  // ========== Access Token ==========

  /// アクセストークンを保存
  Future<void> saveAccessToken(String token) async {
    try {
      await _storage.write(key: _accessTokenKey, value: token);
    } catch (e, stackTrace) {
      logger.e('Failed to save access token', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// アクセストークンを取得
  Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: _accessTokenKey);
    } catch (e, stackTrace) {
      logger.e('Failed to get access token', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// アクセストークンを削除
  Future<void> deleteAccessToken() async {
    try {
      await _storage.delete(key: _accessTokenKey);
    } catch (e, stackTrace) {
      logger.e('Failed to delete access token', error: e, stackTrace: stackTrace);
    }
  }

  // ========== Refresh Token ==========

  /// リフレッシュトークンを保存
  Future<void> saveRefreshToken(String token) async {
    try {
      await _storage.write(key: _refreshTokenKey, value: token);
    } catch (e, stackTrace) {
      logger.e('Failed to save refresh token', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// リフレッシュトークンを取得
  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _refreshTokenKey);
    } catch (e, stackTrace) {
      logger.e('Failed to get refresh token', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// リフレッシュトークンを削除
  Future<void> deleteRefreshToken() async {
    try {
      await _storage.delete(key: _refreshTokenKey);
    } catch (e, stackTrace) {
      logger.e('Failed to delete refresh token', error: e, stackTrace: stackTrace);
    }
  }

  // ========== API Signing Key ==========

  /// API署名キーを保存
  Future<void> saveSigningKey(String key) async {
    try {
      await _storage.write(key: _signingKeyKey, value: key);
      logger.d('API signing key saved');
    } catch (e, stackTrace) {
      logger.e('Failed to save signing key', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// API署名キーを取得
  Future<String?> getSigningKey() async {
    try {
      return await _storage.read(key: _signingKeyKey);
    } catch (e, stackTrace) {
      logger.e('Failed to get signing key', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// API署名キーを削除
  Future<void> deleteSigningKey() async {
    try {
      await _storage.delete(key: _signingKeyKey);
    } catch (e, stackTrace) {
      logger.e('Failed to delete signing key', error: e, stackTrace: stackTrace);
    }
  }

  // ========== Utilities ==========

  /// すべてのセキュアデータを削除
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      logger.i('All secure data cleared');
    } catch (e, stackTrace) {
      logger.e('Failed to clear secure data', error: e, stackTrace: stackTrace);
    }
  }

  /// キーが存在するか確認
  Future<bool> containsKey(String key) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (e, stackTrace) {
      logger.e('Failed to check key existence', error: e, stackTrace: stackTrace);
      return false;
    }
  }
}
