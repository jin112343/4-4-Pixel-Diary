import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/logger.dart';
import 'api_interceptor.dart';

/// APIクライアント
class ApiClient {
  late final Dio _dio;
  final String? _deviceId;

  ApiClient({String? deviceId}) : _deviceId = deviceId {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: Duration(seconds: AppConstants.apiTimeoutSeconds),
        receiveTimeout: Duration(seconds: AppConstants.apiTimeoutSeconds),
        headers: {
          'Content-Type': ApiConstants.contentType,
          'Accept': ApiConstants.contentType,
        },
      ),
    );

    _dio.interceptors.addAll([
      AuthInterceptor(deviceId: _deviceId),
      LoggingInterceptor(),
      RetryInterceptor(dio: _dio),
    ]);
  }

  /// GET リクエスト
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// POST リクエスト
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// PUT リクエスト
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// DELETE リクエスト
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }
}

/// ロギングインターセプター
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    logger.d('API Request: ${options.method} ${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    logger.d('API Response: ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    logger.e(
      'API Error: ${err.response?.statusCode} ${err.requestOptions.path}',
      error: err,
    );
    handler.next(err);
  }
}

/// リトライインターセプター
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;

  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
  });

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final retryCount = options.extra['retryCount'] ?? 0;

    // リトライ可能なエラーかチェック
    if (_shouldRetry(err) && retryCount < maxRetries) {
      options.extra['retryCount'] = retryCount + 1;
      logger.w('Retrying request (${retryCount + 1}/$maxRetries): ${options.path}');

      try {
        final response = await dio.fetch(options);
        handler.resolve(response);
        return;
      } catch (e) {
        // リトライ失敗、次のエラーハンドラへ
      }
    }

    handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        (err.response?.statusCode != null && err.response!.statusCode! >= 500);
  }
}
