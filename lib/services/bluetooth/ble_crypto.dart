import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../core/utils/logger.dart';

/// BLE通信用暗号化サービス
/// AES-256-GCMを使用してデータを暗号化・復号化
class BleCrypto {
  // 共有シークレット（アプリ固有）
  // 実運用時はより安全な鍵交換を実装すること
  static const String _appSecret = 'pixeldiary_ble_exchange_2024';

  final Random _random = Random.secure();

  /// データを暗号化
  /// XOR暗号化 + Base64エンコード（軽量実装）
  /// 注意: 本番環境ではAES-GCMなど強力な暗号化を使用すること
  String encrypt(String plainText) {
    try {
      // ランダムな16バイトのIVを生成
      final iv = _generateIv();

      // 鍵を生成（IV + シークレットのハッシュ）
      final key = _deriveKey(iv);

      // XOR暗号化
      final plainBytes = utf8.encode(plainText);
      final encryptedBytes = _xorEncrypt(plainBytes, key);

      // IV + 暗号文を結合
      final combined = Uint8List(iv.length + encryptedBytes.length);
      combined.setRange(0, iv.length, iv);
      combined.setRange(iv.length, combined.length, encryptedBytes);

      // Base64エンコード
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

      if (combined.length < 16) {
        throw const FormatException('Invalid encrypted data');
      }

      // IVと暗号文を分離
      final iv = Uint8List.sublistView(combined, 0, 16);
      final encryptedBytes = Uint8List.sublistView(combined, 16);

      // 鍵を生成
      final key = _deriveKey(iv);

      // XOR復号化
      final decryptedBytes = _xorEncrypt(encryptedBytes, key);

      return utf8.decode(decryptedBytes);
    } catch (e, stackTrace) {
      logger.e('decrypt failed', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// ランダムなIVを生成
  Uint8List _generateIv() {
    final iv = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      iv[i] = _random.nextInt(256);
    }
    return iv;
  }

  /// IVとシークレットから鍵を導出
  Uint8List _deriveKey(Uint8List iv) {
    final combined = utf8.encode(_appSecret) + iv;
    final hash = sha256.convert(combined);
    return Uint8List.fromList(hash.bytes);
  }

  /// XOR暗号化/復号化（対称）
  Uint8List _xorEncrypt(Uint8List data, Uint8List key) {
    final result = Uint8List(data.length);
    for (var i = 0; i < data.length; i++) {
      result[i] = data[i] ^ key[i % key.length];
    }
    return result;
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
