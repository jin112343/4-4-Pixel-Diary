import 'package:flutter/foundation.dart';

/// API関連定数
class ApiConstants {
  ApiConstants._();

  /// ベースURL（本番環境）
  static const String _prodBaseUrl =
      'https://mipptdxyc9.execute-api.ap-northeast-1.amazonaws.com/v1';

  /// ベースURL（開発環境） - AWS API Gateway
  static const String _devBaseUrl =
      'https://7myvq0fjwe.execute-api.ap-northeast-1.amazonaws.com/v1';

  /// 現在の環境に応じたベースURL
  /// デバッグモードでは開発環境URL、リリースモードでは本番環境URLを使用
  static String get baseUrl {
    // 環境変数で上書き可能（--dart-define=API_ENV=dev で指定）
    const apiEnv = String.fromEnvironment('API_ENV', defaultValue: '');

    if (apiEnv == 'prod') {
      return _prodBaseUrl;
    } else if (apiEnv == 'dev') {
      return _devBaseUrl;
    }

    // 環境変数がない場合はデバッグモードで判定
    return kDebugMode ? _devBaseUrl : _prodBaseUrl;
  }

  /// 開発環境URL（互換性のため残す）
  @Deprecated('Use baseUrl instead')
  static const String devBaseUrl = _devBaseUrl;

  /// エンドポイント
  static const String exchangeEndpoint = '/pixelart/exchange';
  static const String albumEndpoint = '/album';
  static const String postsEndpoint = '/posts';
  static const String bluetoothUploadEndpoint = '/bluetooth/upload';

  /// ヘッダー
  static const String contentType = 'application/json';
  static const String authorizationHeader = 'Authorization';
  static const String deviceIdHeader = 'X-Device-ID';
}
