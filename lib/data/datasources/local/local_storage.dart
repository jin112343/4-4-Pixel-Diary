import 'dart:convert';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/utils/logger.dart';
import '../../../domain/entities/pixel_art.dart';
import '../../../domain/entities/anonymous_user.dart';

/// ローカルストレージサービス（暗号化対応）
///
/// セキュリティ対策:
/// - Hive暗号化を使用してデータを保護
/// - 暗号化キーはSecureStorageで安全に保管
class LocalStorage {
  static const String _pixelArtBoxName = 'pixel_arts';
  static const String _albumBoxName = 'album';
  static const String _userBoxName = 'user';
  static const String _settingsBoxName = 'settings';
  static const String _encryptionKeyName = 'hive_encryption_key';

  Box<Map<dynamic, dynamic>>? _pixelArtBox;
  Box<Map<dynamic, dynamic>>? _albumBox;
  Box<Map<dynamic, dynamic>>? _userBox;
  Box<Map<dynamic, dynamic>>? _settingsBox;

  bool _isInitialized = false;
  Uint8List? _encryptionKey;

  // セキュアストレージ（暗号化キーの保管用）
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// 初期化済みかどうか
  bool get isInitialized => _isInitialized;

  /// 初期化
  Future<void> init() async {
    // 既に初期化済みの場合はスキップ
    if (_isInitialized) {
      logger.d('LocalStorage already initialized, skipping');
      return;
    }

    try {
      // 暗号化キーを取得または生成
      _encryptionKey = await _getOrCreateEncryptionKey();
      logger.d('Encryption key ready');

      // 各ボックスを並列で安全に開く（破損時はリカバリー）
      final results = await Future.wait([
        _openBoxSafely(_pixelArtBoxName),
        _openBoxSafely(_albumBoxName),
        _openBoxSafely(_userBoxName),
        _openBoxSafely(_settingsBoxName),
      ]);

      _pixelArtBox = results[0];
      _albumBox = results[1];
      _userBox = results[2];
      _settingsBox = results[3];

      _isInitialized = true;
      logger.i('LocalStorage initialized with encryption');
    } catch (e, stackTrace) {
      logger.e(
        'Failed to initialize LocalStorage',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 暗号化キーを取得または新規生成
  Future<Uint8List> _getOrCreateEncryptionKey() async {
    try {
      // 既存のキーを取得
      final existingKey = await _secureStorage.read(key: _encryptionKeyName);

      if (existingKey != null) {
        logger.d('Using existing encryption key');
        return base64Decode(existingKey);
      }

      // 新しいキーを生成
      logger.i('Generating new encryption key');
      final newKey = Hive.generateSecureKey();
      final keyString = base64Encode(newKey);

      // セキュアストレージに保存
      await _secureStorage.write(
        key: _encryptionKeyName,
        value: keyString,
      );

      return Uint8List.fromList(newKey);
    } catch (e, stackTrace) {
      logger.e(
        'Failed to get/create encryption key',
        error: e,
        stackTrace: stackTrace,
      );
      // フォールバック: 暗号化なしで動作（デバッグ用）
      logger.w('Falling back to non-encrypted storage');
      return Uint8List(0);
    }
  }

  /// ボックスを安全に開く（破損時は削除して再作成）
  Future<Box<Map<dynamic, dynamic>>> _openBoxSafely(String boxName) async {
    // 既に開いているボックスがあれば再利用
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<Map<dynamic, dynamic>>(boxName);
    }

    // 暗号化キーがある場合は暗号化ボックスを開く
    final cipher = _encryptionKey != null && _encryptionKey!.isNotEmpty
        ? HiveAesCipher(_encryptionKey!)
        : null;

    try {
      return await Hive.openBox<Map<dynamic, dynamic>>(
        boxName,
        encryptionCipher: cipher,
      );
    } catch (e, stackTrace) {
      logger.w(
        'Box "$boxName" corrupted, attempting recovery',
        error: e,
        stackTrace: stackTrace,
      );

      // 破損したボックスを削除して再作成
      try {
        await Hive.deleteBoxFromDisk(boxName);
        logger.i('Deleted corrupted box: $boxName');
        return await Hive.openBox<Map<dynamic, dynamic>>(
          boxName,
          encryptionCipher: cipher,
        );
      } catch (deleteError, deleteStackTrace) {
        logger.e(
          'Failed to recover box "$boxName"',
          error: deleteError,
          stackTrace: deleteStackTrace,
        );
        rethrow;
      }
    }
  }

  // ========== PixelArt ==========

  /// ドット絵を保存
  Future<void> savePixelArt(PixelArt pixelArt) async {
    try {
      await _pixelArtBox?.put(pixelArt.id, pixelArt.toJson());
    } catch (e, stackTrace) {
      logger.e('Failed to save pixel art', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// ドット絵を取得
  PixelArt? getPixelArt(String id) {
    try {
      final data = _pixelArtBox?.get(id);
      if (data == null) return null;
      return PixelArt.fromJson(_convertMap(data));
    } catch (e, stackTrace) {
      logger.e('Failed to get pixel art', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// すべてのドット絵を取得
  List<PixelArt> getAllPixelArts() {
    try {
      final values = _pixelArtBox?.values ?? [];
      return values.map((data) => PixelArt.fromJson(_convertMap(data))).toList();
    } catch (e, stackTrace) {
      logger.e('Failed to get all pixel arts', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// ドット絵を削除
  Future<void> deletePixelArt(String id) async {
    try {
      await _pixelArtBox?.delete(id);
    } catch (e, stackTrace) {
      logger.e('Failed to delete pixel art', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ========== Album ==========

  /// アルバムにドット絵を追加
  Future<void> addToAlbum(PixelArt pixelArt) async {
    try {
      await _albumBox?.put(pixelArt.id, pixelArt.toJson());
    } catch (e, stackTrace) {
      logger.e('Failed to add to album', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// アルバムのドット絵を取得
  List<PixelArt> getAlbumPixelArts() {
    try {
      final values = _albumBox?.values ?? [];
      return values.map((data) => PixelArt.fromJson(_convertMap(data))).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e, stackTrace) {
      logger.e('Failed to get album pixel arts', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// アルバムからドット絵を削除
  Future<void> removeFromAlbum(String id) async {
    try {
      await _albumBox?.delete(id);
    } catch (e, stackTrace) {
      logger.e('Failed to remove from album', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 日付でフィルタリング
  List<PixelArt> getAlbumByDate(DateTime date) {
    try {
      return getAlbumPixelArts().where((art) {
        return art.createdAt.year == date.year &&
            art.createdAt.month == date.month &&
            art.createdAt.day == date.day;
      }).toList();
    } catch (e, stackTrace) {
      logger.e('Failed to get album by date', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  // ========== User ==========

  /// ユーザーを保存
  Future<void> saveUser(AnonymousUser user) async {
    try {
      // ネストされたオブジェクトも含めて完全にJSONに変換
      final json = user.toJson();
      // settings を明示的に toJson() で変換
      json['settings'] = user.settings.toJson();
      await _userBox?.put('current', json);
    } catch (e, stackTrace) {
      logger.e('Failed to save user', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// ユーザーを取得
  AnonymousUser? getUser() {
    try {
      final data = _userBox?.get('current');
      if (data == null) return null;
      // Hiveから取得したMapは Map<dynamic, dynamic> なので再帰的に変換
      return AnonymousUser.fromJson(_convertMap(data));
    } catch (e, stackTrace) {
      logger.e('Failed to get user', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// `Map<dynamic, dynamic>` を再帰的に `Map<String, dynamic>` に変換
  Map<String, dynamic> _convertMap(Map<dynamic, dynamic> map) {
    return map.map((key, value) {
      if (value is Map) {
        return MapEntry(key.toString(), _convertMap(value));
      } else if (value is List) {
        return MapEntry(key.toString(), _convertList(value));
      } else {
        return MapEntry(key.toString(), value);
      }
    });
  }

  /// List内のMapも再帰的に変換
  List<dynamic> _convertList(List<dynamic> list) {
    return list.map((item) {
      if (item is Map) {
        return _convertMap(item);
      } else if (item is List) {
        return _convertList(item);
      } else {
        return item;
      }
    }).toList();
  }

  /// ユーザーを削除
  Future<void> deleteUser() async {
    try {
      await _userBox?.delete('current');
    } catch (e, stackTrace) {
      logger.e('Failed to delete user', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ========== Settings ==========

  /// 設定を保存
  Future<void> saveSetting(String key, dynamic value) async {
    try {
      await _settingsBox?.put(key, {'value': value});
    } catch (e, stackTrace) {
      logger.e('Failed to save setting', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 設定を取得
  T? getSetting<T>(String key) {
    try {
      final data = _settingsBox?.get(key);
      if (data == null) return null;
      return data['value'] as T?;
    } catch (e, stackTrace) {
      logger.e('Failed to get setting', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  // ========== Utilities ==========

  /// すべてのデータをクリア
  Future<void> clearAll() async {
    try {
      await _pixelArtBox?.clear();
      await _albumBox?.clear();
      await _userBox?.clear();
      await _settingsBox?.clear();
      logger.i('All local data cleared');
    } catch (e, stackTrace) {
      logger.e('Failed to clear all data', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// ボックスを閉じる
  Future<void> close() async {
    await _pixelArtBox?.close();
    await _albumBox?.close();
    await _userBox?.close();
    await _settingsBox?.close();
  }

  /// 初期化状態をリセット（再初期化を許可）
  void resetInitializationState() {
    _isInitialized = false;
    _pixelArtBox = null;
    _albumBox = null;
    _userBox = null;
    _settingsBox = null;
    logger.d('LocalStorage initialization state reset');
  }
}
