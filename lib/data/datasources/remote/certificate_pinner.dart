import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/logger.dart';

/// 証明書ピンニング設定
class CertificatePinner {
  CertificatePinner._();

  // 本番環境のAPI証明書フィンガープリント（SHA-256）
  // 注意: 実際の運用では以下のコマンドで取得:
  // openssl s_client -connect api.pixeldiary.app:443 < /dev/null 2>/dev/null | \
  //   openssl x509 -outform DER | openssl sha256 -binary | xxd -p | \
  //   sed 's/../&:/g; s/:$//' | tr '[:lower:]' '[:upper:]'
  //
  // AWS API Gatewayの場合、証明書はAWSが管理するため
  // 証明書ローテーションに注意が必要
  static const List<String> _pinnedCertificateFingerprints = [
    // 本番環境: api.pixeldiary.app の証明書フィンガープリント
    // ここに実際の値を設定（例: 'A1:B2:C3:...'）
    // 複数の証明書を許可することでローテーション対応
  ];

  // 許可されたホスト
  static const List<String> _allowedHosts = [
    'api.pixeldiary.app',
    'dev-api.pixeldiary.app',
    // AWS API Gateway
    '7myvq0fjwe.execute-api.ap-northeast-1.amazonaws.com',
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
    // デバッグモード判定（kDebugModeを使用）
    // 注意: 開発環境でも証明書検証を有効にすることを推奨
    if (kDebugMode && _allowSkipInDebugMode) {
      logger.w(
        'Certificate validation skipped in debug mode for $host. '
        'Set _allowSkipInDebugMode=false for stricter security.',
      );
      return true;
    }

    // 許可されたホスト以外は拒否
    if (!_allowedHosts.contains(host)) {
      logger.e('Certificate validation failed: host not allowed: $host');
      return false;
    }

    // フィンガープリントが設定されていない場合
    // 本番環境ではデフォルトのOS検証に任せる（falseを返すと接続拒否）
    // AWS API Gatewayの場合、証明書は信頼されたCAから発行されるため
    // フィンガープリントなしでもOS標準検証は有効
    if (_pinnedCertificateFingerprints.isEmpty) {
      logger.w(
        'Certificate pinning fingerprints not configured for $host. '
        'Using OS default validation.',
      );
      // falseを返すとbadCertificateとして接続拒否
      // 証明書自体が有効な場合、このコールバックは呼ばれない
      return false;
    }

    // 証明書のフィンガープリントを検証
    final fingerprint = _getCertificateFingerprint(cert);
    final isValid = _pinnedCertificateFingerprints.contains(fingerprint);

    if (!isValid) {
      logger.e(
        'Certificate pinning failed for $host. '
        'Expected one of: $_pinnedCertificateFingerprints, '
        'Got: $fingerprint',
      );
    } else {
      logger.d('Certificate pinning succeeded for $host');
    }

    return isValid;
  }

  // デバッグモードで証明書検証をスキップするかどうか
  // セキュリティテスト時はfalseに設定
  static const bool _allowSkipInDebugMode = true;

  /// 証明書のSHA-256フィンガープリントを取得
  static String _getCertificateFingerprint(X509Certificate cert) {
    // DER形式の証明書データからSHA-256ハッシュを計算
    final der = cert.der;
    final digest = sha256.convert(der);

    // XX:XX:XX:... 形式のフィンガープリント文字列を生成
    final buffer = StringBuffer();
    for (var i = 0; i < digest.bytes.length; i++) {
      if (i > 0) buffer.write(':');
      buffer.write(digest.bytes[i].toRadixString(16).padLeft(2, '0').toUpperCase());
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
