import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/app_config/app_config_service.dart';
import 'force_update_dialog.dart';
import 'maintenance_screen.dart';

/// アプリ設定チェッカー
/// アプリ起動時に強制アップデートとメンテナンスモードをチェックする
class AppConfigChecker extends ConsumerStatefulWidget {
  const AppConfigChecker({
    super.key,
    required this.child,
    required this.currentVersion,
  });

  final Widget child;
  final String currentVersion;

  @override
  ConsumerState<AppConfigChecker> createState() => _AppConfigCheckerState();
}

class _AppConfigCheckerState extends ConsumerState<AppConfigChecker> {
  bool _hasChecked = false;
  bool _showMaintenance = false;
  MaintenanceConfig? _maintenanceConfig;

  @override
  void initState() {
    super.initState();
    _checkAppConfig();
  }

  Future<void> _checkAppConfig() async {
    final asyncConfig = ref.read(appConfigProvider);

    asyncConfig.when(
      data: (config) {
        if (config != null) {
          _handleConfig(config);
        }
        setState(() => _hasChecked = true);
      },
      loading: () {},
      error: (_, __) {
        setState(() => _hasChecked = true);
      },
    );
  }

  void _handleConfig(AppConfigResponse config) {
    // メンテナンスモードチェック
    if (config.maintenance.enabled) {
      setState(() {
        _showMaintenance = true;
        _maintenanceConfig = config.maintenance;
      });
      return;
    }

    // 強制アップデートチェック
    if (AppConfigService.requiresForceUpdate(
      widget.currentVersion,
      config.version,
    )) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ForceUpdateDialog.show(
            context,
            versionConfig: config.version,
            dismissible: false,
          );
        }
      });
      return;
    }

    // 新しいバージョンがあるが強制ではない場合
    if (AppConfigService.compareVersions(
          widget.currentVersion,
          config.version.latestVersion,
        ) <
        0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ForceUpdateDialog.show(
            context,
            versionConfig: config.version,
            dismissible: true,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // メンテナンスモード
    if (_showMaintenance && _maintenanceConfig != null) {
      return MaintenanceScreen(
        maintenanceConfig: _maintenanceConfig!,
        onRefresh: () {
          setState(() {
            _showMaintenance = false;
            _maintenanceConfig = null;
            _hasChecked = false;
          });
          ref.invalidate(appConfigProvider);
          _checkAppConfig();
        },
      );
    }

    // 設定チェック中はローディング表示
    final asyncConfig = ref.watch(appConfigProvider);

    return asyncConfig.when(
      data: (config) {
        if (config != null && !_hasChecked) {
          _handleConfig(config);
          _hasChecked = true;
        }
        return widget.child;
      },
      loading: () => const _LoadingScreen(),
      error: (_, __) => widget.child, // エラー時は通常画面を表示
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // アプリロゴ（ドット絵風）
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: _buildPixelLogo(context),
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '読み込み中...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPixelLogo(BuildContext context) {
    final theme = Theme.of(context);

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      children: List.generate(16, (index) {
        // 簡単なパターン
        final row = index ~/ 4;
        final col = index % 4;
        final isColored = (row == 0 || row == 3) ||
            (col == 0 || col == 3) ||
            (row == 1 && col == 1) ||
            (row == 2 && col == 2);

        return Container(
          decoration: BoxDecoration(
            color: isColored
                ? theme.colorScheme.primary
                : theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}

/// アプリ設定チェッカーをラップするExtension
extension AppConfigCheckerExtension on Widget {
  Widget withAppConfigChecker({required String currentVersion}) {
    return AppConfigChecker(
      currentVersion: currentVersion,
      child: this,
    );
  }
}
