import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/utils/logger.dart';

/// リモートモデレーションサービス
/// サーバーサイドでNGワードフィルタリングを実行
///
/// メリット:
/// 1. NGワードリストの動的更新（アプリ更新不要）
/// 2. リバースエンジニアリング対策（リストが見えない）
/// 3. AI/ML分析をサーバーで実行可能
/// 4. ユーザーがローカルフィルタを回避できない
class RemoteModerationService {
  final Dio _dio;
  final String _baseUrl;

  /// キャッシュ（同じテキストの再チェックを避ける）
  final Map<String, RemoteModerationResult> _cache = {};
  static const int _maxCacheSize = 200;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// タイムアウト設定
  static const Duration _timeout = Duration(seconds: 5);

  RemoteModerationService({
    Dio? dio,
    String? baseUrl,
  })  : _dio = dio ?? Dio(),
        _baseUrl = baseUrl ?? ApiConstants.baseUrl;

  // ============================================================
  // メインAPI呼び出し
  // ============================================================

  /// テキストをサーバーでモデレーションチェック
  Future<RemoteModerationResult> check(String text) async {
    if (text.trim().isEmpty) {
      return RemoteModerationResult.clean();
    }

    // キャッシュチェック
    final cacheKey = _getCacheKey(text);
    final cached = _getFromCache(cacheKey);
    if (cached != null) {
      return cached;
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/api/v1/moderation/check',
        data: {
          'text': text,
          'strictness': 'nintendo', // 常に最強モード
          'include_categories': true,
          'include_details': true,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
          sendTimeout: _timeout,
          receiveTimeout: _timeout,
        ),
      );

      final result = RemoteModerationResult.fromJson(response.data!);
      _addToCache(cacheKey, result);
      return result;
    } on DioException catch (e) {
      logger.e(
        'RemoteModerationService: API呼び出し失敗',
        error: e.message,
        stackTrace: e.stackTrace,
      );

      // APIエラー時はフォールバック結果を返す
      // 安全のため、エラー時はブロック推奨
      return RemoteModerationResult.error(
        'サーバーエラー: ${e.message}',
        shouldBlockOnError: true,
      );
    } catch (e, stackTrace) {
      logger.e(
        'RemoteModerationService: 予期しないエラー',
        error: e,
        stackTrace: stackTrace,
      );
      return RemoteModerationResult.error(
        '予期しないエラー',
        shouldBlockOnError: true,
      );
    }
  }

  /// 複数テキストをバッチチェック
  Future<List<RemoteModerationResult>> checkBatch(List<String> texts) async {
    if (texts.isEmpty) {
      return [];
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/api/v1/moderation/check-batch',
        data: {
          'texts': texts,
          'strictness': 'nintendo',
        },
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final results = (response.data!['results'] as List<dynamic>)
          .map((r) => RemoteModerationResult.fromJson(r as Map<String, dynamic>))
          .toList();

      return results;
    } catch (e) {
      logger.e('RemoteModerationService: バッチチェック失敗', error: e);
      // エラー時は各テキストを個別にチェック
      return Future.wait(texts.map((t) => check(t)));
    }
  }

  /// クイックチェック（ブロックかどうかのみ判定）
  Future<bool> shouldBlock(String text) async {
    final result = await check(text);
    return result.shouldBlock;
  }

  // ============================================================
  // NGワードリスト同期（オプション）
  // ============================================================

  /// サーバーからNGワードリストの更新情報を取得
  Future<NgWordListUpdate?> fetchNgWordListUpdate({
    String? currentVersion,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/api/v1/moderation/ng-words/update',
        queryParameters: {
          if (currentVersion != null) 'current_version': currentVersion,
        },
      );

      if (response.statusCode == 304) {
        // 更新なし
        return null;
      }

      return NgWordListUpdate.fromJson(response.data!);
    } catch (e) {
      logger.e('RemoteModerationService: NGワードリスト取得失敗', error: e);
      return null;
    }
  }

  // ============================================================
  // キャッシュ管理
  // ============================================================

  String _getCacheKey(String text) {
    return text.hashCode.toString();
  }

  RemoteModerationResult? _getFromCache(String key) {
    final cached = _cache[key];
    if (cached == null) return null;

    // 期限切れチェック
    if (DateTime.now().difference(cached.timestamp) > _cacheExpiry) {
      _cache.remove(key);
      return null;
    }

    return cached;
  }

  void _addToCache(String key, RemoteModerationResult result) {
    // キャッシュサイズ管理
    if (_cache.length >= _maxCacheSize) {
      // 古いエントリを半分削除
      final keysToRemove = _cache.keys.take(_maxCacheSize ~/ 2).toList();
      for (final k in keysToRemove) {
        _cache.remove(k);
      }
    }
    _cache[key] = result;
  }

  /// キャッシュをクリア
  void clearCache() {
    _cache.clear();
  }
}

