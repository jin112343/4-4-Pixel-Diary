import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';

/// 通知バッジ付きアイコン
///
/// 通知数をアイコンの右上にバッジとして表示する
class NotificationBadgeIcon extends ConsumerWidget {
  const NotificationBadgeIcon({
    super.key,
    required this.icon,
    this.size,
    this.color,
    this.badgeColor,
    this.badgeTextColor,
    this.showZero = false,
    this.maxCount = 99,
  });

  /// 表示するアイコン
  final IconData icon;

  /// アイコンのサイズ
  final double? size;

  /// アイコンの色
  final Color? color;

  /// バッジの背景色
  final Color? badgeColor;

  /// バッジのテキスト色
  final Color? badgeTextColor;

  /// 0の場合もバッジを表示するか
  final bool showZero;

  /// 最大表示数（これ以上は「99+」のように表示）
  final int maxCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCountAsync = ref.watch(unreadNotificationCountProvider);

    return unreadCountAsync.when(
      data: (count) => _buildIcon(context, count),
      loading: () => _buildIcon(context, 0),
      error: (_, __) => _buildIcon(context, 0),
    );
  }

  Widget _buildIcon(BuildContext context, int count) {
    final theme = Theme.of(context);
    final effectiveBadgeColor = badgeColor ?? theme.colorScheme.error;
    final effectiveBadgeTextColor = badgeTextColor ?? theme.colorScheme.onError;

    if (count == 0 && !showZero) {
      return Icon(
        icon,
        size: size,
        color: color,
      );
    }

    final displayCount = count > maxCount ? '$maxCount+' : count.toString();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          icon,
          size: size,
          color: color,
        ),
        Positioned(
          right: -6,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: effectiveBadgeColor,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(
              minWidth: 16,
              minHeight: 16,
            ),
            child: Text(
              displayCount,
              style: TextStyle(
                color: effectiveBadgeTextColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

/// カスタムバッジウィジェット
///
/// 任意のウィジェットにバッジを付加する
class NotificationBadge extends ConsumerWidget {
  const NotificationBadge({
    super.key,
    required this.child,
    this.badgeColor,
    this.badgeTextColor,
    this.showZero = false,
    this.maxCount = 99,
    this.offset = const Offset(-6, -6),
  });

  /// バッジを付けるウィジェット
  final Widget child;

  /// バッジの背景色
  final Color? badgeColor;

  /// バッジのテキスト色
  final Color? badgeTextColor;

  /// 0の場合もバッジを表示するか
  final bool showZero;

  /// 最大表示数
  final int maxCount;

  /// バッジの位置オフセット
  final Offset offset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCountAsync = ref.watch(unreadNotificationCountProvider);

    return unreadCountAsync.when(
      data: (count) => _buildWithBadge(context, count),
      loading: () => _buildWithBadge(context, 0),
      error: (_, __) => _buildWithBadge(context, 0),
    );
  }

  Widget _buildWithBadge(BuildContext context, int count) {
    final theme = Theme.of(context);
    final effectiveBadgeColor = badgeColor ?? theme.colorScheme.error;
    final effectiveBadgeTextColor = badgeTextColor ?? theme.colorScheme.onError;

    if (count == 0 && !showZero) {
      return child;
    }

    final displayCount = count > maxCount ? '$maxCount+' : count.toString();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: offset.dx,
          top: offset.dy,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: effectiveBadgeColor,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(
              minWidth: 16,
              minHeight: 16,
            ),
            child: Text(
              displayCount,
              style: TextStyle(
                color: effectiveBadgeTextColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

/// ドットバッジ（数字なし）
///
/// 通知がある場合にドットだけを表示する
class NotificationDotBadge extends ConsumerWidget {
  const NotificationDotBadge({
    super.key,
    required this.child,
    this.dotColor,
    this.dotSize = 8,
    this.offset = const Offset(-2, -2),
  });

  /// バッジを付けるウィジェット
  final Widget child;

  /// ドットの色
  final Color? dotColor;

  /// ドットのサイズ
  final double dotSize;

  /// ドットの位置オフセット
  final Offset offset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCountAsync = ref.watch(unreadNotificationCountProvider);

    return unreadCountAsync.when(
      data: (count) => _buildWithDot(context, count > 0),
      loading: () => child,
      error: (_, __) => child,
    );
  }

  Widget _buildWithDot(BuildContext context, bool showDot) {
    final theme = Theme.of(context);
    final effectiveDotColor = dotColor ?? theme.colorScheme.error;

    if (!showDot) {
      return child;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: offset.dx,
          top: offset.dy,
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: effectiveDotColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}
