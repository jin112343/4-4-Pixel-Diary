import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/utils/logger.dart';
import '../../../domain/entities/comment.dart';
import '../../../domain/entities/post.dart';
import '../../../domain/repositories/post_repository.dart';
import '../../../providers/app_providers.dart';

part 'timeline_view_model.freezed.dart';

/// タイムライン画面の状態
@freezed
class TimelineState with _$TimelineState {
  const factory TimelineState({
    /// 投稿リスト
    @Default([]) List<Post> posts,

    /// ローディング中かどうか
    @Default(false) bool isLoading,

    /// 追加読み込み中かどうか
    @Default(false) bool isLoadingMore,

    /// エラーメッセージ
    String? errorMessage,

    /// ソート順（新着/おすすめ）
    @Default(PostSortOrder.newest) PostSortOrder sortOrder,

    /// 現在のページ
    @Default(1) int currentPage,

    /// さらに読み込み可能か
    @Default(true) bool hasMore,

    /// 選択中の投稿（コメント表示用）
    Post? selectedPost,

    /// コメントリスト
    @Default([]) List<Comment> comments,

    /// コメントローディング中かどうか
    @Default(false) bool isLoadingComments,
  }) = _TimelineState;
}

/// タイムライン画面のViewModel
class TimelineViewModel extends StateNotifier<TimelineState> {
  final PostRepository _postRepository;

  TimelineViewModel(this._postRepository) : super(const TimelineState()) {
    loadTimeline();
  }

