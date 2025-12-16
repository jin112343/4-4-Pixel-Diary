import 'package:flutter/widgets.dart';

import 'ad_service_interface.dart';

/// スタブ実装（コンパイル用）
AdServiceInterface getAdService() {
  throw UnsupportedError('Cannot create AdService without dart:io or dart:html');
}

/// スタブ広告サービス
class StubAdService implements AdServiceInterface {
  @override
  Future<void> initialize() async {}

  @override
  bool get isInitialized => false;

  @override
  bool get isRewardedAdReady => false;

  @override
  void loadRewardedAd() {}

  @override
  Future<bool> showRewardedAd({
    required void Function() onRewarded,
    void Function()? onAdDismissed,
  }) async {
    onRewarded();
    return true;
  }

  @override
  Widget buildNativeAd({double? height, String? adSlotId}) {
    return SizedBox(height: height ?? 280);
  }

  @override
  Widget buildBannerAd({double? height, String? adSlotId}) {
    return SizedBox(height: height ?? 90);
  }
}
