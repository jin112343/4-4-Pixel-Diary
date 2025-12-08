import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/comment.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/post_repository.dart';
import '../datasources/remote/api_client.dart';
import '../datasources/remote/api_interceptor.dart';

/// 投稿リポジトリ実装
class PostRepositoryImpl implements PostRepository {
  final ApiClient _apiClient;

  PostRepositoryImpl({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  @override
  Future<Either<Failure, List<Post>>> getTimeline({
    PostSortOrder sortOrder = PostSortOrder.newest,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.postsEndpoint,
        queryParameters: {
          'sort': sortOrder == PostSortOrder.newest ? 'newest' : 'popular',
          'page': page,
          'limit': limit,
        },
      );

      if (response.data is List) {
        final posts = (response.data as List)
            .map((json) => Post.fromJson(json as Map<String, dynamic>))
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
      final response = await _apiClient.get(
        '${ApiConstants.postsEndpoint}/me',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );

      if (response.data is List) {
        final posts = (response.data as List)
            .map((json) => Post.fromJson(json as Map<String, dynamic>))
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
    required PostVisibility visibility,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.postsEndpoint,
        data: {
          'pixelArtId': pixelArtId,
          'visibility': visibility == PostVisibility.public
              ? 'public'
              : 'private',
        },
      );

      final post = Post.fromJson(response.data as Map<String, dynamic>);
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
      await _apiClient.delete('${ApiConstants.postsEndpoint}/$postId');
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
      await _apiClient.post(
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
      await _apiClient.delete(
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
  Future<Either<Failure, List<Comment>>> getComments({
    required String postId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.postsEndpoint}/$postId/comments',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );

      if (response.data is List) {
        final comments = (response.data as List)
            .map((json) => Comment.fromJson(json as Map<String, dynamic>))
            .toList();

        return Right(comments);
      }

      return const Right([]);
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
      // 50文字制限バリデーション
      if (content.length > 50) {
        return const Left(
          ValidationFailure('コメントは50文字以内で入力してください'),
        );
      }

      if (content.trim().isEmpty) {
        return const Left(
          ValidationFailure('コメントを入力してください'),
        );
      }

      final response = await _apiClient.post(
        '${ApiConstants.postsEndpoint}/$postId/comments',
        data: {'content': content.trim()},
      );

      final comment = Comment.fromJson(response.data as Map<String, dynamic>);
      logger.i('Comment added: ${comment.id}');
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
      await _apiClient.delete(
        '${ApiConstants.postsEndpoint}/comments/$commentId',
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

  @override
  Future<Either<Failure, void>> reportPost({
    required String postId,
    required String reason,
  }) async {
    try {
      await _apiClient.post(
        '${ApiConstants.postsEndpoint}/$postId/report',
        data: {'reason': reason},
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
}
