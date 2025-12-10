import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'core/utils/logger.dart';
import 'providers/theme_provider.dart';
import 'providers/initialization_provider.dart';
import 'presentation/pages/splash/splash_page.dart';

/// アプリケーションウィジェット
class PixelDiaryApp extends ConsumerWidget {
  const PixelDiaryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final initStatus = ref.watch(initializationProvider);

    // 初期化完了時はrouterを使用、それ以外は通常のMaterialApp
    if (initStatus == InitializationStatus.completed) {
      return MaterialApp.router(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        routerConfig: appRouter,
      );
    }

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: initStatus == InitializationStatus.failed
          ? _InitializationErrorPage()
          : const SplashPage(),
    );
  }
}

/// 初期化エラー画面
class _InitializationErrorPage extends ConsumerStatefulWidget {
  @override
  ConsumerState<_InitializationErrorPage> createState() =>
      _InitializationErrorPageState();
}

class _InitializationErrorPageState
    extends ConsumerState<_InitializationErrorPage> {
  bool _isResetting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 24),
              const Text(
                '初期化に失敗しました',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'アプリの起動に問題が発生しました。\n再度お試しください。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isResetting
                    ? null
                    : () {
                        ref.read(initializationProvider.notifier).retry();
                      },
                icon: const Icon(Icons.refresh),
                label: const Text('再試行'),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _isResetting ? null : _showResetConfirmDialog,
                icon: const Icon(Icons.delete_forever, color: Colors.orange),
                label: const Text(
                  'データをリセットして再起動',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
              if (_isResetting) ...[
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
                const SizedBox(height: 8),
                const Text('リセット中...'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showResetConfirmDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('データのリセット'),
        content: const Text(
          'すべてのローカルデータが削除されます。\n'
          '（ドット絵、アルバム、設定など）\n\n'
          'この操作は取り消せません。\n'
          '続行しますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetAllData();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('リセット'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetAllData() async {
    setState(() {
      _isResetting = true;
    });

    try {
      // すべてのHiveボックスを削除
      await Hive.deleteFromDisk();
      logger.i('All Hive data deleted');

      // Hiveを再初期化
      await Hive.initFlutter();
      logger.i('Hive re-initialized');

      // 初期化を再試行
      ref.read(initializationProvider.notifier).retry();
    } catch (e, stackTrace) {
      logger.e('Failed to reset data', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('リセットに失敗しました。アプリを再起動してください。'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isResetting = false;
        });
      }
    }
  }
}
