import 'package:fpdart/fpdart.dart';

import '../../core/errors/failures.dart';
import '../entities/comment.dart';
import '../entities/post.dart';

/// 投稿の並び順
enum PostSortOrder {
  /// 新着順
  newest,

  /// 人気順
  popular,
}

/// 投稿リポジトリインターフェース
abstract class PostRepository {
  /// タイムラインを取得
  Future<Either<Failure, List<Post>>> getTimeline({
    PostSortOrder sortOrder = PostSortOrder.newest,
    int page = 1,
    int limit = 20,
  });

  /// 自分の投稿を取得
  Future<Either<Failure, List<Post>>> getMyPosts({
    int page = 1,
    int limit = 20,
  });

  /// 投稿を作成
  Future<Either<Failure, Post>> createPost({
    required String pixelArtId,
    required List<int> pixels,
    required String title,
    required int gridSize,
    String? nickname,
    required PostVisibility visibility,
  });

  /// 投稿を削除
  Future<Either<Failure, void>> deletePost(String postId);

  /// いいねする
  Future<Either<Failure, void>> like(String postId);

  /// いいねを取り消す
  Future<Either<Failure, void>> unlike(String postId);

  /// 投稿を通報
  Future<Either<Failure, void>> reportPost({
    required String postId,
    required String reason,
  });

  /// コメント一覧を取得
  Future<Either<Failure, List<Comment>>> getComments(String postId);

  /// コメントを追加
  Future<Either<Failure, Comment>> addComment({
    required String postId,
    required String content,
  });

  /// コメントを削除
  Future<Either<Failure, void>> deleteComment(String commentId);
}
