import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/color_constants.dart';
import '../../../core/routes/app_router.dart';
import '../../../domain/entities/pixel_art.dart';
import '../../../domain/entities/post.dart';
import '../../../providers/app_providers.dart';
import 'album_view_model.dart';

/// アルバム画面
class AlbumPage extends ConsumerWidget {
  const AlbumPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userIdAsync = ref.watch(currentUserIdProvider);

    return userIdAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('エラー: $error')),
      ),
      data: (userId) => _AlbumContent(userId: userId),
    );
  }
}

/// アルバムコンテンツ
class _AlbumContent extends ConsumerWidget {
  const _AlbumContent({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(albumViewModelProvider(userId));
    final notifier = ref.read(albumViewModelProvider(userId).notifier);

    // エラー監視
    ref.listen<AlbumState>(albumViewModelProvider(userId), (previous, next) {
      if (next.errorMessage != null &&
          previous?.errorMessage != next.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
        notifier.clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: state.isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => notifier.endSelectionMode(),
              )
            : null,
        title: state.isSelectionMode
            ? Text('${state.selectedIds.length}件選択中')
            : const Text('アルバム'),
        actions: state.isSelectionMode
            ? [
                // 全選択/全解除
                IconButton(
                  icon: Icon(
                    state.selectedIds.length == state.pixelArts.length
                        ? Icons.deselect
                        : Icons.select_all,
                  ),
                  tooltip: state.selectedIds.length == state.pixelArts.length
                      ? '全て解除'
                      : '全て選択',
                  onPressed: () {
                    if (state.selectedIds.length == state.pixelArts.length) {
                      notifier.deselectAll();
                    } else {
                      notifier.selectAll();
                    }
                  },
                ),
                // 削除ボタン
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: '削除',
                  onPressed: state.selectedIds.isEmpty
                      ? null
                      : () => _showDeleteConfirmDialog(context, ref, state),
                ),
              ]
            : [
                // 選択モード開始
                IconButton(
                  icon: const Icon(Icons.checklist),
                  tooltip: '選択',
                  onPressed: state.pixelArts.isEmpty
                      ? null
                      : () => notifier.startSelectionMode(),
                ),
                // ソートボタン
                PopupMenuButton<AlbumSortOrder>(
                  icon: const Icon(Icons.sort),
                  tooltip: 'ソート',
                  onSelected: (order) => notifier.setSortOrder(order),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: AlbumSortOrder.newest,
                      child: Row(
                        children: [
                          if (state.sortOrder == AlbumSortOrder.newest)
                            const Icon(Icons.check, size: 18),
                          const SizedBox(width: 8),
                          const Text('新しい順'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: AlbumSortOrder.oldest,
                      child: Row(
                        children: [
                          if (state.sortOrder == AlbumSortOrder.oldest)
                            const Icon(Icons.check, size: 18),
                          const SizedBox(width: 8),
                          const Text('古い順'),
                        ],
                      ),
                    ),
                  ],
                ),
                // カレンダーフィルター
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  tooltip: 'カレンダー',
                  onPressed: () => context.push(AppRoutes.calendar),
                ),
              ],
      ),
      body: RefreshIndicator(
        onRefresh: () => notifier.loadAlbum(refresh: true),
        child: state.pixelArts.isEmpty && !state.isLoading
            ? const _EmptyState()
            : _AlbumGrid(userId: userId, state: state),
      ),
    );
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    WidgetRef ref,
    AlbumState state,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('${state.selectedIds.length}件のドット絵を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(albumViewModelProvider(userId).notifier)
                  .deleteSelectedPixelArts();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}

/// 空の状態
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_album_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'まだ届いたドット絵がありません',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '「こうかんする」で交換したり\n「すれちがい」で受け取ると\nここに保存されます',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

/// アルバムグリッド
class _AlbumGrid extends ConsumerWidget {
  const _AlbumGrid({
    required this.userId,
    required this.state,
  });

  final String userId;
  final AlbumState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(albumViewModelProvider(userId).notifier);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 100) {
          notifier.loadMore();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: state.pixelArts.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.pixelArts.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final pixelArt = state.pixelArts[index];
          final isSelected = state.selectedIds.contains(pixelArt.id);

          return _AlbumItem(
            pixelArt: pixelArt,
            isSelectionMode: state.isSelectionMode,
            isSelected: isSelected,
            onTap: () {
              if (state.isSelectionMode) {
                notifier.toggleSelection(pixelArt.id);
              } else {
                _showDetailDialog(context, ref, pixelArt);
              }
            },
            onLongPress: () {
              if (!state.isSelectionMode) {
                // 長押しで選択モードに入り、この項目を選択
                notifier.startSelectionMode();
                notifier.toggleSelection(pixelArt.id);
              }
            },
          );
        },
      ),
    );
  }

  void _showDetailDialog(
    BuildContext context,
    WidgetRef ref,
    PixelArt pixelArt,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => _DetailDialog(
        pixelArt: pixelArt,
        userId: userId,
      ),
    );
  }
}

