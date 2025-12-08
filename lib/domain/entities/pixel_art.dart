import 'package:freezed_annotation/freezed_annotation.dart';

part 'pixel_art.freezed.dart';
part 'pixel_art.g.dart';

/// ドット絵のソース
enum PixelArtSource {
  /// 自分で作成
  local,

  /// サーバー経由で受信
  server,

  /// Bluetooth経由で受信
  bluetooth,
}

/// ドット絵エンティティ
@freezed
class PixelArt with _$PixelArt {
  const factory PixelArt({
    /// 一意のID
    required String id,

    /// ピクセルデータ（RGB値の配列）
    /// 4×4 = 16個、5×5 = 25個
    required List<int> pixels,

    /// タイトル（最大5文字）
    @Default('') String title,

    /// 作成日時
    required DateTime createdAt,

    /// 受信日時（交換で受け取った場合）
    DateTime? receivedAt,

    /// ソース
    @Default(PixelArtSource.local) PixelArtSource source,

    /// グリッドサイズ（4 or 5）
    @Default(4) int gridSize,

    /// 作成者ID（匿名UUID）
    String? ownerId,

    /// 作成者のニックネーム
    String? authorNickname,
  }) = _PixelArt;

  factory PixelArt.fromJson(Map<String, dynamic> json) =>
      _$PixelArtFromJson(json);
}
