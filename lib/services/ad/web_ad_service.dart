import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../core/utils/logger.dart';
import 'ad_service_interface.dart';

/// プラットフォーム別広告サービスを取得
AdServiceInterface getAdService() => WebAdService.instance;

/// Web用広告サービス (Google AdSense)
class WebAdService implements AdServiceInterface {
  WebAdService._();

  static WebAdService? _instance;
  bool _isInitialized = false;
  int _adCounter = 0;

  /// シングルトンインスタンスを取得
  static WebAdService get instance {
    _instance ??= WebAdService._();
    return _instance!;
  }

  /// AdSense クライアントID
  static const String _adClient = 'ca-pub-1187210314934709';

  /// デフォルトの広告スロットID
  static const String _defaultAdSlot = '5554152884';

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // AdSense スクリプトは index.html で読み込み済み
      _isInitialized = true;
      logger.i('WebAdService initialized');
    } catch (e, stackTrace) {
      logger.e(
        'WebAdService initialization failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isRewardedAdReady => false; // Web版ではリワード広告未対応

  @override
  void loadRewardedAd() {
    // Web版ではリワード広告未対応
    logger.w('Rewarded ads are not supported on web');
  }

  @override
  Future<bool> showRewardedAd({
    required void Function() onRewarded,
    void Function()? onAdDismissed,
  }) async {
    // Web版ではリワード広告未対応のため、直接報酬を付与
    logger.w('Rewarded ads not supported on web, granting reward directly');
    onRewarded();
    onAdDismissed?.call();
    return true;
  }

  @override
  Widget buildNativeAd({
    double? height,
    String? adSlotId,
  }) {
    return _buildAdSenseAd(
      height: height ?? 280,
      adSlotId: adSlotId ?? _defaultAdSlot,
      adFormat: 'fluid',
    );
  }

  @override
  Widget buildBannerAd({
    double? height,
    String? adSlotId,
  }) {
    return _buildAdSenseAd(
      height: height ?? 90,
      adSlotId: adSlotId ?? _defaultAdSlot,
      adFormat: 'auto',
    );
  }

  /// AdSense広告ウィジェットを構築
  Widget _buildAdSenseAd({
    required double height,
    required String adSlotId,
    required String adFormat,
  }) {
    final viewType = 'adsense-ad-${_adCounter++}';

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        final container = web.document.createElement('div') as web.HTMLDivElement
          ..style.width = '100%'
          ..style.height = '${height}px'
          ..style.display = 'flex'
          ..style.justifyContent = 'center'
          ..style.alignItems = 'center';

        final ins = web.document.createElement('ins') as web.HTMLElement
          ..className = 'adsbygoogle'
          ..style.display = 'block'
          ..style.width = '100%'
          ..style.height = '${height}px'
          ..setAttribute('data-ad-client', _adClient)
          ..setAttribute('data-ad-slot', adSlotId)
          ..setAttribute('data-ad-format', adFormat)
          ..setAttribute('data-full-width-responsive', 'true');

        container.appendChild(ins);

        // AdSense の push を実行
        _pushAd();

        return container;
      },
    );

    return SizedBox(
      height: height,
      child: HtmlElementView(viewType: viewType),
    );
  }

  /// AdSense 広告をプッシュ
  void _pushAd() {
    try {
      _pushAdJs();
    } catch (e) {
      logger.e('Failed to push AdSense ad', error: e);
    }
  }
}

/// JavaScript の adsbygoogle.push() を呼び出す
@JS('eval')
external void _evalJs(String code);

void _pushAdJs() {
  _evalJs('(adsbygoogle = window.adsbygoogle || []).push({})');
}
