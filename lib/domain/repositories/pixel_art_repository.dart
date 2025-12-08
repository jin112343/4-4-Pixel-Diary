import 'package:fpdart/fpdart.dart';

import '../../core/errors/failures.dart';
import '../entities/pixel_art.dart';

/// ドット絵リポジトリインターフェース
abstract class PixelArtRepository {
  /// ドット絵を交換する
  /// 自分の作品を送信し、他のユーザーの作品を受け取る
  Future<Either<Failure, PixelArt>> exchange({
    required List<int> pixels,
    required String title,
    required int gridSize,
  });

  /// ドット絵をローカルに保存
  Future<Either<Failure, void>> saveLocal(PixelArt pixelArt);

  /// ローカルからドット絵を取得
  Future<Either<Failure, PixelArt?>> getLocal(String id);

  /// ローカルからすべてのドット絵を取得
  Future<Either<Failure, List<PixelArt>>> getAllLocal();

  /// ローカルのドット絵を削除
  Future<Either<Failure, void>> deleteLocal(String id);
}
