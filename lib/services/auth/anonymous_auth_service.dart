import 'package:uuid/uuid.dart';

import '../../core/utils/logger.dart';
import '../../data/datasources/local/local_storage.dart';
import '../../data/datasources/local/secure_storage.dart';
import '../../domain/entities/anonymous_user.dart';

/// 匿名認証サービス
/// 個人情報を一切収集せず、デバイスUUIDのみで識別
class AnonymousAuthService {
  final LocalStorage _localStorage;
  final SecureStorage _secureStorage;
  final Uuid _uuid = const Uuid();

  AnonymousUser? _currentUser;

  AnonymousAuthService({
    required LocalStorage localStorage,
    required SecureStorage secureStorage,
  })  : _localStorage = localStorage,
        _secureStorage = secureStorage;

  /// 現在のユーザーを取得
  AnonymousUser? get currentUser => _currentUser;

  /// ユーザーが存在するか
  bool get isAuthenticated => _currentUser != null;

  /// 初期化（アプリ起動時に呼び出す）
  Future<AnonymousUser> initialize() async {
    try {
      // 既存のデバイスIDを取得
      var deviceId = await _secureStorage.getDeviceId();

      if (deviceId == null) {
        // 新規デバイスID生成
        deviceId = _uuid.v4();
        await _secureStorage.saveDeviceId(deviceId);
        logger.i('New device ID generated');
      }

      // ローカルストレージからユーザー情報を取得
      var user = _localStorage.getUser();

      if (user == null || user.deviceId != deviceId) {
        // 新規ユーザー作成
        user = AnonymousUser(
          deviceId: deviceId,
          createdAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        );
        await _localStorage.saveUser(user);
        logger.i('New anonymous user created');
      } else {
        // 最終アクティブ日時を更新
        user = user.copyWith(lastActiveAt: DateTime.now());
        await _localStorage.saveUser(user);
      }

      _currentUser = user;
      return user;
    } catch (e, stackTrace) {
      logger.e('Failed to initialize auth', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// ニックネームを更新
  Future<AnonymousUser> updateNickname(String? nickname) async {
    if (_currentUser == null) {
      throw StateError('User not initialized');
    }

    final updatedUser = _currentUser!.copyWith(nickname: nickname);
    await _localStorage.saveUser(updatedUser);
    _currentUser = updatedUser;

    logger.i('Nickname updated: $nickname');
    return updatedUser;
  }

  /// 設定を更新
  Future<AnonymousUser> updateSettings(UserSettings settings) async {
    if (_currentUser == null) {
      throw StateError('User not initialized');
    }

    final updatedUser = _currentUser!.copyWith(settings: settings);
    await _localStorage.saveUser(updatedUser);
    _currentUser = updatedUser;

    logger.i('Settings updated');
    return updatedUser;
  }

  /// プレミアムグリッドを有効化
  Future<AnonymousUser> enablePremiumGrid() async {
    if (_currentUser == null) {
      throw StateError('User not initialized');
    }

    final updatedUser = _currentUser!.copyWith(hasPremiumGrid: true);
    await _localStorage.saveUser(updatedUser);
    _currentUser = updatedUser;

    logger.i('Premium grid enabled');
    return updatedUser;
  }

  /// すべてのユーザーデータを削除
  Future<void> deleteAllData() async {
    await _localStorage.clearAll();
    await _secureStorage.clearAll();
    _currentUser = null;

    logger.i('All user data deleted');
  }

  /// デバイスIDを取得
  Future<String?> getDeviceId() async {
    return _secureStorage.getDeviceId();
  }
}
