import 'package:fpdart/fpdart.dart';

import '../../core/errors/failures.dart';
import '../entities/anonymous_user.dart';

/// 認証リポジトリインターフェース
abstract class AuthRepository {
  /// 現在のユーザーを取得
  Future<Either<Failure, AnonymousUser?>> getCurrentUser();

  /// 匿名ユーザーを作成/取得
  /// デバイスIDベースで一意のユーザーを生成
  Future<Either<Failure, AnonymousUser>> getOrCreateAnonymousUser();

  /// ニックネームを更新
  Future<Either<Failure, AnonymousUser>> updateNickname(String nickname);

  /// 設定を更新
  Future<Either<Failure, AnonymousUser>> updateSettings(UserSettings settings);

  /// プレミアムグリッドを有効化
  Future<Either<Failure, AnonymousUser>> enablePremiumGrid();

  /// ユーザーデータを削除
  Future<Either<Failure, void>> deleteUser();
}
