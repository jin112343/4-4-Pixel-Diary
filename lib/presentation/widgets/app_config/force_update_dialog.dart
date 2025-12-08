import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/app_config/app_config_service.dart';

/// 強制アップデートダイアログ
class ForceUpdateDialog extends StatelessWidget {
  final VersionConfig versionConfig;
  final VoidCallback? onLater;

  const ForceUpdateDialog({
    super.key,
    required this.versionConfig,
    this.onLater,
  });

  /// ダイアログを表示
  static Future<void> show(
    BuildContext context, {
    required VersionConfig versionConfig,
    bool dismissible = false,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: dismissible,
      builder: (context) => ForceUpdateDialog(
        versionConfig: versionConfig,
        onLater: dismissible ? () => Navigator.of(context).pop() : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isForceUpdate = versionConfig.forceUpdate;

    return PopScope(
      canPop: !isForceUpdate,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.system_update,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              isForceUpdate ? 'アップデートが必要です' : '新しいバージョンがあります',
              style: theme.textTheme.titleLarge,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isForceUpdate
                  ? 'アプリを使用するには最新バージョンへのアップデートが必要です。'
                  : '新しいバージョン（${versionConfig.latestVersion}）が利用可能です。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _buildVersionInfo(context),
          ],
        ),
        actions: [
          if (!isForceUpdate && onLater != null)
            TextButton(
              onPressed: onLater,
              child: const Text('あとで'),
            ),
          FilledButton.icon(
            onPressed: () => _openStore(context),
            icon: const Icon(Icons.download),
            label: const Text('アップデート'),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionInfo(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '最低バージョン',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                versionConfig.minVersion,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '最新バージョン',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                versionConfig.latestVersion,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openStore(BuildContext context) async {
    final storeUrl = Platform.isIOS
        ? versionConfig.storeUrl.ios
        : versionConfig.storeUrl.android;

    if (storeUrl.isEmpty) {
      _showError(context, 'ストアURLが設定されていません');
      return;
    }

    final uri = Uri.parse(storeUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (context.mounted) {
          _showError(context, 'ストアを開けませんでした');
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'ストアを開けませんでした');
      }
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}
