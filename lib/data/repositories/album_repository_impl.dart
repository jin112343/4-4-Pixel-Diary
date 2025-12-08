import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/pixel_art.dart';
import '../../domain/repositories/album_repository.dart';
import '../datasources/local/local_storage.dart';
import '../datasources/remote/api_client.dart';
import '../datasources/remote/api_interceptor.dart';

/// アルバムリポジトリ実装
class AlbumRepositoryImpl implements AlbumRepository {
  final ApiClient _apiClient;
  final LocalStorage _localStorage;
  final String _userId;

  AlbumRepositoryImpl({
    required ApiClient apiClient,
    required LocalStorage localStorage,
    required String userId,
  })  : _apiClient = apiClient,
        _localStorage = localStorage,
        _userId = userId;

  @override
  Future<Either<Failure, Album>> getAlbum({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      // まずローカルから取得
      final localArts = _localStorage.getAlbumPixelArts();

      // ページネーション
      final startIndex = (page - 1) * limit;
      final endIndex = startIndex + limit;
      final pagedArts = localArts.length > startIndex
          ? localArts.sublist(
              startIndex,
              endIndex > localArts.length ? localArts.length : endIndex,
            )
          : <PixelArt>[];

      final album = Album(
        userId: _userId,
        pixelArts: pagedArts,
        totalCount: localArts.length,
      );

      return Right(album);
    } catch (e, stackTrace) {
      logger.e('Failed to get album', error: e, stackTrace: stackTrace);
      return const Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, void>> addToAlbum(PixelArt pixelArt) async {
    try {
      await _localStorage.addToAlbum(pixelArt);
      return const Right(null);
    } catch (e, stackTrace) {
      logger.e('Failed to add to album', error: e, stackTrace: stackTrace);
      return const Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, void>> removeFromAlbum(String pixelArtId) async {
    try {
      await _localStorage.removeFromAlbum(pixelArtId);
      return const Right(null);
    } catch (e, stackTrace) {
      logger.e('Failed to remove from album', error: e, stackTrace: stackTrace);
      return const Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, List<PixelArt>>> getByDate(DateTime date) async {
    try {
      final arts = _localStorage.getAlbumByDate(date);
      return Right(arts);
    } catch (e, stackTrace) {
      logger.e('Failed to get album by date', error: e, stackTrace: stackTrace);
      return const Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, List<PixelArt>>> getByDateRange({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final allArts = _localStorage.getAlbumPixelArts();
      final filteredArts = allArts.where((art) {
        return art.createdAt.isAfter(start) && art.createdAt.isBefore(end);
      }).toList();

      return Right(filteredArts);
    } catch (e, stackTrace) {
      logger.e('Failed to get album by date range', error: e, stackTrace: stackTrace);
      return const Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, void>> sync() async {
    try {
      // サーバーからアルバムを取得
      final response = await _apiClient.get(ApiConstants.albumEndpoint);

      if (response.data is List) {
        final serverArts = (response.data as List)
            .map((json) => PixelArt.fromJson(json as Map<String, dynamic>))
            .toList();

        // ローカルにない作品を追加
        for (final art in serverArts) {
          await _localStorage.addToAlbum(art);
        }

        logger.i('Album synced: ${serverArts.length} items');
      }

      return const Right(null);
    } on DioException catch (e) {
      final apiError = ApiError.fromDioException(e);
      logger.e('Sync failed: ${apiError.message}');
      return Left(ServerFailure(apiError.message, apiError.code));
    } catch (e, stackTrace) {
      logger.e('Sync failed', error: e, stackTrace: stackTrace);
      return const Left(UnknownFailure());
    }
  }
}
