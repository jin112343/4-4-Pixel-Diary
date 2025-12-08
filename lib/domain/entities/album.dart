import 'package:freezed_annotation/freezed_annotation.dart';
import 'pixel_art.dart';

part 'album.freezed.dart';
part 'album.g.dart';

/// アルバムエンティティ
@freezed
class Album with _$Album {
  const factory Album({
    /// ユーザーID
    required String userId,

    /// ドット絵リスト
    @Default([]) List<PixelArt> pixelArts,

    /// 最終同期日時
    DateTime? lastSyncedAt,

    /// 総数
    @Default(0) int totalCount,
  }) = _Album;

  factory Album.fromJson(Map<String, dynamic> json) => _$AlbumFromJson(json);
}
