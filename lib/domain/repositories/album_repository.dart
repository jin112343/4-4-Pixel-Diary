import 'package:fpdart/fpdart.dart';

import '../../core/errors/failures.dart';
import '../entities/album.dart';
import '../entities/pixel_art.dart';

/// アルバムリポジトリインターフェース
abstract class AlbumRepository {
  /// アルバムを取得
  Future<Either<Failure, Album>> getAlbum({
    int page = 1,
    int limit = 20,
  });

  /// アルバムに作品を追加
  Future<Either<Failure, void>> addToAlbum(PixelArt pixelArt);

  /// アルバムから作品を削除
  Future<Either<Failure, void>> removeFromAlbum(String pixelArtId);

  /// 日付でアルバムをフィルタリング
  Future<Either<Failure, List<PixelArt>>> getByDate(DateTime date);

  /// 日付範囲でアルバムをフィルタリング
  Future<Either<Failure, List<PixelArt>>> getByDateRange({
    required DateTime start,
    required DateTime end,
  });

  /// サーバーと同期
  Future<Either<Failure, void>> sync();
}
