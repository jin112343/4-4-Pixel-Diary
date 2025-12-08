import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/utils/logger.dart';

/// 認証インターセプター
class AuthInterceptor extends Interceptor {
  final String? deviceId;
  String? _accessToken;

  AuthInterceptor({this.deviceId});

  /// アクセストークンを設定
  void setAccessToken(String? token) {
    _accessToken = token;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // デバイスIDをヘッダーに追加
    if (deviceId != null) {
      options.headers[ApiConstants.deviceIdHeader] = deviceId;
    }

    // アクセストークンをヘッダーに追加
    if (_accessToken != null) {
      options.headers[ApiConstants.authorizationHeader] = 'Bearer $_accessToken';
    }

    // タイムスタンプを追加（リプレイ攻撃防止）
    options.headers['X-Timestamp'] = DateTime.now().millisecondsSinceEpoch.toString();

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 401エラーの場合、トークンをクリア
    if (err.response?.statusCode == 401) {
      _accessToken = null;
      logger.w('Access token cleared due to 401 error');
    }

    handler.next(err);
  }
}

/// エラーレスポンスのパース
class ApiError {
  final String message;
  final String? code;
  final int? statusCode;

  ApiError({
    required this.message,
    this.code,
    this.statusCode,
  });

  factory ApiError.fromDioException(DioException e) {
    final response = e.response;

    if (response != null && response.data is Map) {
      final data = response.data as Map;
      return ApiError(
        message: data['message']?.toString() ?? 'サーバーエラーが発生しました',
        code: data['code']?.toString(),
        statusCode: response.statusCode,
      );
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiError(
          message: '接続がタイムアウトしました',
          code: 'TIMEOUT',
        );
      case DioExceptionType.connectionError:
        return ApiError(
          message: 'ネットワークに接続できません',
          code: 'CONNECTION_ERROR',
        );
      case DioExceptionType.cancel:
        return ApiError(
          message: 'リクエストがキャンセルされました',
          code: 'CANCELLED',
        );
      default:
        return ApiError(
          message: '予期しないエラーが発生しました',
          code: 'UNKNOWN',
          statusCode: response?.statusCode,
        );
    }
  }

  @override
  String toString() => 'ApiError: $message (code: $code, status: $statusCode)';
}
