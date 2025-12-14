import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/utils/logger.dart';
import '../../../domain/entities/pixel_art.dart';
import '../../../domain/entities/anonymous_user.dart';

/// ローカルストレージサービス
class LocalStorage {
  static const String _pixelArtBoxName = 'pixel_arts';
  static const String _albumBoxName = 'album';
  static const String _userBoxName = 'user';
  static const String _settingsBoxName = 'settings';

  Box<Map<dynamic, dynamic>>? _pixelArtBox;
  Box<Map<dynamic, dynamic>>? _albumBox;
  Box<Map<dynamic, dynamic>>? _userBox;
  Box<Map<dynamic, dynamic>>? _settingsBox;

  bool _isInitialized = false;

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
      logger.i('LocalStorage initialized');
    } catch (e, stackTrace) {
      logger.e(
        'Failed to initialize LocalStorage',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// ボックスを安全に開く（破損時は削除して再作成）
  Future<Box<Map<dynamic, dynamic>>> _openBoxSafely(String boxName) async {
    // 既に開いているボックスがあれば再利用
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<Map<dynamic, dynamic>>(boxName);
    }

    try {
      return await Hive.openBox<Map<dynamic, dynamic>>(boxName);
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
        return await Hive.openBox<Map<dynamic, dynamic>>(boxName);
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
    await _pixelArtBox?.put(pixelArt.id, pixelArt.toJson());
  }

  /// ドット絵を取得
  PixelArt? getPixelArt(String id) {
    final data = _pixelArtBox?.get(id);
    if (data == null) return null;
    return PixelArt.fromJson(_convertMap(data));
  }

  /// すべてのドット絵を取得
  List<PixelArt> getAllPixelArts() {
    final values = _pixelArtBox?.values ?? [];
    return values.map((data) => PixelArt.fromJson(_convertMap(data))).toList();
  }

  /// ドット絵を削除
  Future<void> deletePixelArt(String id) async {
    await _pixelArtBox?.delete(id);
  }

  // ========== Album ==========

  /// アルバムにドット絵を追加
  Future<void> addToAlbum(PixelArt pixelArt) async {
    await _albumBox?.put(pixelArt.id, pixelArt.toJson());
  }

  /// アルバムのドット絵を取得
  List<PixelArt> getAlbumPixelArts() {
    final values = _albumBox?.values ?? [];
    return values.map((data) => PixelArt.fromJson(_convertMap(data))).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// アルバムからドット絵を削除
  Future<void> removeFromAlbum(String id) async {
    await _albumBox?.delete(id);
  }

  /// 日付でフィルタリング
  List<PixelArt> getAlbumByDate(DateTime date) {
    return getAlbumPixelArts().where((art) {
      return art.createdAt.year == date.year &&
          art.createdAt.month == date.month &&
          art.createdAt.day == date.day;
    }).toList();
  }

  // ========== User ==========

  /// ユーザーを保存
  Future<void> saveUser(AnonymousUser user) async {
    // ネストされたオブジェクトも含めて完全にJSONに変換
    final json = user.toJson();
    // settings を明示的に toJson() で変換
    json['settings'] = user.settings.toJson();
    await _userBox?.put('current', json);
  }

  /// ユーザーを取得
  AnonymousUser? getUser() {
    final data = _userBox?.get('current');
    if (data == null) return null;
    // Hiveから取得したMapは Map<dynamic, dynamic> なので再帰的に変換
    return AnonymousUser.fromJson(_convertMap(data));
  }

  /// Map<dynamic, dynamic> を再帰的に Map<String, dynamic> に変換
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
    await _userBox?.delete('current');
  }

  // ========== Settings ==========

  /// 設定を保存
  Future<void> saveSetting(String key, dynamic value) async {
    await _settingsBox?.put(key, {'value': value});
  }

  /// 設定を取得
  T? getSetting<T>(String key) {
    final data = _settingsBox?.get(key);
    if (data == null) return null;
    return data['value'] as T?;
  }

  // ========== Utilities ==========

  /// すべてのデータをクリア
  Future<void> clearAll() async {
    await _pixelArtBox?.clear();
    await _albumBox?.clear();
    await _userBox?.clear();
    await _settingsBox?.clear();
    logger.i('All local data cleared');
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
