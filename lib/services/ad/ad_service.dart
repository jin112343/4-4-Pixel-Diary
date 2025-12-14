import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/utils/logger.dart';

/// 広告サービス
class AdService {
  AdService._();

  static AdService? _instance;
  bool _isInitialized = false;
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;

  /// シングルトンインスタンスを取得
  static AdService get instance {
    _instance ??= AdService._();
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

  /// 初期化
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      logger.i('AdService initialized');
      // リワード広告を事前にロード
      loadRewardedAd();
    } catch (e, stackTrace) {
      logger.e(
        'AdService initialization failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// 初期化済みかどうか
  bool get isInitialized => _isInitialized;

  /// リワード広告が準備できているか
  bool get isRewardedAdReady => _rewardedAd != null;

  /// リワード広告をロード
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

  /// リワード広告を表示
  /// [onRewarded] 広告視聴完了時のコールバック
  /// [onAdDismissed] 広告が閉じられた時のコールバック
  /// 戻り値: 広告が表示された場合true、表示できなかった場合false
  Future<bool> showRewardedAd({
    required void Function() onRewarded,
    void Function()? onAdDismissed,
  }) async {
    if (_rewardedAd == null) {
      logger.w('RewardedAd not ready, loading...');
      loadRewardedAd();
      return false;
    }

    bool rewarded = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        // 次の広告をロード
        loadRewardedAd();
        if (rewarded) {
          onRewarded();
        }
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        logger.e('RewardedAd failed to show', error: error);
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        rewarded = true;
        logger.i('User earned reward: ${reward.amount} ${reward.type}');
      },
    );

    return true;
  }
}
