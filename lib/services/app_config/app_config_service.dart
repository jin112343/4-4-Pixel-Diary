import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/logger.dart';
import '../../data/datasources/remote/api_client.dart';

/// アプリ設定レスポンス
class AppConfigResponse {
  final VersionConfig version;
  final MaintenanceConfig maintenance;

  const AppConfigResponse({
    required this.version,
    required this.maintenance,
  });

  factory AppConfigResponse.fromJson(Map<String, dynamic> json) {
    return AppConfigResponse(
      version: VersionConfig.fromJson(json['version'] as Map<String, dynamic>),
      maintenance:
          MaintenanceConfig.fromJson(json['maintenance'] as Map<String, dynamic>),
    );
  }
}

/// バージョン設定
class VersionConfig {
  final String minVersion;
  final String latestVersion;
  final bool forceUpdate;
  final StoreUrls storeUrl;

  const VersionConfig({
    required this.minVersion,
    required this.latestVersion,
    required this.forceUpdate,
    required this.storeUrl,
  });

  factory VersionConfig.fromJson(Map<String, dynamic> json) {
    return VersionConfig(
      minVersion: json['minVersion'] as String? ?? '1.0.0',
      latestVersion: json['latestVersion'] as String? ?? '1.0.0',
      forceUpdate: json['forceUpdate'] as bool? ?? false,
      storeUrl: StoreUrls.fromJson(json['storeUrl'] as Map<String, dynamic>? ?? {}),
    );
  }
}

/// ストアURL
class StoreUrls {
  final String ios;
  final String android;

  const StoreUrls({
    required this.ios,
    required this.android,
  });

  factory StoreUrls.fromJson(Map<String, dynamic> json) {
    return StoreUrls(
      ios: json['ios'] as String? ?? '',
      android: json['android'] as String? ?? '',
    );
  }
}

/// メンテナンス設定
class MaintenanceConfig {
  final bool enabled;
  final String message;
  final DateTime? estimatedEndTime;

  const MaintenanceConfig({
    required this.enabled,
    required this.message,
    this.estimatedEndTime,
  });

  factory MaintenanceConfig.fromJson(Map<String, dynamic> json) {
    final endTimeStr = json['estimatedEndTime'] as String?;
    return MaintenanceConfig(
      enabled: json['enabled'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      estimatedEndTime: endTimeStr != null ? DateTime.tryParse(endTimeStr) : null,
    );
  }
}

/// アプリ設定サービス
class AppConfigService {
  final ApiClient _apiClient;

  AppConfigService(this._apiClient);

  /// アプリ設定を取得
  Future<AppConfigResponse?> getAppConfig({
    String? appVersion,
    String? platform,
  }) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/config/app',
        options: Options(
          headers: {
            if (appVersion != null) 'X-App-Version': appVersion,
            if (platform != null) 'X-Platform': platform,
          },
        ),
      );

      if (response.data != null && response.data!['success'] == true) {
        return AppConfigResponse.fromJson(
          response.data!['data'] as Map<String, dynamic>,
        );
      }

      return null;
    } on DioException catch (e, stackTrace) {
      // 503: メンテナンスモード
      if (e.response?.statusCode == 503) {
        final data = e.response?.data;
        if (data is Map<String, dynamic> && data['data'] != null) {
          return AppConfigResponse.fromJson(data['data'] as Map<String, dynamic>);
        }
      }

      // 426: 強制アップデート必要
      if (e.response?.statusCode == 426) {
        final data = e.response?.data;
        if (data is Map<String, dynamic> && data['data'] != null) {
          return AppConfigResponse.fromJson(data['data'] as Map<String, dynamic>);
        }
      }

      logger.e(
        'getAppConfig failed',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    } catch (e, stackTrace) {
      logger.e(
        'getAppConfig unexpected error',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// バージョン比較
  /// v1 < v2 なら負数、v1 > v2 なら正数、等しいなら0
  static int compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.tryParse).toList();
    final parts2 = v2.split('.').map(int.tryParse).toList();

    final maxLength =
        parts1.length > parts2.length ? parts1.length : parts2.length;

    for (var i = 0; i < maxLength; i++) {
      final num1 = i < parts1.length ? (parts1[i] ?? 0) : 0;
      final num2 = i < parts2.length ? (parts2[i] ?? 0) : 0;

      if (num1 < num2) return -1;
      if (num1 > num2) return 1;
    }

    return 0;
  }

  /// 強制アップデートが必要かチェック
  static bool requiresForceUpdate(
    String currentVersion,
    VersionConfig config,
  ) {
    if (!config.forceUpdate) return false;
    return compareVersions(currentVersion, config.minVersion) < 0;
  }
}

/// AppConfigServiceプロバイダー
final appConfigServiceProvider = Provider<AppConfigService>((ref) {
  // 注意: 実際の実装ではApiClientを適切に注入する
  // ここでは仮のApiClientを使用
  final apiClient = ApiClient();
  return AppConfigService(apiClient);
});

/// アプリ設定プロバイダー
final appConfigProvider = FutureProvider<AppConfigResponse?>((ref) async {
  final service = ref.watch(appConfigServiceProvider);

  // 現在のアプリバージョンを取得（package_infoを使用）
  // final packageInfo = await PackageInfo.fromPlatform();
  // final appVersion = packageInfo.version;

  const appVersion = '1.0.0'; // 仮のバージョン
  final platform = _getPlatform();

  return service.getAppConfig(
    appVersion: appVersion,
    platform: platform,
  );
});

String _getPlatform() {
  // 実際の実装ではPlatform.isIOSなどを使用
  return 'ios';
}
