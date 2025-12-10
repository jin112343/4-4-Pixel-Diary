import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/pixel_art.dart';
import '../../domain/repositories/pixel_art_repository.dart';
import '../datasources/local/local_storage.dart';
import '../datasources/remote/api_client.dart';
import '../datasources/remote/api_interceptor.dart';

/// ドット絵リポジトリ実装
class PixelArtRepositoryImpl implements PixelArtRepository {
  final ApiClient _apiClient;
  final LocalStorage _localStorage;

  PixelArtRepositoryImpl({
    required ApiClient apiClient,
    required LocalStorage localStorage,
  })  : _apiClient = apiClient,
        _localStorage = localStorage;

  @override
  Future<Either<Failure, PixelArt>> exchange({
    required List<int> pixels,
    required String title,
    required int gridSize,
  }) async {
    try {
      // バリデーション
      final expectedPixelCount = gridSize * gridSize;
      if (pixels.length != expectedPixelCount) {
        return Left(ValidationFailure(
          'ピクセル数が不正です（期待: $expectedPixelCount, 実際: ${pixels.length}）',
        ));
      }

      if (title.length > 5) {
        return const Left(ValidationFailure('タイトルは5文字以内で入力してください'));
      }

      // API呼び出し
      final response = await _apiClient.post(
        ApiConstants.exchangeEndpoint,
        data: {
          'pixels': pixels,
          'title': title,
          'gridSize': gridSize,
        },
      );

      // レスポンスをパース
      // サーバーレスポンス形式: { success: bool, data: { received: PixelArt, sent: PixelArt } | { status: 'pending', artId: string } }
      final responseData = response.data as Map<String, dynamic>;

      if (responseData['success'] != true) {
        final error = responseData['error'] as Map<String, dynamic>?;
        return Left(ServerFailure(
          error?['message'] as String? ?? '交換に失敗しました',
          error?['code'] as String?,
        ));
      }

      final data = responseData['data'] as Map<String, dynamic>;

      // ペンディング状態の場合（マッチング相手がいない）
      if (data['status'] == 'pending') {
        logger.i('Exchange pending: artId=${data['artId']}');
        return const Left(ServerFailure(
          '交換相手を探しています。しばらくお待ちください。',
          'PENDING',
        ));
      }

      // マッチング成功の場合
      final receivedData = data['received'] as Map<String, dynamic>;

      // サーバーのフィールド名をFlutterのエンティティに変換
      final receivedArt = _parsePixelArtFromServer(receivedData);

      // ローカルに保存
      await _localStorage.addToAlbum(receivedArt);

      logger.i('Exchange successful: received art ${receivedArt.id}');
      return Right(receivedArt);
    } on DioException catch (e) {
      final apiError = ApiError.fromDioException(e);
      logger.e('Exchange failed: ${apiError.message}');
      return Left(ServerFailure(apiError.message, apiError.code));
    } catch (e, stackTrace) {
      logger.e('Exchange failed', error: e, stackTrace: stackTrace);
      return const Left(UnknownFailure());
    }
  }

  /// サーバーのPixelArtレスポンスをFlutterのエンティティに変換
  PixelArt _parsePixelArtFromServer(Map<String, dynamic> data) {
    return PixelArt(
      id: data['id'] as String,
      pixels: (data['pixels'] as List<dynamic>).map((e) => e as int).toList(),
      title: data['title'] as String? ?? '',
      createdAt: DateTime.parse(data['createdAt'] as String),
      receivedAt: DateTime.now(),
      source: PixelArtSource.server,
      gridSize: data['gridSize'] as int? ?? 4,
      ownerId: data['userId'] as String?,
    );
  }

  @override
  Future<Either<Failure, void>> saveLocal(PixelArt pixelArt) async {
    try {
      await _localStorage.savePixelArt(pixelArt);
      return const Right(null);
    } catch (e, stackTrace) {
      logger.e('Failed to save pixel art locally', error: e, stackTrace: stackTrace);
      return const Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, PixelArt?>> getLocal(String id) async {
    try {
      final pixelArt = _localStorage.getPixelArt(id);
      return Right(pixelArt);
    } catch (e, stackTrace) {
      logger.e('Failed to get pixel art from local', error: e, stackTrace: stackTrace);
      return const Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, List<PixelArt>>> getAllLocal() async {
    try {
      final pixelArts = _localStorage.getAllPixelArts();
      return Right(pixelArts);
    } catch (e, stackTrace) {
      logger.e('Failed to get all pixel arts from local', error: e, stackTrace: stackTrace);
      return const Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, void>> deleteLocal(String id) async {
    try {
      await _localStorage.deletePixelArt(id);
      return const Right(null);
    } catch (e, stackTrace) {
      logger.e('Failed to delete pixel art from local', error: e, stackTrace: stackTrace);
      return const Left(CacheFailure());
    }
  }
}
