/// API関連定数
class ApiConstants {
  ApiConstants._();

  /// ベースURL（本番環境のみ）
  static const String baseUrl =
      'https://mipptdxyc9.execute-api.ap-northeast-1.amazonaws.com/v1';

  /// エンドポイント
  static const String exchangeEndpoint = '/pixelart/exchange';
  static const String albumEndpoint = '/album';
  static const String postsEndpoint = '/posts';
  static const String commentsEndpoint = '/comments';

  /// ヘッダー
  static const String contentType = 'application/json';
  static const String authorizationHeader = 'Authorization';
  static const String deviceIdHeader = 'X-Device-ID';
}
