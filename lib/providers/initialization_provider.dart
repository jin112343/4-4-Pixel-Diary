import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/logger.dart';
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
  final Ref _ref;

  InitializationNotifier(this._ref) : super(InitializationStatus.initializing) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      logger.i('Starting app initialization...');

      // ローカルストレージを初期化
      try {
        final localStorage = _ref.read(localStorageProvider);
        await localStorage.init();
        logger.i('LocalStorage initialized');
      } catch (e, stackTrace) {
        logger.e('LocalStorage init failed', error: e, stackTrace: stackTrace);
        rethrow;
      }

      // 認証サービスを初期化してデバイスIDを取得
      String? deviceId;
      try {
        final authService = _ref.read(authServiceProvider);
        final user = await authService.initialize();
        deviceId = user.deviceId;
        logger.i('Auth service initialized, deviceId: $deviceId');
      } catch (e, stackTrace) {
        logger.e('Auth service init failed', error: e, stackTrace: stackTrace);
        rethrow;
      }

      // APIクライアントにデバイスIDを設定
      try {
        final apiClient = _ref.read(apiClientProvider);
        apiClient.setDeviceId(deviceId);
        logger.i('ApiClient deviceId configured');
      } catch (e, stackTrace) {
        logger.e('ApiClient config failed', error: e, stackTrace: stackTrace);
        rethrow;
      }

      // 初期化完了まで最低限の時間を確保（UX向上のため）
      await Future<void>.delayed(const Duration(milliseconds: 800));

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
