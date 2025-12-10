import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/logger.dart';
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
      final response = await _apiClient.get(
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
      final response = await _apiClient.post(
        ApiConstants.postsEndpoint,
        data: {
          'pixelArtId': pixelArtId,
          'pixels': pixels,
          'title': title,
          'gridSize': gridSize,
          if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
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
