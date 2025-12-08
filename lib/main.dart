import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/utils/logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive初期化
  await _initializeHive();

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
