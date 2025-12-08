import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'providers/theme_provider.dart';

/// アプリケーションウィジェット
class PixelDiaryApp extends ConsumerWidget {
  const PixelDiaryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,

      // テーマ設定
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,

      // ルーティング
      routerConfig: appRouter,
    );
  }
}
