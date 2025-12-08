import 'package:freezed_annotation/freezed_annotation.dart';

part 'post.freezed.dart';
part 'post.g.dart';

/// 投稿の公開設定
enum PostVisibility {
  /// 公開
  public,

  /// 非公開
  private,
}

/// 投稿エンティティ
@freezed
class Post with _$Post {
  const factory Post({
    /// 投稿ID
    required String id,

    /// ドット絵ID
    required String pixelArtId,

    /// ピクセルデータ（表示用）
    required List<int> pixels,

    /// タイトル
    @Default('') String title,

    /// 作成者ID
    required String ownerId,

    /// 作成者ニックネーム
    String? ownerNickname,

    /// いいね数
    @Default(0) int likeCount,

    /// コメント数
    @Default(0) int commentCount,

    /// 作成日時
    required DateTime createdAt,

    /// 公開設定
    @Default(PostVisibility.public) PostVisibility visibility,

    /// グリッドサイズ
    @Default(4) int gridSize,

    /// 自分がいいねしたか
    @Default(false) bool isLikedByMe,
  }) = _Post;

  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);
}
