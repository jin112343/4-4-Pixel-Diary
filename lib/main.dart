import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/utils/logger.dart';
import 'services/security/security_service.dart';
import 'services/sync/connectivity_service.dart';
import 'services/sync/offline_queue_service.dart';

/// グローバルサービスインスタンス
late final ConnectivityService connectivityService;
late final OfflineQueueService offlineQueueService;
late final SecurityService securityService;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 日本語ロケール初期化
  await initializeDateFormatting('ja_JP');

  // Hive初期化
  await _initializeHive();

  // サービス初期化
  await _initializeServices();

  // セキュリティチェック
  await _performSecurityCheck();

  // アプリ起動
  runApp(
    const ProviderScope(
      child: PixelDiaryApp(),
    ),
  );
}

/// Hiveの初期化
Future<void> _initializeHive() async {
  try {
    await Hive.initFlutter();
    logger.i('Hive initialized successfully');
  } catch (e, stackTrace) {
    logger.e('Failed to initialize Hive', error: e, stackTrace: stackTrace);
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
