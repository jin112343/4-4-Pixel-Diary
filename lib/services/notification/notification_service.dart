import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/utils/logger.dart';

/// 通知トピック
class NotificationTopic {
  /// 新しいドット絵受信通知
  static const String newPixelArt = 'new_pixel_art';

  /// いいね通知
  static const String likes = 'likes';

  /// コメント通知
  static const String comments = 'comments';

  /// アプリ全体のお知らせ
  static const String announcements = 'announcements';
}

/// 通知データ
class NotificationData {
  final String? title;
  final String? body;
  final Map<String, dynamic>? data;
  final DateTime receivedAt;

  NotificationData({
    this.title,
    this.body,
    this.data,
    required this.receivedAt,
  });
}

/// 通知権限の状態
enum NotificationPermissionStatus {
  /// 許可済み
  granted,

  /// 拒否
  denied,

  /// 永続的に拒否（設定から変更が必要）
  permanentlyDenied,

  /// 制限あり（iOSのみ）
  restricted,

  /// 仮許可（iOSのみ）
  provisional,

  /// 不明
  unknown,
}

/// ローカル通知チャンネルID
class NotificationChannelId {
  /// すれ違い通知
  static const String bleEncounter = 'ble_encounter';

  /// 一般通知
  static const String general = 'general';
}

