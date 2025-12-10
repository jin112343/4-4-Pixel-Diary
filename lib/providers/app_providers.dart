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
import '../services/auth/anonymous_auth_service.dart';
import '../services/bluetooth/ble_dual_role_service.dart';
import '../services/bluetooth/ble_notification_coordinator.dart';
import '../services/bluetooth/ble_peripheral_native.dart';
import '../services/bluetooth/ble_service.dart';
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

/// BLEサービスプロバイダー（app_providers版）
final appBleServiceProvider = Provider<BleService>((ref) {
  final service = BleService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// BLE Peripheralネイティブプロバイダー
final blePeripheralNativeProvider = Provider<BlePeripheralNative>((ref) {
  return BlePeripheralNative();
});

/// BLE Dual Roleサービスプロバイダー
final bleDualRoleServiceProvider = Provider<BleDualRoleService>((ref) {
  final centralService = ref.watch(appBleServiceProvider);
  final peripheralNative = ref.watch(blePeripheralNativeProvider);

  final service = BleDualRoleService(
    centralService: centralService,
    peripheralNative: peripheralNative,
  );

  ref.onDispose(() => service.dispose());

  return service;
});

/// BLE通知コーディネータープロバイダー
final bleNotificationCoordinatorProvider =
    Provider<BleNotificationCoordinator>((ref) {
  final bleService = ref.watch(appBleServiceProvider);
  final notificationService = ref.watch(notificationServiceProvider);

  final coordinator = BleNotificationCoordinator(
    bleService: bleService,
    notificationService: notificationService,
  );

  ref.onDispose(() => coordinator.dispose());

  return coordinator;
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
