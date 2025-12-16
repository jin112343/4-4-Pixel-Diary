import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_router.dart';
import '../../../providers/app_providers.dart';
import '../album/album_view_model.dart';
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

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
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
                Expanded(flex: 3, child: Center(child: PixelCanvas())),

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
      ),
    );
  }

  /// 状態変化を監視
  void _listenToState(BuildContext context, WidgetRef ref) {
    ref.listen<HomeState>(homeViewModelProvider, (previous, next) {
      // NGワードエラー時にダイアログ表示
      if (next.titleError != null &&
          previous?.titleError != next.titleError) {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('エラー'),
              ],
            ),
            content: Text(next.titleError!),
            actions: [
              TextButton(
                onPressed: () {
                  // タイトルをクリアしてダイアログを閉じる
                  ref.read(homeViewModelProvider.notifier).setTitle('');
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      // エラーメッセージ表示（ネットワークエラー、サーバーエラー等）
      if (next.errorMessage != null &&
          previous?.errorMessage != next.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: '閉じる',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
        // エラーメッセージをクリア
        ref.read(homeViewModelProvider.notifier).clearError();
      }

      // 受信アート表示
      if (next.receivedArt != null &&
          previous?.receivedArt != next.receivedArt) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => ReceivedArtDialog(
            pixelArt: next.receivedArt!,
            onDismiss: () async {
              ref.read(homeViewModelProvider.notifier).clearReceivedArt();
              Navigator.of(dialogContext).pop();

              // アルバムを更新
              final userIdAsync = ref.read(currentUserIdProvider);
              userIdAsync.whenData((userId) {
                ref
                    .read(albumViewModelProvider(userId).notifier)
                    .loadAlbum(refresh: true);
              });
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
class _TitleInput extends ConsumerStatefulWidget {
  const _TitleInput();

  @override
  ConsumerState<_TitleInput> createState() => _TitleInputState();
}

class _TitleInputState extends ConsumerState<_TitleInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final title = ref.read(homeViewModelProvider).title;
    _controller = TextEditingController(text: title);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // タイトル変更を監視してコントローラーを更新
    ref.listen<String>(homeViewModelProvider.select((state) => state.title), (
      previous,
      next,
    ) {
      if (_controller.text != next) {
        _controller.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
    });

    // タイトルエラーを監視
    final titleError = ref.watch(
      homeViewModelProvider.select((state) => state.titleError),
    );

    return TextField(
      maxLength: AppConstants.maxTitleLength,
      decoration: InputDecoration(
        labelText: 'タイトル（5文字まで）',
        hintText: 'なにをかいた？',
        counterText: '',
        errorText: titleError,
        errorStyle: const TextStyle(fontSize: 12),
      ),
      onChanged: (value) {
        ref.read(homeViewModelProvider.notifier).setTitle(value);
      },
      controller: _controller,
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
    final titleError = ref.watch(
      homeViewModelProvider.select((state) => state.titleError),
    );
    final exchangeCount = ref.watch(exchangeCountProvider);

    // NGワードエラーがある場合はボタンを無効化
    final isDisabled = isExchanging || titleError != null;

    // 次の交換で広告を表示するかどうか（3回に1回: 3, 6, 9...回目）
    final willShowAd = (exchangeCount + 1) % 3 == 0;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isDisabled
            ? null
            : () => _onExchangePressed(context, ref, willShowAd),
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
            : Text(
                titleError != null ? '使用できない表現があります' : 'こうかんする',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  /// 交換ボタン押下時の処理
  Future<void> _onExchangePressed(
    BuildContext context,
    WidgetRef ref,
    bool willShowAd,
  ) async {
    // 交換回数をインクリメント
    await ref.read(exchangeCountProvider.notifier).increment();

    if (willShowAd) {
      // 3回に1回広告を表示
      final adService = ref.read(adServiceProvider);
      final adShown = await adService.showRewardedAd(
        onRewarded: () {
          // 広告視聴完了後に交換を実行
          ref.read(homeViewModelProvider.notifier).exchange();
        },
        onAdDismissed: () {
          // 広告が閉じられた（視聴完了はonRewardedで処理済み）
        },
      );

      // 広告が表示できなかった場合はそのまま交換を実行
      if (!adShown) {
        ref.read(homeViewModelProvider.notifier).exchange();
      }
    } else {
      // 広告なしで交換を実行
      ref.read(homeViewModelProvider.notifier).exchange();
    }
  }
}
