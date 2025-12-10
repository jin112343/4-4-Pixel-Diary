import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/post.dart';
import '../../../domain/repositories/post_repository.dart';
import 'timeline_view_model.dart';
import 'widgets/post_card.dart';

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
    );
  }

  Widget _buildBody(TimelineState state) {
    if (state.isLoading && state.posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.posts.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref
            .read(timelineViewModelProvider.notifier)
            .loadTimeline(refresh: true);
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: state.posts.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.posts.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final post = state.posts[index];
          return PostCard(
            post: post,
            onLike: () {
              ref.read(timelineViewModelProvider.notifier).toggleLike(post.id);
            },
            onReport: () {
              _showReportDialog(post);
            },
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
                (reason) => RadioListTile<String>(
                  title: Text(reason),
                  value: reason,
                  groupValue: selectedReason,
                  onChanged: (value) {
                    setState(() => selectedReason = value);
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
}
