import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/local/local_storage.dart';
import '../data/datasources/local/secure_storage.dart';
import '../data/datasources/remote/api_client.dart';
import '../data/repositories/album_repository_impl.dart';
import '../data/repositories/pixel_art_repository_impl.dart';
import '../data/repositories/post_repository_impl.dart';
import '../domain/repositories/album_repository.dart';
import '../domain/repositories/pixel_art_repository.dart';
import '../domain/repositories/post_repository.dart';
import '../services/ad/ad_service.dart';
import '../services/auth/anonymous_auth_service.dart';
import '../services/notification/notification_service.dart';
import '../services/sync/connectivity_service.dart';
import '../services/sync/offline_queue_service.dart';
import '../services/sync/sync_service.dart';

/// ローカルストレージプロバイダー
final localStorageProvider = Provider<LocalStorage>((ref) {
  return LocalStorage();
});

/// セキュアストレージプロバイダー
final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage();
});

/// 匿名認証サービスプロバイダー
final authServiceProvider = Provider<AnonymousAuthService>((ref) {
  return AnonymousAuthService(
    localStorage: ref.watch(localStorageProvider),
    secureStorage: ref.watch(secureStorageProvider),
  );
});

/// APIクライアントプロバイダー
final apiClientProvider = Provider<ApiClient>((ref) {
  // デバイスIDは非同期で取得されるため、初期は null
  // Note: ローディング表示は各画面で個別に管理する
  return ApiClient();
});

/// ドット絵リポジトリプロバイダー
final pixelArtRepositoryProvider = Provider<PixelArtRepository>((ref) {
  return PixelArtRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
    localStorage: ref.watch(localStorageProvider),
  );
});

/// アルバムリポジトリプロバイダー
final albumRepositoryProvider = Provider.family<AlbumRepository, String>((ref, userId) {
  return AlbumRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
    localStorage: ref.watch(localStorageProvider),
    userId: userId,
  );
});

/// 投稿リポジトリプロバイダー
final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
  );
});

/// 接続状態監視サービスプロバイダー
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// オフラインキューサービスプロバイダー
final offlineQueueServiceProvider = Provider<OfflineQueueService>((ref) {
  return OfflineQueueService();
});

/// 同期サービスプロバイダー
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    connectivityService: ref.watch(connectivityServiceProvider),
    offlineQueueService: ref.watch(offlineQueueServiceProvider),
    apiClient: ref.watch(apiClientProvider),
  );
});

/// オンライン状態プロバイダー
final isOnlineProvider = StreamProvider<bool>((ref) {
  final connectivityService = ref.watch(connectivityServiceProvider);
  return connectivityService.onStatusChange;
});

/// 同期状態プロバイダー
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.onStatusChange;
});

/// 通知サービスプロバイダー
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// 未読通知数プロバイダー
final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  return notificationService.onUnreadCountChange;
});

/// 通知権限状態プロバイダー
final notificationPermissionProvider =
    FutureProvider<NotificationPermissionStatus>((ref) async {
  final notificationService = ref.watch(notificationServiceProvider);
  return notificationService.getNotificationPermissionStatus();
});

/// 広告サービスプロバイダー
final adServiceProvider = Provider<AdService>((ref) {
  return AdService.instance;
});

/// 交換回数カウントキー
const String _exchangeCountKey = 'exchange_count';

/// 交換回数プロバイダー
final exchangeCountProvider =
    StateNotifierProvider<ExchangeCountNotifier, int>((ref) {
  final localStorage = ref.watch(localStorageProvider);
  return ExchangeCountNotifier(localStorage);
});

/// 交換回数の状態管理
class ExchangeCountNotifier extends StateNotifier<int> {
  ExchangeCountNotifier(this._localStorage) : super(0) {
    _loadCount();
  }

  final LocalStorage _localStorage;

  void _loadCount() {
    final count = _localStorage.getSetting<int>(_exchangeCountKey) ?? 0;
    state = count;
  }

  /// 交換回数をインクリメント
  Future<void> increment() async {
    state = state + 1;
    await _localStorage.saveSetting(_exchangeCountKey, state);
  }

  /// 広告を表示すべきかどうか（3回に1回）
  bool get shouldShowAd => state > 0 && state % 3 == 0;
}
