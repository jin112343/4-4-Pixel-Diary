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

  Box<Map>? _pixelArtBox;
  Box<Map>? _albumBox;
  Box<Map>? _userBox;
  Box<Map>? _settingsBox;

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
      // 各ボックスを安全に開く（破損時はリカバリー）
      _pixelArtBox = await _openBoxSafely(_pixelArtBoxName);
      _albumBox = await _openBoxSafely(_albumBoxName);
      _userBox = await _openBoxSafely(_userBoxName);
      _settingsBox = await _openBoxSafely(_settingsBoxName);

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
  Future<Box<Map>> _openBoxSafely(String boxName) async {
    // 既に開いているボックスがあれば再利用
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<Map>(boxName);
    }

    try {
      return await Hive.openBox<Map>(boxName);
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
        return await Hive.openBox<Map>(boxName);
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
    return PixelArt.fromJson(Map<String, dynamic>.from(data));
  }

  /// すべてのドット絵を取得
  List<PixelArt> getAllPixelArts() {
    final values = _pixelArtBox?.values ?? [];
    return values
        .map((data) => PixelArt.fromJson(Map<String, dynamic>.from(data)))
        .toList();
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
    return values
        .map((data) => PixelArt.fromJson(Map<String, dynamic>.from(data)))
        .toList()
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
    return AnonymousUser.fromJson(Map<String, dynamic>.from(data));
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
