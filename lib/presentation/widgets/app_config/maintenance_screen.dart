import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/app_config/app_config_service.dart';

/// メンテナンス画面
class MaintenanceScreen extends StatelessWidget {
  final MaintenanceConfig maintenanceConfig;
  final VoidCallback? onRefresh;

  const MaintenanceScreen({
    super.key,
    required this.maintenanceConfig,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // アイコン
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.construction,
                    size: 64,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 32),

                // タイトル
                Text(
                  'メンテナンス中',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // メッセージ
                Text(
                  maintenanceConfig.message.isNotEmpty
                      ? maintenanceConfig.message
                      : '現在メンテナンスを実施しています。\nしばらくお待ちください。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),

                // 終了予定時刻
                if (maintenanceConfig.estimatedEndTime != null)
                  _buildEstimatedEndTime(context),

                const SizedBox(height: 32),

                // 再読み込みボタン
                if (onRefresh != null)
                  OutlinedButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('再読み込み'),
                  ),

                const SizedBox(height: 48),

                // ドット絵アニメーション（装飾）
                _buildPixelArtDecoration(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEstimatedEndTime(BuildContext context) {
    final theme = Theme.of(context);
    final endTime = maintenanceConfig.estimatedEndTime!;
    final formatter = DateFormat('M月d日 HH:mm', 'ja');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            '終了予定: ${formatter.format(endTime.toLocal())}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPixelArtDecoration(BuildContext context) {
    final theme = Theme.of(context);

    // 4x4のドット絵風デコレーション
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            children: List.generate(4, (j) {
              final isColored = (i + j) % 2 == 0;
              return Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: isColored
                      ? theme.colorScheme.primary.withOpacity(0.3)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

/// メンテナンス画面のラッパー（Navigator用）
class MaintenanceRoute extends StatelessWidget {
  final MaintenanceConfig maintenanceConfig;

  const MaintenanceRoute({
    super.key,
    required this.maintenanceConfig,
  });

  @override
  Widget build(BuildContext context) {
    return MaintenanceScreen(
      maintenanceConfig: maintenanceConfig,
      onRefresh: () {
        // アプリを再起動または設定を再取得
        // 実際の実装ではRiverpodのrefを使用してappConfigProviderをrefresh
      },
    );
  }
}
