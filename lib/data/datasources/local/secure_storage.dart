import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/utils/logger.dart';

/// セキュアストレージサービス
/// 機密情報（デバイスID、トークンなど）を安全に保存
class SecureStorage {
  static const String _deviceIdKey = 'device_id';
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  final FlutterSecureStorage _storage;

  SecureStorage()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock_this_device,
          ),
        );

  // ========== Device ID ==========

  /// デバイスIDを保存
  Future<void> saveDeviceId(String deviceId) async {
    try {
      await _storage.write(key: _deviceIdKey, value: deviceId);
      logger.d('Device ID saved');
    } catch (e, stackTrace) {
      logger.e('Failed to save device ID', error: e, stackTrace: stackTrace);
      rethrow;
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
}
