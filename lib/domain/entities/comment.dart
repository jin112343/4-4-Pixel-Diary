import 'package:freezed_annotation/freezed_annotation.dart';

part 'comment.freezed.dart';
part 'comment.g.dart';

/// コメントエンティティ
@freezed
class Comment with _$Comment {
  const factory Comment({
    /// コメントID
    required String id,

    /// 投稿ID
    required String postId,

    /// ユーザーID
    required String userId,

    /// ユーザーニックネーム
    String? userNickname,

    /// コメント内容（最大50文字）
    required String content,

    /// 作成日時
    required DateTime createdAt,
  }) = _Comment;

  factory Comment.fromJson(Map<String, dynamic> json) =>
      _$CommentFromJson(json);
}
