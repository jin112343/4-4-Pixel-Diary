import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:safe_device/safe_device.dart';

import '../../core/utils/logger.dart';

/// セキュリティステータス
class SecurityStatus {
  final bool isJailbroken;
  final bool isRooted;
  final bool isDeveloperMode;
  final bool isEmulator;
  final List<String> warnings;

  SecurityStatus({
    required this.isJailbroken,
    required this.isRooted,
    required this.isDeveloperMode,
    required this.isEmulator,
    required this.warnings,
  });

  /// セキュアな状態かどうか
  bool get isSecure =>
      !isJailbroken && !isRooted && !isDeveloperMode && !isEmulator;

  /// 警告メッセージを取得
  String get warningMessage {
    if (warnings.isEmpty) return '';
    return warnings.join('\n');
  }
}

/// セキュリティチェックサービス
class SecurityService {
  /// セキュリティチェックを実行
  Future<SecurityStatus> checkSecurity() async {
    // WebではPlatform APIが未サポートのためスキップ
    if (kIsWeb) {
      logger.i('Security check skipped on web');
      return SecurityStatus(
        isJailbroken: false,
        isRooted: false,
        isDeveloperMode: false,
        isEmulator: false,
        warnings: const [],
      );
    }

    final warnings = <String>[];
    var isJailbroken = false;
    var isRooted = false;
    var isDeveloperMode = false;
    var isEmulator = false;

    try {
      // ジェイルブレイク/ルート検知
      if (Platform.isIOS) {
        isJailbroken = await _checkJailbreak();
        if (isJailbroken) {
          warnings.add('ジェイルブレイクされたデバイスが検出されました');
        }
      } else if (Platform.isAndroid) {
        isRooted = await _checkRoot();
        if (isRooted) {
          warnings.add('ルート化されたデバイスが検出されました');
        }
      }

      // 開発者モード検知（Android）
      if (Platform.isAndroid) {
        isDeveloperMode = await _checkDeveloperMode();
        if (isDeveloperMode) {
          warnings.add('開発者モードが有効です');
        }
      }

      // エミュレータ検知
      isEmulator = await _checkEmulator();
      if (isEmulator && !kDebugMode) {
        warnings.add('エミュレータが検出されました');
      }

      logger.i('Security check completed: ${warnings.isEmpty ? "secure" : warnings.length.toString() + " warnings"}');
    } catch (e, stackTrace) {
      logger.e(
        'SecurityService.checkSecurity failed',
        error: e,
        stackTrace: stackTrace,
      );
    }

    return SecurityStatus(
      isJailbroken: isJailbroken,
      isRooted: isRooted,
      isDeveloperMode: isDeveloperMode,
      isEmulator: isEmulator,
      warnings: warnings,
    );
  }

  /// ジェイルブレイク検知（iOS）
  Future<bool> _checkJailbreak() async {
    try {
      return await SafeDevice.isJailBroken;
    } catch (e) {
      logger.w('Jailbreak detection failed: $e');
      return false;
    }
  }

  /// ルート検知（Android）
  Future<bool> _checkRoot() async {
    try {
      return await SafeDevice.isJailBroken;
    } catch (e) {
      logger.w('Root detection failed: $e');
      return false;
    }
  }

  /// 開発者モード検知（Android）
  Future<bool> _checkDeveloperMode() async {
    try {
      return await SafeDevice.isDevelopmentModeEnable;
    } catch (e) {
      logger.w('Developer mode detection failed: $e');
      return false;
    }
  }

  /// エミュレータ検知
  Future<bool> _checkEmulator() async {
    // デバッグモードではエミュレータチェックをスキップ
    if (kDebugMode) {
      return false;
    }

    try {
      // プラットフォーム固有のエミュレータ検知
      if (Platform.isAndroid) {
        return _checkAndroidEmulator();
      } else if (Platform.isIOS) {
        return _checkIOSSimulator();
      }
      return false;
    } catch (e) {
      logger.w('Emulator detection failed: $e');
      return false;
    }
  }

  /// Androidエミュレータ検知
  bool _checkAndroidEmulator() {
    // 一般的なエミュレータの特徴を確認
    final indicators = [
      Platform.environment['ANDROID_EMULATOR'],
      Platform.environment['ANDROID_SDK_ROOT'],
    ];

    return indicators.any((indicator) => indicator != null);
  }

  /// iOSシミュレータ検知
  bool _checkIOSSimulator() {
    // シミュレータの特徴を確認
    return Platform.environment['SIMULATOR_DEVICE_NAME'] != null;
  }

  /// セキュリティ警告ダイアログを表示すべきか
  bool shouldShowWarning(SecurityStatus status) {
    // デバッグモードでは警告を表示しない
    if (kDebugMode) {
      return false;
    }

    // ジェイルブレイク/ルートの場合のみ警告
    return status.isJailbroken || status.isRooted;
  }

  /// 危険な状態でアプリをブロックすべきか
  bool shouldBlockApp(SecurityStatus status) {
    // デバッグモードではブロックしない
    if (kDebugMode) {
      return false;
    }

    // 本番環境でジェイルブレイク/ルートの場合はブロック
    return status.isJailbroken || status.isRooted;
  }
}
