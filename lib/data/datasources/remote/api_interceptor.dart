import 'dart:async';
import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/utils/logger.dart';

/// トークンリフレッシュコールバック
typedef TokenRefreshCallback = Future<String?> Function(String? refreshToken);

/// 認証インターセプター
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    String? deviceId,
    this.onTokenRefresh,
    this.onTokenExpired,
  }) : _deviceId = deviceId;

  String? _deviceId;
  String? _accessToken;
  String? _refreshToken;

  /// トークンリフレッシュ時に呼ばれるコールバック
  final TokenRefreshCallback? onTokenRefresh;

  /// トークン期限切れ時（リフレッシュ失敗含む）に呼ばれるコールバック
  final VoidCallback? onTokenExpired;

  // リフレッシュ中フラグ（重複リフレッシュ防止）
  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;

  /// デバイスIDを設定
  void setDeviceId(String? id) {
    _deviceId = id;
  }

  /// アクセストークンを設定
  void setAccessToken(String? token) {
    _accessToken = token;
  }

  /// リフレッシュトークンを設定
  void setRefreshToken(String? token) {
    _refreshToken = token;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // デバイスIDをヘッダーに追加
    if (_deviceId != null) {
      options.headers[ApiConstants.deviceIdHeader] = _deviceId;
    }

    // アクセストークンをヘッダーに追加
    if (_accessToken != null) {
      options.headers[ApiConstants.authorizationHeader] = 'Bearer $_accessToken';
    }

    // タイムスタンプを追加（リプレイ攻撃防止）
    // 注意: RequestSignerInterceptorでも追加されるため、署名用は別途設定
    options.headers['X-Request-Time'] = DateTime.now().millisecondsSinceEpoch.toString();

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // 401エラーの場合、トークンリフレッシュを試行
    if (err.response?.statusCode == 401) {
      // リフレッシュトークンがある場合のみ自動リフレッシュ
      if (_refreshToken != null && onTokenRefresh != null) {
        try {
          final newToken = await _refreshAccessToken();

          if (newToken != null) {
            // 新しいトークンでリクエストを再試行
            final options = err.requestOptions;
            options.headers[ApiConstants.authorizationHeader] = 'Bearer $newToken';

            logger.i('Retrying request with refreshed token');
            final response = await Dio().fetch<dynamic>(options);
            handler.resolve(response);
            return;
          }
        } catch (e, stackTrace) {
          logger.e(
            'Token refresh failed',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }

      // リフレッシュ失敗またはリフレッシュトークンなし
      _accessToken = null;
      _refreshToken = null;
      logger.w('Access token cleared due to 401 error');
      onTokenExpired?.call();
    }

    handler.next(err);
  }

  /// アクセストークンをリフレッシュ
  Future<String?> _refreshAccessToken() async {
    // 既にリフレッシュ中の場合は完了を待つ
    if (_isRefreshing) {
      logger.d('Token refresh already in progress, waiting...');
      return _refreshCompleter?.future;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<String?>();

    try {
      logger.i('Starting token refresh');
      final newToken = await onTokenRefresh?.call(_refreshToken);

      if (newToken != null) {
        _accessToken = newToken;
        logger.i('Token refresh successful');
      } else {
        logger.w('Token refresh returned null');
      }

      _refreshCompleter?.complete(newToken);
      return newToken;
    } catch (e) {
      _refreshCompleter?.completeError(e);
      rethrow;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }
}

/// コールバック型定義
typedef VoidCallback = void Function();

/// エラーレスポンスのパース
class ApiError {
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

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => 'ApiError: $message (code: $code, status: $statusCode)';
}