/// プッシュ通知サービス（トピックベース・匿名）
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final _notificationController =
      StreamController<NotificationData>.broadcast();

  /// 通知受信ストリーム
  Stream<NotificationData> get onNotification =>
      _notificationController.stream;

  /// 購読中のトピック
  final Set<String> _subscribedTopics = {};

  /// 未読通知数
  int _unreadCount = 0;

  /// 未読通知数を取得
  int get unreadCount => _unreadCount;

  /// 未読通知数変更ストリーム
  final _unreadCountController = StreamController<int>.broadcast();

  /// 未読通知数ストリーム
  Stream<int> get onUnreadCountChange => _unreadCountController.stream;

  /// 通知クリックストリーム
  final _notificationClickController =
      StreamController<NotificationData>.broadcast();

  /// 通知クリックストリーム
  Stream<NotificationData> get onNotificationClick =>
      _notificationClickController.stream;

  /// 初期化
  Future<void> init() async {
    try {
      // Firebase初期化（まだの場合）
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      // ローカル通知の初期化
      await _initLocalNotifications();

      // 通知権限リクエスト
      await _requestPermission();

      // フォアグラウンド通知リスナー設定
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // バックグラウンド通知リスナー設定
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

      // 初期通知チェック（アプリが通知から起動された場合）
      await _checkInitialMessage();

      logger.i('NotificationService initialized');
    } catch (e, stackTrace) {
      logger.e(
        'NotificationService.init failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// ローカル通知の初期化
  Future<void> _initLocalNotifications() async {
    // Android設定
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS設定
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Androidの通知チャンネルを作成
    if (Platform.isAndroid) {
      await _createAndroidNotificationChannels();
    }
  }

  /// Android通知チャンネルを作成
  Future<void> _createAndroidNotificationChannels() async {
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // すれ違い通知チャンネル
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationChannelId.bleEncounter,
        'すれ違い通知',
        description: '近くのユーザーとすれ違った時の通知',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );

    // 一般通知チャンネル
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationChannelId.general,
        '一般通知',
        description: 'アプリからの一般的な通知',
        importance: Importance.defaultImportance,
        showBadge: true,
      ),
    );
  }

  /// 通知タップ時の処理
  void _onNotificationTapped(NotificationResponse response) {
    logger.d('Notification tapped: ${response.payload}');

    final notification = NotificationData(
      title: null,
      body: null,
      data: response.payload != null ? {'payload': response.payload} : null,
      receivedAt: DateTime.now(),
    );

    _notificationClickController.add(notification);
  }

  /// 通知権限をリクエスト
  Future<bool> _requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final isAuthorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;

      logger.i('Notification permission: ${settings.authorizationStatus}');
      return isAuthorized;
    } catch (e, stackTrace) {
      logger.e(
        'NotificationService._requestPermission failed',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// 通知権限をリクエスト（OS別ダイアログ表示）
  Future<NotificationPermissionStatus> requestNotificationPermission() async {
    try {
      // permission_handlerで権限リクエスト
      final status = await Permission.notification.request();

      return _convertPermissionStatus(status);
    } catch (e, stackTrace) {
      logger.e(
        'requestNotificationPermission failed',
        error: e,
        stackTrace: stackTrace,
      );
      return NotificationPermissionStatus.unknown;
    }
  }

  /// 通知権限の状態を取得
  Future<NotificationPermissionStatus> getNotificationPermissionStatus() async {
    try {
      final status = await Permission.notification.status;
      return _convertPermissionStatus(status);
    } catch (e, stackTrace) {
      logger.e(
        'getNotificationPermissionStatus failed',
        error: e,
        stackTrace: stackTrace,
      );
      return NotificationPermissionStatus.unknown;
    }
  }

  /// PermissionStatusを変換
  NotificationPermissionStatus _convertPermissionStatus(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return NotificationPermissionStatus.granted;
      case PermissionStatus.denied:
        return NotificationPermissionStatus.denied;
      case PermissionStatus.permanentlyDenied:
        return NotificationPermissionStatus.permanentlyDenied;
      case PermissionStatus.restricted:
        return NotificationPermissionStatus.restricted;
      case PermissionStatus.provisional:
        return NotificationPermissionStatus.provisional;
      case PermissionStatus.limited:
        return NotificationPermissionStatus.granted;
    }
  }

  /// 設定アプリを開く
  Future<bool> openNotificationSettings() async {
    try {
      return await openAppSettings();
    } catch (e, stackTrace) {
      logger.e(
        'openNotificationSettings failed',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// フォアグラウンド通知ハンドラー
  void _handleForegroundMessage(RemoteMessage message) {
    logger.d('Foreground message received: ${message.messageId}');

    final notification = NotificationData(
      title: message.notification?.title,
      body: message.notification?.body,
      data: message.data,
      receivedAt: DateTime.now(),
    );

    _notificationController.add(notification);

    // バッジ数を増やす
    incrementUnreadCount();
  }

  /// バックグラウンド通知ハンドラー
  void _handleBackgroundMessage(RemoteMessage message) {
    logger.d('Background message opened: ${message.messageId}');

    final notification = NotificationData(
      title: message.notification?.title,
      body: message.notification?.body,
      data: message.data,
      receivedAt: DateTime.now(),
    );

    _notificationController.add(notification);
  }

  /// 初期通知チェック
  Future<void> _checkInitialMessage() async {
    try {
      final initialMessage = await _messaging.getInitialMessage();

      if (initialMessage != null) {
        logger.d('Initial message: ${initialMessage.messageId}');

        final notification = NotificationData(
          title: initialMessage.notification?.title,
          body: initialMessage.notification?.body,
          data: initialMessage.data,
          receivedAt: DateTime.now(),
        );

        _notificationController.add(notification);
      }
    } catch (e, stackTrace) {
      logger.e(
        'NotificationService._checkInitialMessage failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ========== ローカル通知 ==========

  /// すれ違い通知を表示
  Future<void> showBleEncounterNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        NotificationChannelId.bleEncounter,
        'すれ違い通知',
        channelDescription: '近くのユーザーとすれ違った時の通知',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
        payload: payload,
      );

      // バッジ数を増やす
      incrementUnreadCount();

      logger.d('BLE encounter notification shown');
    } catch (e, stackTrace) {
      logger.e(
        'showBleEncounterNotification failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// 一般的なローカル通知を表示
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        NotificationChannelId.general,
        '一般通知',
        channelDescription: 'アプリからの一般的な通知',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
        payload: payload,
      );

      logger.d('Local notification shown');
    } catch (e, stackTrace) {
      logger.e(
        'showLocalNotification failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ========== バッジ管理 ==========

  /// 未読数を増やす
  void incrementUnreadCount() {
    _unreadCount++;
    _updateBadge();
    _unreadCountController.add(_unreadCount);
  }

  /// 未読数を設定
  void setUnreadCount(int count) {
    _unreadCount = count;
    _updateBadge();
    _unreadCountController.add(_unreadCount);
  }

  /// 未読数をクリア
  Future<void> clearUnreadCount() async {
    _unreadCount = 0;
    await _removeBadge();
    _unreadCountController.add(_unreadCount);
  }

  /// バッジを更新
  Future<void> _updateBadge() async {
    try {
      // バッジがサポートされているか確認
      final isSupported = await FlutterAppBadger.isAppBadgeSupported();
      if (!isSupported) {
        logger.w('App badge is not supported on this device');
        return;
      }

      await FlutterAppBadger.updateBadgeCount(_unreadCount);
      logger.d('Badge updated: $_unreadCount');
    } catch (e, stackTrace) {
      logger.e(
        '_updateBadge failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// バッジを削除
  Future<void> _removeBadge() async {
    try {
      final isSupported = await FlutterAppBadger.isAppBadgeSupported();
      if (!isSupported) return;

      await FlutterAppBadger.removeBadge();
      logger.d('Badge removed');
    } catch (e, stackTrace) {
      logger.e(
        '_removeBadge failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ========== トピック管理 ==========

  /// トピックを購読（匿名・個人情報不要）
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      _subscribedTopics.add(topic);
      logger.i('Subscribed to topic: $topic');
    } catch (e, stackTrace) {
      logger.e(
        'NotificationService.subscribeToTopic failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// トピックの購読を解除
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      _subscribedTopics.remove(topic);
      logger.i('Unsubscribed from topic: $topic');
    } catch (e, stackTrace) {
      logger.e(
        'NotificationService.unsubscribeFromTopic failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// デフォルトのトピックを購読
  Future<void> subscribeToDefaultTopics() async {
    await subscribeToTopic(NotificationTopic.announcements);
  }

  /// ユーザー設定に基づいてトピックを更新
  Future<void> updateTopicSubscriptions({
    bool newPixelArt = true,
    bool likes = true,
    bool comments = true,
  }) async {
    if (newPixelArt) {
      await subscribeToTopic(NotificationTopic.newPixelArt);
    } else {
      await unsubscribeFromTopic(NotificationTopic.newPixelArt);
    }

    if (likes) {
      await subscribeToTopic(NotificationTopic.likes);
    } else {
      await unsubscribeFromTopic(NotificationTopic.likes);
    }

    if (comments) {
      await subscribeToTopic(NotificationTopic.comments);
    } else {
      await unsubscribeFromTopic(NotificationTopic.comments);
    }
  }

  /// 購読中のトピック一覧を取得
  Set<String> get subscribedTopics => Set.unmodifiable(_subscribedTopics);

  /// 通知権限の状態を確認
  Future<AuthorizationStatus> getPermissionStatus() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus;
  }

  /// 通知が許可されているか
  Future<bool> isNotificationEnabled() async {
    final status = await getPermissionStatus();
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  /// リソースを解放
  void dispose() {
    _notificationController.close();
    _unreadCountController.close();
    _notificationClickController.close();
  }
}

/// バックグラウンドメッセージハンドラー（トップレベル関数である必要がある）
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase初期化
  await Firebase.initializeApp();

  if (kDebugMode) {
    debugPrint('Background message: ${message.messageId}');
  }
}
