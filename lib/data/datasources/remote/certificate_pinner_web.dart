import 'package:dio/dio.dart';

/// Web用証明書ピンニング（スタブ）
/// Webでは証明書ピンニングはブラウザが処理するため、何もしない
class CertificatePinner {
  CertificatePinner._();

  /// Dioに証明書ピンニングを設定（Web版では何もしない）
  static void configureDio(Dio dio) {
    // Webではブラウザが証明書検証を行うため、何もしない
  }

  /// 証明書ピンニングインターセプター（Web版では何もしない）
  static Interceptor createInterceptor() {
    return InterceptorsWrapper();
  }
}
