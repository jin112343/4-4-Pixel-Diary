import 'package:flutter/material.dart';

/// グローバルローディングオーバーレイ
class LoadingOverlay {
  LoadingOverlay._();

  static OverlayEntry? _overlayEntry;
  static bool _isShowing = false;

  /// ローディングを表示
  static void show(
    BuildContext context, {
    String? message,
    bool barrierDismissible = false,
  }) {
    if (_isShowing) return;

    _isShowing = true;
    _overlayEntry = OverlayEntry(
      builder: (context) => _LoadingOverlayWidget(
        message: message,
        barrierDismissible: barrierDismissible,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// ローディングを非表示
  static void hide() {
    if (!_isShowing) return;

    _overlayEntry?.remove();
    _overlayEntry = null;
    _isShowing = false;
  }

  /// ローディング表示中かどうか
  static bool get isShowing => _isShowing;
}

class _LoadingOverlayWidget extends StatelessWidget {
  const _LoadingOverlayWidget({
    this.message,
    this.barrierDismissible = false,
  });

  final String? message;
  final bool barrierDismissible;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: GestureDetector(
        onTap: barrierDismissible ? LoadingOverlay.hide : null,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                if (message != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    message!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ローディング付きの非同期処理実行ヘルパー
extension LoadingOverlayExtension on BuildContext {
  /// ローディングを表示しながら非同期処理を実行
  Future<T> withLoading<T>(
    Future<T> Function() action, {
    String? message,
  }) async {
    LoadingOverlay.show(this, message: message);
    try {
      return await action();
    } finally {
      LoadingOverlay.hide();
    }
  }
}
