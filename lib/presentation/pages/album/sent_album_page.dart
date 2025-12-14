import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/color_constants.dart';
import '../../../domain/entities/pixel_art.dart';
import 'album_view_model.dart';
import 'sent_album_view_model.dart';

/// おくったアルバム画面
class SentAlbumPage extends ConsumerWidget {
  const SentAlbumPage({super.key});

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
      data: (userId) => _SentAlbumContent(userId: userId),
    );
  }
}

/// おくったアルバムコンテンツ
class _SentAlbumContent extends ConsumerWidget {
  const _SentAlbumContent({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sentAlbumViewModelProvider(userId));
    final notifier = ref.read(sentAlbumViewModelProvider(userId).notifier);

    // エラー監視
    ref.listen<SentAlbumState>(sentAlbumViewModelProvider(userId), (
      previous,
      next,
    ) {
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
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: state.isSelectionMode
            ? Text('${state.selectedIds.length}件選択中')
            : const Text('おくったアルバム'),
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
                PopupMenuButton<SentAlbumSortOrder>(
                  icon: const Icon(Icons.sort),
                  tooltip: 'ソート',
                  onSelected: (order) => notifier.setSortOrder(order),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: SentAlbumSortOrder.newest,
                      child: Row(
                        children: [
                          if (state.sortOrder == SentAlbumSortOrder.newest)
                            const Icon(Icons.check, size: 18),
                          const SizedBox(width: 8),
                          const Text('新しい順'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: SentAlbumSortOrder.oldest,
                      child: Row(
                        children: [
                          if (state.sortOrder == SentAlbumSortOrder.oldest)
                            const Icon(Icons.check, size: 18),
                          const SizedBox(width: 8),
                          const Text('古い順'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
      ),
      body: RefreshIndicator(
        onRefresh: () => notifier.loadAlbum(refresh: true),
        child: state.pixelArts.isEmpty && !state.isLoading
            ? const _EmptyState()
            : _SentAlbumGrid(userId: userId, state: state),
      ),
    );
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    WidgetRef ref,
    SentAlbumState state,
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
                  .read(sentAlbumViewModelProvider(userId).notifier)
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
            Icons.send_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'まだおくったドット絵がありません',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '「こうかんする」でドット絵を送ると\nここに保存されます',
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

/// おくったアルバムグリッド
class _SentAlbumGrid extends ConsumerWidget {
  const _SentAlbumGrid({
    required this.userId,
    required this.state,
  });

  final String userId;
  final SentAlbumState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(sentAlbumViewModelProvider(userId).notifier);

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
          // ローディングインジケーター
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

          return _SentAlbumItem(
            pixelArt: pixelArt,
            isSelectionMode: state.isSelectionMode,
            isSelected: isSelected,
            onTap: () {
              if (state.isSelectionMode) {
                notifier.toggleSelection(pixelArt.id);
              } else {
                _showDetailDialog(context, pixelArt);
              }
            },
            onLongPress: () {
              if (!state.isSelectionMode) {
                notifier.startSelectionMode();
                notifier.toggleSelection(pixelArt.id);
              }
            },
          );
        },
      ),
    );
  }

  void _showDetailDialog(BuildContext context, PixelArt pixelArt) {
    showDialog<void>(
      context: context,
      builder: (context) => _DetailDialog(pixelArt: pixelArt),
    );
  }
}

/// おくったアルバムアイテム
class _SentAlbumItem extends StatelessWidget {
  const _SentAlbumItem({
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
class _DetailDialog extends StatelessWidget {
  const _DetailDialog({required this.pixelArt});

  final PixelArt pixelArt;

  @override
  Widget build(BuildContext context) {
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

            const SizedBox(height: 16),

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
    return '${date.year}/${date.month}/${date.day} '
        '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
