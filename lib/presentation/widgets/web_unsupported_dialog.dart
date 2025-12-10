import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Web非対応機能のダイアログ
///
/// Bluetooth交換やローカル通知など、Webでは利用できない機能に
/// アクセスしようとした際に表示するダイアログ。
class WebUnsupportedDialog extends StatelessWidget {
  const WebUnsupportedDialog({
    super.key,
    required this.featureName,
    this.description,
    this.iconData,
  });

  /// 機能名（例: 「すれ違い通信」「プッシュ通知」）
  final String featureName;

  /// 追加の説明文（オプション）
  final String? description;

  /// アイコン（オプション、デフォルトはスマートフォンアイコン）
  final IconData? iconData;

  /// ダイアログを表示するヘルパーメソッド
  static Future<void> show(
    BuildContext context, {
    required String featureName,
    String? description,
    IconData? iconData,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => WebUnsupportedDialog(
        featureName: featureName,
        description: description,
        iconData: iconData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // アイコン
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData ?? Icons.phone_android,
                size: 40,
                color: AppColors.warning,
              ),
            ),

            const SizedBox(height: 20),

            // タイトル
            Text(
              'アプリでご利用ください',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            // 説明文
            Text(
              '「$featureName」はWebブラウザでは\nご利用いただけません。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                height: 1.5,
              ),
            ),

            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ストアへの案内
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceDark
                    : AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.download_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'アプリをダウンロード',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'App Store / Google Play',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 閉じるボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('とじる'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Web非対応機能の全画面表示ビュー
///
/// ページ全体をこのウィジェットに置き換える場合に使用
class WebUnsupportedView extends StatelessWidget {
  const WebUnsupportedView({
    super.key,
    required this.featureName,
    this.description,
    this.iconData,
  });

  final String featureName;
  final String? description;
  final IconData? iconData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // アイコン
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData ?? Icons.phone_android,
                size: 56,
                color: AppColors.warning,
              ),
            ),

            const SizedBox(height: 24),

            // タイトル
            Text(
              'アプリでご利用ください',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            // 説明文
            Text(
              '「$featureName」はWebブラウザでは\nご利用いただけません。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                height: 1.5,
              ),
            ),

            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ),
            ],

            const SizedBox(height: 32),

            // ストアへの案内
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceDark
                    : AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.download_rounded,
                    color: AppColors.primary,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'アプリをダウンロード',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'App Store / Google Play',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
