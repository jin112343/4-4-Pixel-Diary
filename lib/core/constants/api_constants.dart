/// API関連定数
class ApiConstants {
  ApiConstants._();

  /// ベースURL（本番環境）
  static const String baseUrl = 'https://api.pixeldiary.app/v1';

  /// ベースURL（開発環境）
  static const String devBaseUrl = 'https://dev-api.pixeldiary.app/v1';

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
