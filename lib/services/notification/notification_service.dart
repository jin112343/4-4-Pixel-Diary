import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

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

/// プッシュ通知サービス（トピックベース・匿名）
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  final _notificationController =
      StreamController<NotificationData>.broadcast();

  /// 通知受信ストリーム
  Stream<NotificationData> get onNotification => _notificationController.stream;

  /// 購読中のトピック
  final Set<String> _subscribedTopics = {};

  /// 初期化
  Future<void> init() async {
    try {
      // Firebase初期化（まだの場合）
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

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
  }
}

/// バックグラウンドメッセージハンドラー（トップレベル関数である必要がある）
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase初期化
  await Firebase.initializeApp();

  if (kDebugMode) {
    // ignore: avoid_print
    print('Background message: ${message.messageId}');
  }
}
