import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/color_constants.dart';
import '../../../core/routes/app_router.dart';
import '../../../domain/entities/pixel_art.dart';
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
        ref.read(albumViewModelProvider(userId).notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('アルバム'),
        actions: [
          // ソートボタン
          PopupMenuButton<AlbumSortOrder>(
            icon: const Icon(Icons.sort),
            tooltip: 'ソート',
            onSelected: (order) {
              ref
                  .read(albumViewModelProvider(userId).notifier)
                  .setSortOrder(order);
            },
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
        onRefresh: () =>
            ref.read(albumViewModelProvider(userId).notifier).loadAlbum(
                  refresh: true,
                ),
        child: state.pixelArts.isEmpty && !state.isLoading
            ? const _EmptyState()
            : _AlbumGrid(userId: userId, state: state),
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
            'まだドット絵がありません',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '「こうかんする」で送信すると\nここに保存されます',
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
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 100) {
          ref.read(albumViewModelProvider(userId).notifier).loadMore();
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
          return _AlbumItem(
            pixelArt: pixelArt,
            onTap: () => _showDetailDialog(context, ref, pixelArt),
            onLongPress: () => _showDeleteDialog(context, ref, pixelArt),
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
      builder: (context) => _DetailDialog(pixelArt: pixelArt),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    PixelArt pixelArt,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除'),
        content: const Text('このドット絵を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(albumViewModelProvider(userId).notifier)
                  .deletePixelArt(pixelArt.id);
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

/// アルバムアイテム
class _AlbumItem extends StatelessWidget {
  const _AlbumItem({
    required this.pixelArt,
    required this.onTap,
    required this.onLongPress,
  });

  final PixelArt pixelArt;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ピクセルアート表示
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: ColorConstants.gridLineColor,
                    width: 1,
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

            // 閉じるボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
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
}
