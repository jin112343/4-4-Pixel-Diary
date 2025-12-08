import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/logger.dart';

/// BLEプライバシー設定
enum BlePrivacyMode {
  /// 標準モード（システムデフォルト）
  standard,

  /// 強化モード（最大限のプライバシー保護）
  enhanced,
}

/// BLE MACアドレスランダム化設定サービス
/// プライバシー保護のためのMACアドレスランダム化を管理
class BlePrivacyService {
  BlePrivacyService._();

  static final BlePrivacyService instance = BlePrivacyService._();

  static const String _privacyModeKey = 'ble_privacy_mode';
  static const String _randomizeIntervalKey = 'ble_randomize_interval';

  // プラットフォームチャンネル（ネイティブコード連携用）
  static const MethodChannel _channel = MethodChannel(
    'com.pixeldiary/ble_privacy',
  );

  SharedPreferences? _prefs;
  BlePrivacyMode _currentMode = BlePrivacyMode.standard;

  /// 現在のプライバシーモード
  BlePrivacyMode get currentMode => _currentMode;

  /// 初期化
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final modeIndex = _prefs?.getInt(_privacyModeKey) ?? 0;
      _currentMode = BlePrivacyMode.values[modeIndex];
      logger.i('BLE Privacy Service initialized: $_currentMode');
    } catch (e, stackTrace) {
      logger.e('BLE Privacy Service init failed', error: e, stackTrace: stackTrace);
    }
  }

  /// プライバシーモードを設定
  Future<void> setPrivacyMode(BlePrivacyMode mode) async {
    try {
      _currentMode = mode;
      await _prefs?.setInt(_privacyModeKey, mode.index);

      // プラットフォーム固有の設定を適用
      await _applyPlatformSettings(mode);

      logger.i('BLE Privacy Mode set to: $mode');
    } catch (e, stackTrace) {
      logger.e('setPrivacyMode failed', error: e, stackTrace: stackTrace);
    }
  }

  /// MACアドレスランダム化の間隔を設定（分）
  /// 注意: これはアプリ側で広告を再開するタイミングの設定
  Future<void> setRandomizeInterval(int minutes) async {
    try {
      await _prefs?.setInt(_randomizeIntervalKey, minutes);
      logger.i('BLE randomize interval set to: $minutes minutes');
    } catch (e, stackTrace) {
      logger.e('setRandomizeInterval failed', error: e, stackTrace: stackTrace);
    }
  }

  /// 現在のランダム化間隔を取得
  int getRandomizeInterval() {
    return _prefs?.getInt(_randomizeIntervalKey) ?? 15; // デフォルト15分
  }

  /// プラットフォーム固有の設定を適用
  Future<void> _applyPlatformSettings(BlePrivacyMode mode) async {
    try {
      if (Platform.isAndroid) {
        await _applyAndroidSettings(mode);
      } else if (Platform.isIOS) {
        await _applyIosSettings(mode);
      }
    } catch (e, stackTrace) {
      logger.e('_applyPlatformSettings failed', error: e, stackTrace: stackTrace);
    }
  }

  /// Android固有の設定
  /// Android 6.0+ではBLEスタックがデフォルトでランダムアドレスを使用
  Future<void> _applyAndroidSettings(BlePrivacyMode mode) async {
    try {
      // Androidでは以下の設定が可能:
      // - BLE広告時のアドレスタイプ
      // - プライベートアドレスの更新間隔
      await _channel.invokeMethod<void>('setPrivacyMode', {
        'mode': mode == BlePrivacyMode.enhanced ? 'enhanced' : 'standard',
        'randomizeOnReconnect': mode == BlePrivacyMode.enhanced,
      });
    } on MissingPluginException {
      // ネイティブ実装がない場合はスキップ
      logger.d('Android native privacy settings not implemented');
    } catch (e, stackTrace) {
      logger.e('_applyAndroidSettings failed', error: e, stackTrace: stackTrace);
    }
  }

  /// iOS固有の設定
  /// iOSではシステムが自動的にプライベートアドレスを管理
  Future<void> _applyIosSettings(BlePrivacyMode mode) async {
    try {
      // iOSでは:
      // - iOS 8以降、BLEスキャン時に自動でランダムアドレス
      // - iOS 13以降、より強力なプライバシー保護
      // アプリ側で制御できる設定は限定的
      await _channel.invokeMethod<void>('setPrivacyMode', {
        'mode': mode == BlePrivacyMode.enhanced ? 'enhanced' : 'standard',
      });
    } on MissingPluginException {
      // ネイティブ実装がない場合はスキップ
      logger.d('iOS native privacy settings not implemented');
    } catch (e, stackTrace) {
      logger.e('_applyIosSettings failed', error: e, stackTrace: stackTrace);
    }
  }

  /// プライバシー情報を取得
  BlePrivacyInfo getPrivacyInfo() {
    return BlePrivacyInfo(
      mode: _currentMode,
      randomizeInterval: getRandomizeInterval(),
      isSystemManaged: _isSystemManagedRandomization(),
      platformInfo: _getPlatformPrivacyInfo(),
    );
  }

  /// システム管理のランダム化かどうか
  bool _isSystemManagedRandomization() {
    // iOS 8+, Android 6.0+ではシステムが自動管理
    if (Platform.isIOS) {
      return true; // iOSは常にシステム管理
    } else if (Platform.isAndroid) {
      return true; // Android 6.0+はシステム管理
    }
    return false;
  }

  /// プラットフォーム固有のプライバシー情報
  String _getPlatformPrivacyInfo() {
    if (Platform.isIOS) {
      return 'iOSではBLE通信時に自動的にランダムなMACアドレスが使用されます。'
          'これはシステムレベルで管理され、追加の設定は不要です。';
    } else if (Platform.isAndroid) {
      return 'Android 6.0以降では、BLE広告時に自動的にランダムなプライベートアドレスが使用されます。'
          '強化モードを有効にすると、接続ごとにアドレスを更新します。';
    }
    return 'このプラットフォームのBLEプライバシー設定は不明です。';
  }
}

/// BLEプライバシー情報
class BlePrivacyInfo {
  const BlePrivacyInfo({
    required this.mode,
    required this.randomizeInterval,
    required this.isSystemManaged,
    required this.platformInfo,
  });

  final BlePrivacyMode mode;
  final int randomizeInterval;
  final bool isSystemManaged;
  final String platformInfo;
}
