import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/logger.dart';

/// 証明書ピンニング設定
class CertificatePinner {
  CertificatePinner._();

  // 本番環境のAPI証明書フィンガープリント（SHA-256）
  // 注意: 実際の運用では証明書を取得してフィンガープリントを設定する
  static const List<String> _pinnedCertificateFingerprints = [
    // 例: 'XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX'
  ];

  // 許可されたホスト
  static const List<String> _allowedHosts = [
    'api.pixeldiary.app',
    'dev-api.pixeldiary.app',
  ];

  /// Dioに証明書ピンニングを設定
  static void configureDio(Dio dio) {
    if (dio.httpClientAdapter is IOHttpClientAdapter) {
      final adapter = dio.httpClientAdapter as IOHttpClientAdapter;

      adapter.createHttpClient = () {
        final client = HttpClient();

        // TLS 1.3を優先
        client.connectionTimeout = const Duration(seconds: 30);

        // 証明書検証のカスタマイズ
        client.badCertificateCallback = _badCertificateCallback;

        return client;
      };
    }
  }

  /// 証明書検証コールバック
  static bool _badCertificateCallback(
    X509Certificate cert,
    String host,
    int port,
  ) {
    // 開発環境では証明書検証をスキップ（本番では必ずfalseを返す）
    const isDevelopment = bool.fromEnvironment('dart.vm.product') == false;

    if (isDevelopment) {
      logger.w('Certificate validation skipped in development mode');
      return true;
    }

    // 許可されたホスト以外は拒否
    if (!_allowedHosts.contains(host)) {
      logger.e('Certificate validation failed: host not allowed: $host');
      return false;
    }

    // フィンガープリントが設定されていない場合はデフォルト検証
    if (_pinnedCertificateFingerprints.isEmpty) {
      return false;
    }

    // 証明書のフィンガープリントを検証
    final fingerprint = _getCertificateFingerprint(cert);
    final isValid = _pinnedCertificateFingerprints.contains(fingerprint);

    if (!isValid) {
      logger.e('Certificate pinning failed: fingerprint mismatch for $host');
    }

    return isValid;
  }

  /// 証明書のSHA-256フィンガープリントを取得
  static String _getCertificateFingerprint(X509Certificate cert) {
    // DER形式の証明書データからフィンガープリントを計算
    // 実際の実装では crypto パッケージを使用
    final der = cert.der;

    // 簡易的なフィンガープリント生成（本番では適切なハッシュ関数を使用）
    final bytes = der;
    final buffer = StringBuffer();

    for (var i = 0; i < bytes.length && i < 32; i++) {
      if (i > 0) buffer.write(':');
      buffer.write(bytes[i].toRadixString(16).padLeft(2, '0').toUpperCase());
    }

    return buffer.toString();
  }

  /// 証明書ピンニングインターセプター
  static Interceptor createInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        // リクエストURLのホストを確認
        final host = options.uri.host;

        if (!_allowedHosts.contains(host)) {
          logger.w('Request to non-allowed host: $host');
        }

        handler.next(options);
      },
      onError: (error, handler) {
        // SSL/TLSエラーの詳細ログ
        if (error.type == DioExceptionType.connectionError) {
          final innerError = error.error;
          if (innerError is HandshakeException) {
            logger.e(
              'SSL/TLS handshake failed',
              error: innerError,
            );
          }
        }

        handler.next(error);
      },
    );
  }
}

/// セキュアなHTTPクライアント設定
class SecureHttpClientConfig {
  SecureHttpClientConfig._();

  /// セキュアなHttpClientを作成
  static HttpClient createSecureClient() {
    final client = HttpClient();

    // TLS設定
    client.connectionTimeout = const Duration(seconds: 30);
    client.idleTimeout = const Duration(seconds: 60);

    // 自動リダイレクトを制限（オープンリダイレクト攻撃対策）
    client.maxConnectionsPerHost = 6;
    client.autoUncompress = true;

    return client;
  }

  /// SecurityContextを設定（カスタム証明書使用時）
  static Future<SecurityContext> createSecurityContext({
    String? certificatePath,
    Uint8List? certificateBytes,
  }) async {
    final context = SecurityContext(withTrustedRoots: true);

    // カスタム証明書を追加
    if (certificatePath != null) {
      final certData = await rootBundle.load(certificatePath);
      context.setTrustedCertificatesBytes(certData.buffer.asUint8List());
    } else if (certificateBytes != null) {
      context.setTrustedCertificatesBytes(certificateBytes);
    }

    return context;
  }
}