// ============================================================
// データクラス
// ============================================================

/// リモートモデレーション結果
class RemoteModerationResult {
  /// テキストがクリーンか
  final bool isClean;

  /// ブロックすべきか
  final bool shouldBlock;

  /// 検出されたカテゴリ
  final List<String> detectedCategories;

  /// 検出されたNGワード（マスク済み）
  final List<String> detectedWords;

  /// リスクスコア（0.0-1.0）
  final double riskScore;

  /// 詳細メッセージ（開発用）
  final String? detailMessage;

  /// ユーザー向けメッセージ
  final String? userMessage;

  /// エラーかどうか
  final bool isError;

  /// エラーメッセージ
  final String? errorMessage;

  /// タイムスタンプ（キャッシュ用）
  final DateTime timestamp;

  RemoteModerationResult({
    required this.isClean,
    required this.shouldBlock,
    this.detectedCategories = const [],
    this.detectedWords = const [],
    this.riskScore = 0.0,
    this.detailMessage,
    this.userMessage,
    this.isError = false,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// クリーン結果
  factory RemoteModerationResult.clean() {
    return RemoteModerationResult(
      isClean: true,
      shouldBlock: false,
      riskScore: 0.0,
    );
  }

  /// エラー結果
  factory RemoteModerationResult.error(
    String message, {
    bool shouldBlockOnError = true,
  }) {
    return RemoteModerationResult(
      isClean: !shouldBlockOnError,
      shouldBlock: shouldBlockOnError,
      isError: true,
      errorMessage: message,
      userMessage: 'コンテンツの確認中にエラーが発生しました',
      riskScore: shouldBlockOnError ? 1.0 : 0.0,
    );
  }

  /// JSONからパース
  factory RemoteModerationResult.fromJson(Map<String, dynamic> json) {
    return RemoteModerationResult(
      isClean: json['is_clean'] as bool? ?? false,
      shouldBlock: json['should_block'] as bool? ?? true,
      detectedCategories: (json['detected_categories'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      detectedWords: (json['detected_words'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      riskScore: (json['risk_score'] as num?)?.toDouble() ?? 0.0,
      detailMessage: json['detail_message'] as String?,
      userMessage: json['user_message'] as String?,
      isError: json['is_error'] as bool? ?? false,
      errorMessage: json['error_message'] as String?,
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'is_clean': isClean,
      'should_block': shouldBlock,
      'detected_categories': detectedCategories,
      'detected_words': detectedWords,
      'risk_score': riskScore,
      'detail_message': detailMessage,
      'user_message': userMessage,
      'is_error': isError,
      'error_message': errorMessage,
    };
  }

  @override
  String toString() {
    if (isError) {
      return 'RemoteModerationResult(error: $errorMessage)';
    }
    return 'RemoteModerationResult('
        'clean: $isClean, '
        'block: $shouldBlock, '
        'risk: ${(riskScore * 100).toInt()}%, '
        'categories: $detectedCategories)';
  }
}

/// NGワードリスト更新情報
class NgWordListUpdate {
  /// バージョン
  final String version;

  /// 更新日時
  final DateTime updatedAt;

  /// 追加されたワード数
  final int addedCount;

  /// 削除されたワード数
  final int removedCount;

  /// ダウンロードURL（差分更新用）
  final String? downloadUrl;

  const NgWordListUpdate({
    required this.version,
    required this.updatedAt,
    this.addedCount = 0,
    this.removedCount = 0,
    this.downloadUrl,
  });

  factory NgWordListUpdate.fromJson(Map<String, dynamic> json) {
    return NgWordListUpdate(
      version: json['version'] as String,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      addedCount: json['added_count'] as int? ?? 0,
      removedCount: json['removed_count'] as int? ?? 0,
      downloadUrl: json['download_url'] as String?,
    );
  }
}
