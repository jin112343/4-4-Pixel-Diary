import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/utils/logger.dart';
import 'ad_service_interface.dart';

/// プラットフォーム別広告サービスを取得
AdServiceInterface getAdService() => MobileAdService.instance;

/// モバイル用広告サービス (Google Mobile Ads)
class MobileAdService implements AdServiceInterface {
  MobileAdService._();

  static MobileAdService? _instance;
  bool _isInitialized = false;
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;

  /// シングルトンインスタンスを取得
  static MobileAdService get instance {
    _instance ??= MobileAdService._();
    return _instance!;
  }

  /// Android ネイティブ広告ユニットID
  static const String _androidNativeAdUnitId =
      'ca-app-pub-1187210314934709/5013675953';

  /// iOS ネイティブ広告ユニットID
  static const String _iosNativeAdUnitId =
      'ca-app-pub-1187210314934709/3937409761';

  /// テスト用ネイティブ広告ユニットID
  static const String _testNativeAdUnitId =
      'ca-app-pub-3940256099942544/2247696110';

  /// Android リワード広告ユニットID
  static const String _androidRewardedAdUnitId =
      'ca-app-pub-1187210314934709/1506687545';

  /// iOS リワード広告ユニットID
  static const String _iosRewardedAdUnitId =
      'ca-app-pub-1187210314934709/7521238033';

  /// テスト用リワード広告ユニットID
  static const String _testRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  /// ネイティブ広告ユニットIDを取得
  String get nativeAdUnitId {
    if (kDebugMode) {
      return _testNativeAdUnitId;
    }
    if (Platform.isAndroid) {
      return _androidNativeAdUnitId;
    } else if (Platform.isIOS) {
      return _iosNativeAdUnitId;
    }
    return _testNativeAdUnitId;
  }

  /// リワード広告ユニットIDを取得
  String get rewardedAdUnitId {
    if (kDebugMode) {
      return _testRewardedAdUnitId;
    }
    if (Platform.isAndroid) {
      return _androidRewardedAdUnitId;
    } else if (Platform.isIOS) {
      return _iosRewardedAdUnitId;
    }
    return _testRewardedAdUnitId;
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      logger.i('MobileAdService initialized');
      // リワード広告を事前にロード
      loadRewardedAd();
    } catch (e, stackTrace) {
      logger.e(
        'MobileAdService initialization failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isRewardedAdReady => _rewardedAd != null;

  @override
  void loadRewardedAd() {
    if (_isRewardedAdLoading || _rewardedAd != null) return;

    _isRewardedAdLoading = true;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
          logger.i('RewardedAd loaded');
        },
        onAdFailedToLoad: (error) {
          _isRewardedAdLoading = false;
          logger.e(
            'RewardedAd failed to load',
            error: error,
          );
        },
      ),
    );
  }

  @override
  Future<bool> showRewardedAd({
    required void Function() onRewarded,
    void Function()? onAdDismissed,
  }) async {
    if (_rewardedAd == null) {
      logger.w('RewardedAd not ready, loading...');
      loadRewardedAd();
      return false;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        // 次の広告をロード
        loadRewardedAd();
        // リワード獲得の有無に関わらず交換を実行
        onRewarded();
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        logger.e('RewardedAd failed to show', error: error);
        // 広告表示失敗時も交換を実行
        onRewarded();
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        logger.i('User earned reward: ${reward.amount} ${reward.type}');
      },
    );

    return true;
  }

  @override
  Widget buildNativeAd({
    double? height,
    String? adSlotId,
  }) {
    return _NativeAdWidget(
      adUnitId: nativeAdUnitId,
      height: height ?? 280,
    );
  }

  @override
  Widget buildBannerAd({
    double? height,
    String? adSlotId,
  }) {
    return _BannerAdWidget(
      adUnitId: nativeAdUnitId,
      height: height ?? 90,
    );
  }
}

/// ネイティブ広告ウィジェット
class _NativeAdWidget extends StatefulWidget {
  final String adUnitId;
  final double height;

  const _NativeAdWidget({
    required this.adUnitId,
    required this.height,
  });

  @override
  State<_NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<_NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _nativeAd = NativeAd(
      adUnitId: widget.adUnitId,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          logger.e('NativeAd failed to load', error: error);
        },
      ),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
      ),
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _nativeAd == null) {
      return SizedBox(height: widget.height);
    }
    return SizedBox(
      height: widget.height,
      child: AdWidget(ad: _nativeAd!),
    );
  }
}

/// バナー広告ウィジェット
class _BannerAdWidget extends StatefulWidget {
  final String adUnitId;
  final double height;

  const _BannerAdWidget({
    required this.adUnitId,
    required this.height,
  });

  @override
  State<_BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<_BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: widget.adUnitId,
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          logger.e('BannerAd failed to load', error: error);
        },
      ),
      request: const AdRequest(),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      return SizedBox(height: widget.height);
    }
    return SizedBox(
      height: widget.height,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
