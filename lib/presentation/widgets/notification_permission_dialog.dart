import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../services/notification/notification_service.dart';

/// 通知権限リクエストダイアログ
///
/// OS別の通知許可ダイアログを表示し、権限をリクエストする
class NotificationPermissionDialog extends ConsumerStatefulWidget {
  const NotificationPermissionDialog({
    super.key,
    this.onPermissionGranted,
    this.onPermissionDenied,
  });

  /// 権限が許可された時のコールバック
  final VoidCallback? onPermissionGranted;

  /// 権限が拒否された時のコールバック
  final VoidCallback? onPermissionDenied;

  /// ダイアログを表示
  static Future<bool?> show(
    BuildContext context, {
    VoidCallback? onPermissionGranted,
    VoidCallback? onPermissionDenied,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => NotificationPermissionDialog(
        onPermissionGranted: onPermissionGranted,
        onPermissionDenied: onPermissionDenied,
      ),
    );
  }

  @override
  ConsumerState<NotificationPermissionDialog> createState() =>
      _NotificationPermissionDialogState();
}

class _NotificationPermissionDialogState
    extends ConsumerState<NotificationPermissionDialog> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.notifications_outlined,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          const Text('通知を許可'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'すれ違い通知を受け取るには、通知の許可が必要です。',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            icon: Icons.bluetooth,
            text: '近くのユーザーとすれ違った時',
          ),
          _buildFeatureItem(
            icon: Icons.swap_horiz,
            text: 'ドット絵の交換が完了した時',
          ),
          _buildFeatureItem(
            icon: Icons.favorite_border,
            text: 'いいねやコメントを受け取った時',
          ),
          const SizedBox(height: 16),
          Text(
            Platform.isIOS
                ? '「許可」をタップすると、iOSの通知設定画面が表示されます。'
                : '「許可」をタップすると、Androidの通知許可ダイアログが表示されます。',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : _onSkip,
          child: const Text('あとで'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _onRequestPermission,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('許可する'),
        ),
      ],
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onRequestPermission() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notificationService = ref.read(notificationServiceProvider);
      final status = await notificationService.requestNotificationPermission();

      if (!mounted) return;

      if (status == NotificationPermissionStatus.granted ||
          status == NotificationPermissionStatus.provisional) {
        widget.onPermissionGranted?.call();
        Navigator.of(context).pop(true);
      } else if (status == NotificationPermissionStatus.permanentlyDenied) {
        // 設定画面を開くかどうか確認
        _showSettingsDialog();
      } else {
        widget.onPermissionDenied?.call();
        Navigator.of(context).pop(false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSkip() {
    widget.onPermissionDenied?.call();
    Navigator.of(context).pop(false);
  }

  void _showSettingsDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('通知が無効です'),
        content: const Text(
          '通知を受け取るには、設定アプリから通知を有効にしてください。',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(this.context).pop(false);
            },
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () async {
              final notificationService = ref.read(notificationServiceProvider);
              await notificationService.openNotificationSettings();
              if (mounted) {
                Navigator.of(context).pop();
                Navigator.of(this.context).pop(false);
              }
            },
            child: const Text('設定を開く'),
          ),
        ],
      ),
    );
  }
}

/// 通知権限チェッカー
///
/// アプリ起動時や特定のタイミングで通知権限をチェックし、
/// 必要に応じてダイアログを表示する
class NotificationPermissionChecker {
  NotificationPermissionChecker(this._notificationService);

  final NotificationService _notificationService;

  /// 通知権限をチェックし、未許可の場合はダイアログを表示
  Future<bool> checkAndRequestPermission(BuildContext context) async {
    final status = await _notificationService.getNotificationPermissionStatus();

    if (status == NotificationPermissionStatus.granted ||
        status == NotificationPermissionStatus.provisional) {
      return true;
    }

    if (!context.mounted) return false;

    final result = await NotificationPermissionDialog.show(context);
    return result ?? false;
  }

  /// 権限が許可されているか確認
  Future<bool> isPermissionGranted() async {
    final status = await _notificationService.getNotificationPermissionStatus();
    return status == NotificationPermissionStatus.granted ||
        status == NotificationPermissionStatus.provisional;
  }
}

/// 通知権限チェッカープロバイダー
final notificationPermissionCheckerProvider =
    Provider<NotificationPermissionChecker>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  return NotificationPermissionChecker(notificationService);
});
