import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../../core/utils/logger.dart';

/// リクエスト署名インターセプター
/// HMAC-SHA256を使用してリクエストに署名を追加
class RequestSignerInterceptor extends Interceptor {
  RequestSignerInterceptor({required this.signingKey});

  final String signingKey;
  final Random _random = Random.secure();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    try {
      // タイムスタンプ（ミリ秒）
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      // ノンス（ランダムな文字列）
      final nonce = _generateNonce();

      // 署名対象のデータを構築
      final bodyString = _getBodyString(options);
      final signatureData = '$timestamp:$nonce:$bodyString';

      // HMAC-SHA256で署名
      final signature = _sign(signatureData);

      // ヘッダーに追加
      options.headers['X-Timestamp'] = timestamp;
      options.headers['X-Nonce'] = nonce;
      options.headers['X-Signature'] = signature;

      handler.next(options);
    } catch (e, stackTrace) {
      logger.e(
        'Request signing failed',
        error: e,
        stackTrace: stackTrace,
      );
      // 署名に失敗してもリクエストは続行
      handler.next(options);
    }
  }

  /// ノンスを生成（32文字のランダム文字列）
  String _generateNonce() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(32, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  /// リクエストボディを文字列化
  String _getBodyString(RequestOptions options) {
    final data = options.data;

    if (data == null) {
      return '';
    }

    if (data is String) {
      return data;
    }

    if (data is Map || data is List) {
      return jsonEncode(data);
    }

    if (data is FormData) {
      // FormDataの場合は空文字列（バイナリデータは署名対象外）
      return '';
    }

    return data.toString();
  }

  /// HMAC-SHA256で署名
  String _sign(String data) {
    final key = utf8.encode(signingKey);
    final bytes = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return digest.toString();
  }
}

/// リクエスト署名ユーティリティ
class RequestSigner {
  RequestSigner({required this.signingKey});

  final String signingKey;

  /// 署名データを生成
  SignatureData generateSignature(String body) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final nonce = _generateNonce();
    final signatureData = '$timestamp:$nonce:$body';
    final signature = _sign(signatureData);

    return SignatureData(
      timestamp: timestamp,
      nonce: nonce,
      signature: signature,
    );
  }

  /// 署名を検証
  bool verifySignature({
    required String timestamp,
    required String nonce,
    required String body,
    required String signature,
    Duration maxAge = const Duration(minutes: 5),
  }) {
    // タイムスタンプの有効期限チェック
    final requestTime = int.tryParse(timestamp);
    if (requestTime == null) {
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final timeDiff = (now - requestTime).abs();
    if (timeDiff > maxAge.inMilliseconds) {
      logger.w('Signature expired: timestamp=$timestamp, now=$now');
      return false;
    }

    // 署名の検証
    final signatureData = '$timestamp:$nonce:$body';
    final expectedSignature = _sign(signatureData);

    if (signature != expectedSignature) {
      logger.w('Signature mismatch');
      return false;
    }

    return true;
  }

  String _generateNonce() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String _sign(String data) {
    final key = utf8.encode(signingKey);
    final bytes = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return digest.toString();
  }
}

/// 署名データ
class SignatureData {
  const SignatureData({
    required this.timestamp,
    required this.nonce,
    required this.signature,
  });

  final String timestamp;
  final String nonce;
  final String signature;

  Map<String, String> toHeaders() {
    return {
      'X-Timestamp': timestamp,
      'X-Nonce': nonce,
      'X-Signature': signature,
    };
  }
}
