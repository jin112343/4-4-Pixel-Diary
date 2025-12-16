import 'package:flutter/widgets.dart';

/// 広告サービスの共通インターフェース
abstract class AdServiceInterface {
  /// 初期化
  Future<void> initialize();

  /// 初期化済みかどうか
  bool get isInitialized;

  /// リワード広告が準備できているか
  bool get isRewardedAdReady;

  /// リワード広告をロード
  void loadRewardedAd();

  /// リワード広告を表示
  Future<bool> showRewardedAd({
    required void Function() onRewarded,
    void Function()? onAdDismissed,
  });

  /// ネイティブ広告ウィジェットを作成
  Widget buildNativeAd({
    double? height,
    String? adSlotId,
  });

  /// バナー広告ウィジェットを作成
  Widget buildBannerAd({
    double? height,
    String? adSlotId,
  });
}
