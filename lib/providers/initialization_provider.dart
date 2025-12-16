import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/utils/logger.dart';
import '../domain/entities/anonymous_user.dart';
import 'app_providers.dart';

/// 初期化状態
enum InitializationStatus { initializing, completed, failed }

/// 初期化状態プロバイダー
final initializationProvider =
    StateNotifierProvider<InitializationNotifier, InitializationStatus>(
      (ref) => InitializationNotifier(ref),
    );

/// 初期化状態Notifier
class InitializationNotifier extends StateNotifier<InitializationStatus> {
  InitializationNotifier(this._ref) : super(InitializationStatus.initializing) {
    _initialize();
  }

  final Ref _ref;

  Future<void> _initialize() async {
    try {
      logger.i('Starting app initialization...');

      final localStorage = _ref.read(localStorageProvider);
      final secureStorage = _ref.read(secureStorageProvider);

      // LocalStorageの初期化とSecureStorageからのdeviceID取得を並列実行
      final results = await Future.wait([
        localStorage.init(),
        secureStorage.getDeviceId(),
      ]);
      logger.i('LocalStorage and SecureStorage initialized in parallel');

      String? deviceId = results[1] as String?;

      // deviceIdがなければ新規生成
      if (deviceId == null) {
        deviceId = const Uuid().v4();
        await secureStorage.saveDeviceId(deviceId);
        logger.i('New device ID generated: $deviceId');
      }

      // ユーザー情報を取得・更新（AuthServiceをバイパスして高速化）
      var user = localStorage.getUser();
      if (user == null || user.deviceId != deviceId) {
        user = AnonymousUser(
          deviceId: deviceId,
          createdAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        );
        logger.i('New anonymous user created');
      } else {
        user = user.copyWith(lastActiveAt: DateTime.now());
      }
      await localStorage.saveUser(user);

      // AuthServiceにユーザーを設定
      final authService = _ref.read(authServiceProvider);
      authService.setCurrentUser(user);
      logger.i('Auth service initialized, deviceId: $deviceId');

      // APIクライアントにデバイスIDを設定
      final apiClient = _ref.read(apiClientProvider);
      apiClient.setDeviceId(deviceId);
      logger.i('ApiClient deviceId configured');

      state = InitializationStatus.completed;
      logger.i('App initialization completed');
    } catch (e, stackTrace) {
      logger.e('App initialization failed', error: e, stackTrace: stackTrace);
      state = InitializationStatus.failed;
    }
  }

  /// 初期化をリトライ
  void retry() {
    // LocalStorageの初期化状態をリセット
    try {
      final localStorage = _ref.read(localStorageProvider);
      localStorage.resetInitializationState();
    } catch (e) {
      logger.w('Failed to reset localStorage state: $e');
    }

    state = InitializationStatus.initializing;
    _initialize();
  }
}