  /// タイムラインを読み込む
  Future<void> loadTimeline({bool refresh = false}) async {
    if (state.isLoading) return;

    if (refresh) {
      state = state.copyWith(
        currentPage: 1,
        hasMore: true,
        posts: [],
      );
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final result = await _postRepository.getTimeline(
        sortOrder: state.sortOrder,
        page: state.currentPage,
        limit: 20,
      );

      result.fold(
        (failure) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: failure.message,
          );
          logger.e('Failed to load timeline: ${failure.message}');
        },
        (posts) {
          state = state.copyWith(
            isLoading: false,
            posts: refresh ? posts : [...state.posts, ...posts],
            hasMore: posts.length >= 20,
          );
          logger.i('Timeline loaded: ${posts.length} posts');
        },
      );
    } catch (e, stackTrace) {
      logger.e('Timeline load error', error: e, stackTrace: stackTrace);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'タイムラインの読み込みに失敗しました',
      );
    }
  }

  /// さらに読み込む（無限スクロール）
  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(
      isLoadingMore: true,
      currentPage: state.currentPage + 1,
    );

    try {
      final result = await _postRepository.getTimeline(
        sortOrder: state.sortOrder,
        page: state.currentPage,
        limit: 20,
      );

      result.fold(
        (failure) {
          state = state.copyWith(
            isLoadingMore: false,
            errorMessage: failure.message,
            currentPage: state.currentPage - 1,
          );
        },
        (posts) {
          state = state.copyWith(
            isLoadingMore: false,
            posts: [...state.posts, ...posts],
            hasMore: posts.length >= 20,
          );
        },
      );
    } catch (e, stackTrace) {
      logger.e('Load more error', error: e, stackTrace: stackTrace);
      state = state.copyWith(
        isLoadingMore: false,
        currentPage: state.currentPage - 1,
      );
    }
  }

  /// ソート順を変更
  void setSortOrder(PostSortOrder order) {
    if (state.sortOrder == order) return;

    state = state.copyWith(sortOrder: order);
    loadTimeline(refresh: true);
  }

  /// いいねする/取り消す
  Future<void> toggleLike(String postId) async {
    final postIndex = state.posts.indexWhere((p) => p.id == postId);
    if (postIndex == -1) return;

    final post = state.posts[postIndex];
    final isLiked = post.isLikedByMe;

    // 楽観的更新
    final updatedPost = post.copyWith(
      isLikedByMe: !isLiked,
      likeCount: isLiked ? post.likeCount - 1 : post.likeCount + 1,
    );
    final updatedPosts = List<Post>.from(state.posts);
    updatedPosts[postIndex] = updatedPost;
    state = state.copyWith(posts: updatedPosts);

    try {
      final result = isLiked
          ? await _postRepository.unlike(postId)
          : await _postRepository.like(postId);

      result.fold(
        (failure) {
          // 失敗時は元に戻す
          final revertedPosts = List<Post>.from(state.posts);
          revertedPosts[postIndex] = post;
          state = state.copyWith(
            posts: revertedPosts,
            errorMessage: failure.message,
          );
        },
        (_) {
          logger.i('Like toggled for post: $postId');
        },
      );
    } catch (e, stackTrace) {
      logger.e('Toggle like error', error: e, stackTrace: stackTrace);
      // 失敗時は元に戻す
      final revertedPosts = List<Post>.from(state.posts);
      revertedPosts[postIndex] = post;
      state = state.copyWith(posts: revertedPosts);
    }
  }

  /// コメントを読み込む
  Future<void> loadComments(Post post) async {
    state = state.copyWith(
      selectedPost: post,
      isLoadingComments: true,
      comments: [],
    );

    try {
      final result = await _postRepository.getComments(postId: post.id);

      result.fold(
        (failure) {
          state = state.copyWith(
            isLoadingComments: false,
            errorMessage: failure.message,
          );
        },
        (comments) {
          state = state.copyWith(
            isLoadingComments: false,
            comments: comments,
          );
        },
      );
    } catch (e, stackTrace) {
      logger.e('Load comments error', error: e, stackTrace: stackTrace);
      state = state.copyWith(
        isLoadingComments: false,
        errorMessage: 'コメントの読み込みに失敗しました',
      );
    }
  }

  /// コメントを追加
  Future<bool> addComment(String content) async {
    final post = state.selectedPost;
    if (post == null) return false;

    try {
      final result = await _postRepository.addComment(
        postId: post.id,
        content: content,
      );

      return result.fold(
        (failure) {
          state = state.copyWith(errorMessage: failure.message);
          return false;
        },
        (comment) {
          // コメントリストに追加
          state = state.copyWith(
            comments: [...state.comments, comment],
          );

          // 投稿のコメント数を更新
          final postIndex = state.posts.indexWhere((p) => p.id == post.id);
          if (postIndex != -1) {
            final updatedPost = state.posts[postIndex].copyWith(
              commentCount: state.posts[postIndex].commentCount + 1,
            );
            final updatedPosts = List<Post>.from(state.posts);
            updatedPosts[postIndex] = updatedPost;
            state = state.copyWith(
              posts: updatedPosts,
              selectedPost: updatedPost,
            );
          }

          logger.i('Comment added to post: ${post.id}');
          return true;
        },
      );
    } catch (e, stackTrace) {
      logger.e('Add comment error', error: e, stackTrace: stackTrace);
      state = state.copyWith(errorMessage: 'コメントの投稿に失敗しました');
      return false;
    }
  }

  /// コメントを削除
  Future<void> deleteComment(String commentId) async {
    try {
      final result = await _postRepository.deleteComment(commentId);

      result.fold(
        (failure) {
          state = state.copyWith(errorMessage: failure.message);
        },
        (_) {
          // コメントリストから削除
          state = state.copyWith(
            comments: state.comments.where((c) => c.id != commentId).toList(),
          );

          // 投稿のコメント数を更新
          if (state.selectedPost != null) {
            final postIndex = state.posts.indexWhere(
              (p) => p.id == state.selectedPost!.id,
            );
            if (postIndex != -1) {
              final updatedPost = state.posts[postIndex].copyWith(
                commentCount: state.posts[postIndex].commentCount - 1,
              );
              final updatedPosts = List<Post>.from(state.posts);
              updatedPosts[postIndex] = updatedPost;
              state = state.copyWith(
                posts: updatedPosts,
                selectedPost: updatedPost,
              );
            }
          }

          logger.i('Comment deleted: $commentId');
        },
      );
    } catch (e, stackTrace) {
      logger.e('Delete comment error', error: e, stackTrace: stackTrace);
      state = state.copyWith(errorMessage: 'コメントの削除に失敗しました');
    }
  }

  /// 投稿を通報
  Future<void> reportPost(String postId, String reason) async {
    try {
      final result = await _postRepository.reportPost(
        postId: postId,
        reason: reason,
      );

      result.fold(
        (failure) {
          state = state.copyWith(errorMessage: failure.message);
        },
        (_) {
          logger.i('Post reported: $postId');
        },
      );
    } catch (e, stackTrace) {
      logger.e('Report post error', error: e, stackTrace: stackTrace);
      state = state.copyWith(errorMessage: '通報に失敗しました');
    }
  }

  /// コメント画面を閉じる
  void closeComments() {
    state = state.copyWith(
      selectedPost: null,
      comments: [],
    );
  }

  /// エラーをクリア
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

/// タイムラインViewModelプロバイダー
final timelineViewModelProvider =
    StateNotifierProvider<TimelineViewModel, TimelineState>(
  (ref) {
    final postRepository = ref.watch(postRepositoryProvider);
    return TimelineViewModel(postRepository);
  },
);
