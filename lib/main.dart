import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/utils/logger.dart';
import 'services/ad/ad_service.dart';
import 'services/security/security_service.dart';
import 'services/sync/connectivity_service.dart';
import 'services/sync/offline_queue_service.dart';

/// グローバルサービスインスタンス
late final ConnectivityService connectivityService;
late final OfflineQueueService offlineQueueService;
late final SecurityService securityService;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 独立した初期化を並列実行
  await Future.wait([
    initializeDateFormatting('ja_JP'),
    _initializeHive(),
  ]);

  // サービス初期化（Hive依存のため順次実行）
  await _initializeServices();

  // セキュリティチェックはバックグラウンドで実行（起動をブロックしない）
  _performSecurityCheck();

  // アプリ起動
  runApp(
    const ProviderScope(
      child: PixelDiaryApp(),
    ),
  );
}

/// Hiveの初期化とボックスの事前オープン
Future<void> _initializeHive() async {
  try {
    await Hive.initFlutter();

    // Hiveボックスを並列で事前オープン（initialization_providerでの待ち時間を削減）
    await Future.wait([
      _openBoxIfNeeded<Map<dynamic, dynamic>>('pixel_arts'),
      _openBoxIfNeeded<Map<dynamic, dynamic>>('album'),
      _openBoxIfNeeded<Map<dynamic, dynamic>>('user'),
      _openBoxIfNeeded<Map<dynamic, dynamic>>('settings'),
    ]);

    logger.i('Hive initialized with boxes pre-opened');
  } catch (e, stackTrace) {
    logger.e('Failed to initialize Hive', error: e, stackTrace: stackTrace);
  }
}

/// ボックスを安全にオープン
Future<void> _openBoxIfNeeded<T>(String boxName) async {
  if (!Hive.isBoxOpen(boxName)) {
    await Hive.openBox<T>(boxName);
  }
}

/// サービスの初期化
Future<void> _initializeServices() async {
  try {
    // 接続状態監視サービス
    connectivityService = ConnectivityService();
    await connectivityService.init();

    // オフラインキューサービス
    offlineQueueService = OfflineQueueService();
    await offlineQueueService.init();

    // セキュリティサービス
    securityService = SecurityService();

    // 広告サービス
    await AdService.instance.initialize();

    logger.i('Services initialized successfully');
  } catch (e, stackTrace) {
    logger.e('Failed to initialize services', error: e, stackTrace: stackTrace);
  }
}

/// セキュリティチェック
Future<void> _performSecurityCheck() async {
  try {
    final securityStatus = await securityService.checkSecurity();

    if (!securityStatus.isSecure) {
      logger.w('Security warning: ${securityStatus.warnings.join(", ")}');
    }
  } catch (e, stackTrace) {
    logger.e('Security check failed', error: e, stackTrace: stackTrace);
  }
}
