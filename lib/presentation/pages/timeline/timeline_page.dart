import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/color_constants.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/sanitizer.dart';
import '../../../domain/entities/post.dart';
import '../../../domain/repositories/post_repository.dart';
import '../../../services/ad/ad_service.dart';
import 'timeline_view_model.dart';
import 'widgets/pixel_art_display.dart';

/// タイムライン画面
class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({super.key});

  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<TimelinePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(timelineViewModelProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(timelineViewModelProvider);

    // エラーメッセージを表示
    ref.listen<TimelineState>(
      timelineViewModelProvider,
      (previous, next) {
        if (next.errorMessage != null && previous?.errorMessage == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.errorMessage!),
              action: SnackBarAction(
                label: '閉じる',
                onPressed: () {
                  ref.read(timelineViewModelProvider.notifier).clearError();
                },
              ),
            ),
          );
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('みんなの作品'),
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            ref.read(timelineViewModelProvider.notifier).setSortOrder(
                  index == 0 ? PostSortOrder.newest : PostSortOrder.popular,
                );
          },
          tabs: const [
            Tab(text: '新着'),
            Tab(text: 'おすすめ'),
          ],
        ),
      ),
      body: _buildBody(state),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPostSourceDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  /// 投稿元選択ダイアログを表示
  void _showPostSourceDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.send),
              title: const Text('おくったアルバムから選ぶ'),
              subtitle: const Text('自分で作ったドット絵を投稿'),
              onTap: () {
                Navigator.of(context).pop();
                context.push(
                  AppRoutes.sentAlbum,
                  extra: {'selectMode': true},
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_album),
              title: const Text('もらったアルバムから選ぶ'),
              subtitle: const Text('交換で受け取ったドット絵を投稿'),
              onTap: () {
                Navigator.of(context).pop();
                context.push(
                  AppRoutes.album,
                  extra: {'selectMode': true},
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 広告の数を計算
  int _getAdCount(int postCount) {
    if (postCount == 0) return 0;
    return (postCount + 2) ~/ 3;
  }

  /// 総表示アイテム数を計算
  int _getTotalDisplayCount(int postCount) {
    return postCount + _getAdCount(postCount);
  }

  /// 表示位置が広告かどうかを判定
  /// 位置1, 4, 7, 10... が広告
  bool _isAdPosition(int displayIndex) {
    return displayIndex > 0 && (displayIndex - 1) % 3 == 0;
  }

  /// 表示位置から投稿インデックスを計算
  int _getPostIndex(int displayIndex) {
    return displayIndex - (displayIndex + 1) ~/ 3;
  }

  Widget _buildBody(TimelineState state) {
    if (state.isLoading && state.posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.posts.isEmpty) {
      return _buildEmptyState();
    }

    final postCount = state.posts.length;
    final totalDisplayCount = _getTotalDisplayCount(postCount);

    return RefreshIndicator(
      onRefresh: () async {
        await ref
            .read(timelineViewModelProvider.notifier)
            .loadTimeline(refresh: true);
      },
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: totalDisplayCount + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          // ローディングインジケーター
          if (index >= totalDisplayCount) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          // 広告位置の場合
          if (_isAdPosition(index)) {
            return _NativeAdItem(key: ValueKey('ad_$index'));
          }

          // 投稿アイテム
          final postIndex = _getPostIndex(index);
          if (postIndex >= state.posts.length) {
            return const SizedBox.shrink();
          }

          final post = state.posts[postIndex];
          return _TimelineGridItem(
            post: post,
            onTap: () => _showPostDetailDialog(post),
            onLike: () {
              ref.read(timelineViewModelProvider.notifier).toggleLike(post.id);
            },
            onReport: () => _showReportDialog(post),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 64,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'まだ投稿がありません',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ドット絵を作成して投稿してみましょう',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(Post post) {
    String? selectedReason;
    final reasons = [
      '不適切なコンテンツ',
      'スパム・迷惑行為',
      '著作権侵害',
      'その他',
    ];

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('通報'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('通報理由を選択してください'),
              const SizedBox(height: 16),
              ...reasons.map(
                (reason) => ListTile(
                  leading: Icon(
                    selectedReason == reason
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selectedReason == reason
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(reason),
                  onTap: () {
                    setState(() => selectedReason = reason);
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: selectedReason == null
                  ? null
                  : () {
                      ref
                          .read(timelineViewModelProvider.notifier)
                          .reportPost(post.id, selectedReason!);
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('通報を送信しました')),
                      );
                    },
              child: const Text('通報する'),
            ),
          ],
        ),
      ),
    );
  }

  /// 投稿詳細ダイアログを表示
  void _showPostDetailDialog(Post post) {
    showDialog<void>(
      context: context,
      builder: (context) => _PostDetailDialog(
        post: post,
        onLike: () {
          ref.read(timelineViewModelProvider.notifier).toggleLike(post.id);
        },
        onReport: () {
          Navigator.of(context).pop();
          _showReportDialog(post);
        },
      ),
    );
  }
}

/// ネイティブ広告アイテム
class _NativeAdItem extends StatelessWidget {
  const _NativeAdItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: AdService.instance.buildNativeAd(height: 180),
    );
  }
}

/// タイムライングリッドアイテム
class _TimelineGridItem extends StatelessWidget {
  const _TimelineGridItem({
    required this.post,
    required this.onTap,
    required this.onLike,
    required this.onReport,
  });

  final Post post;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    // XSS対策: サニタイズ
    final sanitizedNickname = Sanitizer.sanitizeNicknameForDisplay(
      post.ownerNickname,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: PixelArtDisplay(
                    pixels: post.pixels,
                    gridSize: post.gridSize,
                  ),
                ),
              ),
            ),

            // 情報表示
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.title.isNotEmpty)
                    Text(
                      Sanitizer.sanitizeTitleForDisplay(post.title),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    sanitizedNickname,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // いいねボタン
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: Row(
                children: [
                  InkWell(
                    onTap: onLike,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            post.isLikedByMe
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 16,
                            color: post.isLikedByMe ? Colors.red : Colors.grey,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${post.likeCount}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
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

/// 投稿詳細ダイアログ
class _PostDetailDialog extends StatelessWidget {
  const _PostDetailDialog({
    required this.post,
    required this.onLike,
    required this.onReport,
  });

  final Post post;
  final VoidCallback onLike;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final sanitizedNickname = Sanitizer.sanitizeNicknameForDisplay(
      post.ownerNickname,
    );
    final sanitizedTitle = Sanitizer.sanitizeTitleForDisplay(post.title);

    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ヘッダー
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: Text(
                      sanitizedNickname.characters.first,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sanitizedNickname,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _formatDate(post.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.flag_outlined),
                    onPressed: onReport,
                    tooltip: '通報',
                  ),
                ],
              ),

              const SizedBox(height: 16),

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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: PixelArtDisplay(
                      pixels: post.pixels,
                      gridSize: post.gridSize,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // タイトル
              if (sanitizedTitle.isNotEmpty)
                Text(
                  sanitizedTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),

              const SizedBox(height: 16),

              // いいねボタン
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: onLike,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            post.isLikedByMe
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 28,
                            color: post.isLikedByMe ? Colors.red : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${post.likeCount}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'たった今';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}時間前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}日前';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}
