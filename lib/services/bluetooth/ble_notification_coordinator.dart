import 'dart:async';

import '../../core/utils/logger.dart';
import '../../domain/entities/pixel_art.dart';
import '../notification/notification_service.dart';
import 'ble_service.dart';

/// BLEとローカル通知を連携するコーディネーター
///
/// すれ違い検知時にプッシュ通知を送信し、バッジ数を管理する
class BleNotificationCoordinator {
  BleNotificationCoordinator({
    required BleService bleService,
    required NotificationService notificationService,
  })  : _bleService = bleService,
        _notificationService = notificationService;

  final BleService _bleService;
  final NotificationService _notificationService;

  StreamSubscription<List<DiscoveredDevice>>? _discoveredDevicesSubscription;
  StreamSubscription<PixelArt>? _receivedArtSubscription;

  /// 通知済みデバイスIDのキャッシュ（重複通知防止）
  final Set<String> _notifiedDeviceIds = {};

  /// 通知キャッシュの有効期限（分）
  static const int _notificationCacheDurationMinutes = 5;

  /// 通知キャッシュのタイムスタンプ
  final Map<String, DateTime> _notificationTimestamps = {};

  /// すれ違い通知が有効かどうか
  bool _isEncounterNotificationEnabled = true;

  /// 交換完了通知が有効かどうか
  bool _isExchangeNotificationEnabled = true;

  /// 初期化
  Future<void> init() async {
    // デバイス発見時の購読
    _discoveredDevicesSubscription =
        _bleService.discoveredDevicesStream.listen(_onDevicesDiscovered);

    // ドット絵受信時の購読
    _receivedArtSubscription =
        _bleService.receivedArtStream.listen(_onArtReceived);

    logger.i('BleNotificationCoordinator initialized');
  }

  /// すれ違い通知を有効/無効
  void setEncounterNotificationEnabled(bool enabled) {
    _isEncounterNotificationEnabled = enabled;
    logger.d('Encounter notification enabled: $enabled');
  }

  /// 交換完了通知を有効/無効
  void setExchangeNotificationEnabled(bool enabled) {
    _isExchangeNotificationEnabled = enabled;
    logger.d('Exchange notification enabled: $enabled');
  }

  /// デバイス発見時の処理
  void _onDevicesDiscovered(List<DiscoveredDevice> devices) {
    if (!_isEncounterNotificationEnabled) return;

    // 期限切れのキャッシュをクリア
    _cleanupExpiredCache();

    for (final device in devices) {
      // 既に通知済みならスキップ
      if (_notifiedDeviceIds.contains(device.deviceId)) continue;

      // キャッシュに追加
      _notifiedDeviceIds.add(device.deviceId);
      _notificationTimestamps[device.deviceId] = DateTime.now();

      // 通知を表示
      _showEncounterNotification(device);
    }
  }

  /// すれ違い通知を表示
  Future<void> _showEncounterNotification(DiscoveredDevice device) async {
    final nickname = device.nickname ?? '誰か';
    final title = 'すれ違いました！';
    final body = '$nicknameが近くにいます。ドット絵を交換しませんか？';

    await _notificationService.showBleEncounterNotification(
      title: title,
      body: body,
      payload: 'ble_encounter:${device.deviceId}',
    );

    logger.d('Encounter notification shown for device: ${device.deviceId}');
  }

  /// ドット絵受信時の処理
  void _onArtReceived(PixelArt art) {
    if (!_isExchangeNotificationEnabled) return;

    _showExchangeCompleteNotification(art);
  }

  /// 交換完了通知を表示
  Future<void> _showExchangeCompleteNotification(PixelArt art) async {
    final authorName = art.authorNickname ?? '誰か';
    final title = 'ドット絵を受け取りました！';
    final body = '$authorNameから「${art.title}」が届きました';

    await _notificationService.showBleEncounterNotification(
      title: title,
      body: body,
      payload: 'ble_exchange:${art.id}',
    );

    logger.d('Exchange complete notification shown for art: ${art.id}');
  }

  /// 期限切れのキャッシュをクリア
  void _cleanupExpiredCache() {
    final now = DateTime.now();
    final expiredIds = <String>[];

    for (final entry in _notificationTimestamps.entries) {
      final elapsed = now.difference(entry.value);
      if (elapsed.inMinutes >= _notificationCacheDurationMinutes) {
        expiredIds.add(entry.key);
      }
    }

    for (final id in expiredIds) {
      _notifiedDeviceIds.remove(id);
      _notificationTimestamps.remove(id);
    }

    if (expiredIds.isNotEmpty) {
      logger.d('Cleaned up ${expiredIds.length} expired notification caches');
    }
  }

  /// 通知キャッシュをクリア
  void clearNotificationCache() {
    _notifiedDeviceIds.clear();
    _notificationTimestamps.clear();
    logger.d('Notification cache cleared');
  }

  /// バッジ数をクリア
  Future<void> clearBadge() async {
    await _notificationService.clearUnreadCount();
  }

  /// 現在の未読数を取得
  int get unreadCount => _notificationService.unreadCount;

  /// 未読数のストリーム
  Stream<int> get onUnreadCountChange =>
      _notificationService.onUnreadCountChange;

  /// リソースを解放
  Future<void> dispose() async {
    await _discoveredDevicesSubscription?.cancel();
    await _receivedArtSubscription?.cancel();
  }
}
