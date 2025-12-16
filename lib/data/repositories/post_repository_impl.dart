import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/sanitizer.dart';
import '../../domain/entities/comment.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/post_repository.dart';
import '../datasources/remote/api_client.dart';
import '../datasources/remote/api_interceptor.dart';

/// 投稿リポジトリ実装
class PostRepositoryImpl implements PostRepository {
  PostRepositoryImpl({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Either<Failure, List<Post>>> getTimeline({
    PostSortOrder sortOrder = PostSortOrder.newest,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiConstants.postsEndpoint,
        queryParameters: {
          'tab': sortOrder == PostSortOrder.newest ? 'new' : 'popular',
          'limit': limit,
        },
      );

      // サーバーレスポンス形式: { success: bool, data: [...], pagination: { ... } }
      final responseData = response.data as Map<String, dynamic>;

      if (responseData['success'] != true) {
        final error = responseData['error'] as Map<String, dynamic>?;
        return Left(ServerFailure(
          error?['message'] as String? ?? 'タイムラインの取得に失敗しました',
          error?['code'] as String?,
        ));
      }

      final data = responseData['data'];
      if (data is List) {
        final posts = data
            .map((json) => _parsePostFromServer(json as Map<String, dynamic>))
            .toList();

        logger.i('Timeline loaded: ${posts.length} posts');
        return Right(posts);
      }

      return const Right([]);
    } on DioException catch (e) {
      final apiError = ApiError.fromDioException(e);
      logger.e('Failed to get timeline: ${apiError.message}');
      return Left(ServerFailure(apiError.message, apiError.code));
    } catch (e, stackTrace) {
      logger.e('Failed to get timeline', error: e, stackTrace: stackTrace);
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, List<Post>>> getMyPosts({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '${ApiConstants.postsEndpoint}/me',
        queryParameters: {
          'limit': limit,
        },
      );

      // サーバーレスポンス形式: { success: bool, data: [...], pagination: { ... } }
      final responseData = response.data as Map<String, dynamic>;

      if (responseData['success'] != true) {
        final error = responseData['error'] as Map<String, dynamic>?;
        return Left(ServerFailure(
          error?['message'] as String? ?? '自分の投稿の取得に失敗しました',
          error?['code'] as String?,
        ));
      }

      final data = responseData['data'];
      if (data is List) {
        final posts = data
            .map((json) => _parsePostFromServer(json as Map<String, dynamic>))
            .toList();

        return Right(posts);
      }

      return const Right([]);
    } on DioException catch (e) {
      final apiError = ApiError.fromDioException(e);
      logger.e('Failed to get my posts: ${apiError.message}');
      return Left(ServerFailure(apiError.message, apiError.code));
    } catch (e, stackTrace) {
      logger.e('Failed to get my posts', error: e, stackTrace: stackTrace);
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, Post>> createPost({
    required String pixelArtId,
    required List<int> pixels,
    required String title,
    required int gridSize,
    String? nickname,
    required PostVisibility visibility,
  }) async {
    try {
      // ========== 入力バリデーション（セキュリティ強化） ==========

      // pixelArtIdのバリデーション（UUID形式のチェック）
      if (pixelArtId.isEmpty || pixelArtId.length > 100) {
        return const Left(ValidationFailure('無効なピクセルアートIDです'));
      }

      // グリッドサイズのバリデーション
      if (gridSize < 4 || gridSize > 8) {
        return const Left(ValidationFailure('グリッドサイズは4〜8の範囲で指定してください'));
      }

      // ピクセル数のバリデーション
      final expectedPixelCount = gridSize * gridSize;
      if (pixels.length != expectedPixelCount) {
        return Left(ValidationFailure(
          'ピクセル数が不正です（期待: $expectedPixelCount, 実際: ${pixels.length}）',
        ));
      }

      // ピクセル値のバリデーション
      for (final pixel in pixels) {
        if (pixel < 0 || pixel > 0xFFFFFF) {
          return const Left(ValidationFailure('ピクセル値が不正です'));
        }
      }

      // タイトルのサニタイズ
      final sanitizedTitle = Sanitizer.sanitizeUserInput(title, maxLength: 5);

      // ニックネームのサニタイズ
      final sanitizedNickname = nickname != null && nickname.isNotEmpty
          ? Sanitizer.sanitizeUserInput(nickname, maxLength: 5)
          : null;

      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiConstants.postsEndpoint,
        data: {
          'pixelArtId': pixelArtId,
          'pixels': pixels,
          'title': sanitizedTitle,
          'gridSize': gridSize,
          if (sanitizedNickname != null && sanitizedNickname.isNotEmpty)
            'nickname': sanitizedNickname,
          'visibility': visibility == PostVisibility.public
              ? 'public'
              : 'private',
        },
      );

      // サーバーレスポンス形式: { success: bool, data: Post }
      final responseData = response.data as Map<String, dynamic>;

      if (responseData['success'] != true) {
        final error = responseData['error'] as Map<String, dynamic>?;
        return Left(ServerFailure(
          error?['message'] as String? ?? '投稿の作成に失敗しました',
          error?['code'] as String?,
        ));
      }

      final postData = responseData['data'] as Map<String, dynamic>;
      final post = _parsePostFromServer(postData);
      logger.i('Post created: ${post.id}');
      return Right(post);
    } on DioException catch (e) {
      final apiError = ApiError.fromDioException(e);
      logger.e('Failed to create post: ${apiError.message}');
      return Left(ServerFailure(apiError.message, apiError.code));
    } catch (e, stackTrace) {
      logger.e('Failed to create post', error: e, stackTrace: stackTrace);
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, void>> deletePost(String postId) async {
    try {
      await _apiClient.delete<void>('${ApiConstants.postsEndpoint}/$postId');
      logger.i('Post deleted: $postId');
      return const Right(null);
    } on DioException catch (e) {
      final apiError = ApiError.fromDioException(e);
      logger.e('Failed to delete post: ${apiError.message}');
      return Left(ServerFailure(apiError.message, apiError.code));
    } catch (e, stackTrace) {
      logger.e('Failed to delete post', error: e, stackTrace: stackTrace);
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, void>> like(String postId) async {
    try {
      await _apiClient.post<void>(
        '${ApiConstants.postsEndpoint}/$postId/like',
      );
      logger.i('Liked post: $postId');
      return const Right(null);
    } on DioException catch (e) {
      final apiError = ApiError.fromDioException(e);
      logger.e('Failed to like post: ${apiError.message}');
      return Left(ServerFailure(apiError.message, apiError.code));
    } catch (e, stackTrace) {
      logger.e('Failed to like post', error: e, stackTrace: stackTrace);
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, void>> unlike(String postId) async {
    try {
      await _apiClient.delete<void>(
        '${ApiConstants.postsEndpoint}/$postId/like',
      );
      logger.i('Unliked post: $postId');
      return const Right(null);
    } on DioException catch (e) {
      final apiError = ApiError.fromDioException(e);
      logger.e('Failed to unlike post: ${apiError.message}');
      return Left(ServerFailure(apiError.message, apiError.code));
    } catch (e, stackTrace) {
      logger.e('Failed to unlike post', error: e, stackTrace: stackTrace);
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, void>> reportPost({
    required String postId,
    required String reason,
  }) async {
    try {
      // ========== 入力バリデーション ==========

      // postIdのバリデーション
      if (postId.isEmpty || postId.length > 100) {
        return const Left(ValidationFailure('無効な投稿IDです'));
      }

      // 理由のバリデーションとサニタイズ
      if (reason.isEmpty) {
        return const Left(ValidationFailure('通報理由を入力してください'));
      }

      final sanitizedReason = Sanitizer.sanitizeUserInput(reason, maxLength: 200);

      await _apiClient.post<void>(
        '${ApiConstants.postsEndpoint}/$postId/report',
        data: {'reason': sanitizedReason},
      );
      logger.i('Post reported: $postId');
      return const Right(null);
    } on DioException catch (e) {
      final apiError = ApiError.fromDioException(e);
      logger.e('Failed to report post: ${apiError.message}');
      return Left(ServerFailure(apiError.message, apiError.code));
    } catch (e, stackTrace) {
      logger.e('Failed to report post', error: e, stackTrace: stackTrace);
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, List<Comment>>> getComments(String postId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '${ApiConstants.postsEndpoint}/$postId/comments',
      );
      final data = response.data;
      if (data == null) {
        return const Right([]);
      }
      final comments = (data['comments'] as List<dynamic>? ?? [])
          .map((e) => Comment.fromJson(e as Map<String, dynamic>))
          .toList();
      logger.i('Fetched ${comments.length} comments for post: $postId');
      return Right(comments);
    } on DioException catch (e) {
      final apiError = ApiError.fromDioException(e);
      logger.e('Failed to get comments: ${apiError.message}');
      return Left(ServerFailure(apiError.message, apiError.code));
    } catch (e, stackTrace) {
      logger.e('Failed to get comments', error: e, stackTrace: stackTrace);
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, Comment>> addComment({
    required String postId,
    required String content,
  }) async {
    try {
      // ========== 入力バリデーション（セキュリティ強化） ==========

      // postIdのバリデーション
      if (postId.isEmpty || postId.length > 100) {
        return const Left(ValidationFailure('無効な投稿IDです'));
      }

      // コンテンツのバリデーション
      if (content.isEmpty) {
        return const Left(ValidationFailure('コメントを入力してください'));
      }

      // コンテンツのサニタイズ（50文字制限）
      final sanitizedContent = Sanitizer.sanitizeUserInput(content, maxLength: 50);

      if (sanitizedContent.isEmpty) {
        return const Left(ValidationFailure('有効なコメントを入力してください'));
      }

      if (sanitizedContent.length > 50) {
        return const Left(ValidationFailure('コメントは50文字以内で入力してください'));
      }

      final response = await _apiClient.post<Map<String, dynamic>>(
        '${ApiConstants.postsEndpoint}/$postId/comments',
        data: {'content': sanitizedContent},
      );
      final data = response.data;
      if (data == null) {
        return const Left(UnknownFailure());
      }
      final comment = Comment.fromJson(data);
      logger.i('Comment added to post: $postId');
      return Right(comment);
    } on DioException catch (e) {
      final apiError = ApiError.fromDioException(e);
      logger.e('Failed to add comment: ${apiError.message}');
      return Left(ServerFailure(apiError.message, apiError.code));
    } catch (e, stackTrace) {
      logger.e('Failed to add comment', error: e, stackTrace: stackTrace);
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, void>> deleteComment(String commentId) async {
    try {
      await _apiClient.delete<void>(
        '${ApiConstants.commentsEndpoint}/$commentId',
      );
      logger.i('Comment deleted: $commentId');
      return const Right(null);
    } on DioException catch (e) {
      final apiError = ApiError.fromDioException(e);
      logger.e('Failed to delete comment: ${apiError.message}');
      return Left(ServerFailure(apiError.message, apiError.code));
    } catch (e, stackTrace) {
      logger.e('Failed to delete comment', error: e, stackTrace: stackTrace);
      return const Left(UnknownFailure());
    }
  }

  /// サーバーのPostレスポンスをFlutterのエンティティに変換
  Post _parsePostFromServer(Map<String, dynamic> data) {
    return Post(
      id: data['id'] as String,
      pixelArtId: data['pixelArtId'] as String? ?? data['id'] as String,
      pixels: (data['pixels'] as List<dynamic>).map((e) => e as int).toList(),
      title: data['title'] as String? ?? '',
      ownerId: data['userId'] as String,
      ownerNickname: data['nickname'] as String?,
      likeCount: data['likeCount'] as int? ?? 0,
      commentCount: data['commentCount'] as int? ?? 0,
      createdAt: DateTime.parse(data['createdAt'] as String),
      gridSize: data['gridSize'] as int? ?? 4,
    );
  }
}
