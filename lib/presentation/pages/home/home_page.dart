import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_router.dart';
import 'home_view_model.dart';
import 'widgets/pixel_canvas.dart';
import 'widgets/color_palette.dart';
import 'widgets/received_art_dialog.dart';

/// ホーム画面（ドット絵作成）
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // エラー・受信アート監視
    _listenToState(context, ref);

    return Scaffold(
      appBar: AppBar(
        title: const Text('いまのきぶん'),
        actions: [
          // Undoボタン
          _UndoButton(),
          // Redoボタン
          _RedoButton(),
          // クリアボタン
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _showClearConfirmation(context, ref),
            tooltip: 'クリア',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // キャンバス
              Expanded(
                flex: 3,
                child: Center(
                  child: PixelCanvas(),
                ),
              ),

              SizedBox(height: 16),

              // カラーパレット
              ColorPalette(),

              SizedBox(height: 16),

              // タイトル入力
              _TitleInput(),

              SizedBox(height: 24),

              // 交換ボタン
              _ExchangeButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// 状態変化を監視
  void _listenToState(BuildContext context, WidgetRef ref) {
    ref.listen<HomeState>(homeViewModelProvider, (previous, next) {
      // エラーメッセージ表示
      if (next.errorMessage != null && previous?.errorMessage != next.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
        ref.read(homeViewModelProvider.notifier).clearError();
      }

      // 受信アート表示
      if (next.receivedArt != null && previous?.receivedArt != next.receivedArt) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => ReceivedArtDialog(
            pixelArt: next.receivedArt!,
            onDismiss: () {
              ref.read(homeViewModelProvider.notifier).clearReceivedArt();
              Navigator.of(context).pop();
            },
          ),
        );
      }
    });
  }

  /// クリア確認ダイアログ
  void _showClearConfirmation(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('クリア'),
        content: const Text('キャンバスをクリアしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(homeViewModelProvider.notifier).clearCanvas();
              Navigator.of(context).pop();
            },
            child: const Text('クリア'),
          ),
        ],
      ),
    );
  }
}

/// Undoボタン
class _UndoButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canUndo = ref.watch(
      homeViewModelProvider.select((state) => state.undoHistory.isNotEmpty),
    );

    return IconButton(
      icon: const Icon(Icons.undo),
      onPressed: canUndo
          ? () => ref.read(homeViewModelProvider.notifier).undo()
          : null,
      tooltip: 'もどす',
    );
  }
}

/// Redoボタン
class _RedoButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canRedo = ref.watch(
      homeViewModelProvider.select((state) => state.redoHistory.isNotEmpty),
    );

    return IconButton(
      icon: const Icon(Icons.redo),
      onPressed: canRedo
          ? () => ref.read(homeViewModelProvider.notifier).redo()
          : null,
      tooltip: 'やりなおす',
    );
  }
}

/// タイトル入力
class _TitleInput extends ConsumerWidget {
  const _TitleInput();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = ref.watch(
      homeViewModelProvider.select((state) => state.title),
    );

    return TextField(
      maxLength: AppConstants.maxTitleLength,
      decoration: const InputDecoration(
        labelText: 'タイトル（5文字まで）',
        hintText: 'なにをかいた？',
        counterText: '',
      ),
      onChanged: (value) {
        ref.read(homeViewModelProvider.notifier).setTitle(value);
      },
      controller: TextEditingController(text: title)
        ..selection = TextSelection.collapsed(offset: title.length),
    );
  }
}

/// 交換ボタン
class _ExchangeButton extends ConsumerWidget {
  const _ExchangeButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExchanging = ref.watch(
      homeViewModelProvider.select((state) => state.isExchanging),
    );

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isExchanging
            ? null
            : () => ref.read(homeViewModelProvider.notifier).exchange(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
        child: isExchanging
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'こうかんする',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