/// アルバムアイテム
class _AlbumItem extends StatelessWidget {
  const _AlbumItem({
    required this.pixelArt,
    required this.onTap,
    required this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  final PixelArt pixelArt;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isSelectionMode;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ピクセルアート表示
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : ColorConstants.gridLineColor,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: pixelArt.gridSize,
                      ),
                      itemCount: pixelArt.pixels.length,
                      itemBuilder: (context, index) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Color(pixelArt.pixels[index] | 0xFF000000),
                            border: Border.all(
                              color: ColorConstants.gridLineColor,
                              width: 0.25,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // タイトルと日付
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (pixelArt.title.isNotEmpty)
                        Text(
                          pixelArt.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        _formatDate(pixelArt.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 選択モード時のチェックマーク
            if (isSelectionMode)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    isSelected ? Icons.check : null,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}

/// 詳細ダイアログ
class _DetailDialog extends ConsumerWidget {
  const _DetailDialog({
    required this.pixelArt,
    required this.userId,
  });

  final PixelArt pixelArt;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ピクセルアート拡大表示
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: ColorConstants.gridLineColor,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: pixelArt.gridSize,
                  ),
                  itemCount: pixelArt.pixels.length,
                  itemBuilder: (context, index) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Color(pixelArt.pixels[index] | 0xFF000000),
                        border: Border.all(
                          color: ColorConstants.gridLineColor,
                          width: 0.5,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // タイトル
            if (pixelArt.title.isNotEmpty)
              Text(
                pixelArt.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),

            const SizedBox(height: 8),

            // 日付
            Text(
              _formatDateTime(pixelArt.createdAt),
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),

            // ソース表示
            if (pixelArt.source != PixelArtSource.local)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Chip(
                  label: Text(_getSourceLabel(pixelArt.source)),
                  avatar: Icon(
                    _getSourceIcon(pixelArt.source),
                    size: 18,
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // 投稿ボタン（交換で受け取ったものは投稿可能）
            if (pixelArt.source != PixelArtSource.local)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showPostDialog(context, ref),
                    icon: const Icon(Icons.send),
                    label: const Text('タイムラインに投稿'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),

            // 閉じるボタン
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('とじる'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}/${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getSourceLabel(PixelArtSource source) {
    switch (source) {
      case PixelArtSource.local:
        return '自分';
      case PixelArtSource.server:
        return 'こうかん';
      case PixelArtSource.bluetooth:
        return 'すれちがい';
    }
  }

  IconData _getSourceIcon(PixelArtSource source) {
    switch (source) {
      case PixelArtSource.local:
        return Icons.person;
      case PixelArtSource.server:
        return Icons.swap_horiz;
      case PixelArtSource.bluetooth:
        return Icons.bluetooth;
    }
  }

  /// 投稿確認ダイアログを表示
  void _showPostDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('タイムラインに投稿'),
        content: const Text(
          'このドット絵をタイムラインに投稿しますか？\n'
          '投稿すると他のユーザーが閲覧できます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _createPost(context, ref);
            },
            child: const Text('投稿する'),
          ),
        ],
      ),
    );
  }

  /// 投稿を作成
  Future<void> _createPost(BuildContext context, WidgetRef ref) async {
    final postRepository = ref.read(postRepositoryProvider);

    // ローディング表示
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final result = await postRepository.createPost(
      pixelArtId: pixelArt.id,
      pixels: pixelArt.pixels,
      title: pixelArt.title,
      gridSize: pixelArt.gridSize,
      visibility: PostVisibility.public,
    );

    // ローディング閉じる
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    result.fold(
      (failure) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('投稿に失敗しました: ${failure.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      (post) {
        if (context.mounted) {
          // 詳細ダイアログを閉じる
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('投稿しました！'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
    );
  }
}
