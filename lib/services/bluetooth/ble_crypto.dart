import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;

import '../../core/utils/logger.dart';

/// BLE通信用暗号化サービス
/// AES-256-GCMを使用してデータを暗号化・復号化
class BleCrypto {
  // 共有シークレット（アプリ固有）
  // 環境変数から読み込み: --dart-define=BLE_CRYPTO_SECRET=your_secret
  static const String _appSecret = String.fromEnvironment(
    'BLE_CRYPTO_SECRET',
    defaultValue: '',
  );

  late final Encrypter _encrypter;
  late final Key _key;

  BleCrypto() {
    // 本番環境では暗号化キーが必須
    if (_appSecret.isEmpty) {
      if (kReleaseMode) {
        throw StateError(
          'BLE_CRYPTO_SECRET must be set in production build.\n'
          'Build with: flutter build --dart-define=BLE_CRYPTO_SECRET=your_secret_key',
        );
      }
      logger.w(
        'BLE_CRYPTO_SECRET is not set. Using development fallback key.\n'
        'This is only allowed in debug mode.',
      );
    }

    // シークレットから256ビット(32バイト)の鍵を導出
    _key = _deriveKey256(
      _appSecret.isNotEmpty ? _appSecret : 'dev_fallback_only_insecure',
    );
    _encrypter = Encrypter(AES(_key, mode: AESMode.gcm));
  }

  /// データを暗号化
  /// AES-256-GCM暗号化 + Base64エンコード
  String encrypt(String plainText) {
    try {
      // ランダムなIVを生成（GCMには12バイト推奨）
      final iv = IV.fromSecureRandom(12);

      // AES-GCM暗号化
      final encrypted = _encrypter.encrypt(plainText, iv: iv);

      // IV + 暗号文 + 認証タグを結合してBase64エンコード
      final combined = Uint8List.fromList([
        ...iv.bytes,
        ...encrypted.bytes,
      ]);

      return base64Encode(combined);
    } catch (e, stackTrace) {
      logger.e('encrypt failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// データを復号化
  String? decrypt(String encryptedText) {
    try {
      // Base64デコード
      final combined = base64Decode(encryptedText);

      if (combined.length < 12) {
        throw const FormatException('Invalid encrypted data');
      }

      // IVと暗号文を分離（GCMのIVは12バイト）
      final iv = IV(Uint8List.fromList(combined.sublist(0, 12)));
      final encryptedBytes = Uint8List.fromList(combined.sublist(12));

      // AES-GCM復号化
      final encrypted = Encrypted(encryptedBytes);
      final decrypted = _encrypter.decrypt(encrypted, iv: iv);

      return decrypted;
    } catch (e, stackTrace) {
      logger.e('decrypt failed', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// シークレットから256ビット(32バイト)の鍵を導出
  Key _deriveKey256(String secret) {
    // SHA-256でハッシュ化して32バイトの鍵を生成
    final hash = sha256.convert(utf8.encode(secret));
    return Key(Uint8List.fromList(hash.bytes));
  }

  /// チェックサムを計算
  String calculateChecksum(String data) {
    final bytes = utf8.encode(data);
    final hash = sha256.convert(bytes);
    return hash.toString().substring(0, 8);
  }

  /// チェックサムを検証
  bool verifyChecksum(String data, String checksum) {
    return calculateChecksum(data) == checksum;
  }
}
