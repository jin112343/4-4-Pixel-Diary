import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/utils/logger.dart';
import 'ad_service_interface.dart';

// 条件付きインポート
import 'ad_service_stub.dart'
    if (dart.library.io) 'mobile_ad_service.dart'
    if (dart.library.html) 'web_ad_service.dart' as platform_ad;

/// 広告サービス（プラットフォーム共通）
class AdService implements AdServiceInterface {
  AdService._();

  static AdService? _instance;
  late final AdServiceInterface _platformService;
  bool _initialized = false;

  /// シングルトンインスタンスを取得
  static AdService get instance {
    _instance ??= AdService._();
    return _instance!;
  }

  /// 初期化
  @override
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      if (kIsWeb) {
        _platformService = platform_ad.getAdService();
        logger.i('Using WebAdService');
      } else {
        _platformService = platform_ad.getAdService();
        logger.i('Using MobileAdService');
      }

      await _platformService.initialize();
      _initialized = true;
      logger.i('AdService initialized');
    } catch (e, stackTrace) {
      logger.e(
        'AdService initialization failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  bool get isInitialized => _initialized && _platformService.isInitialized;

  @override
  bool get isRewardedAdReady => _platformService.isRewardedAdReady;

  @override
  void loadRewardedAd() => _platformService.loadRewardedAd();

  @override
  Future<bool> showRewardedAd({
    required void Function() onRewarded,
    void Function()? onAdDismissed,
  }) {
    return _platformService.showRewardedAd(
      onRewarded: onRewarded,
      onAdDismissed: onAdDismissed,
    );
  }

  @override
  Widget buildNativeAd({
    double? height,
    String? adSlotId,
  }) {
    return _platformService.buildNativeAd(
      height: height,
      adSlotId: adSlotId,
    );
  }

  @override
  Widget buildBannerAd({
    double? height,
    String? adSlotId,
  }) {
    return _platformService.buildBannerAd(
      height: height,
      adSlotId: adSlotId,
    );
  }
}
