import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/utils/logger.dart';
import '../../core/utils/text_normalizer.dart';

/// AI/機械学習ベースのコンテンツモデレーションサービス
/// Perspective API と AWS Comprehend をサポート
///
/// 使用方法:
/// 1. APIキーを設定（SecureStorageから取得）
/// 2. analyze() でテキストを分析
/// 3. スコアに基づいてブロック判定
class AiModerationService {
  AiModerationService._();

  static AiModerationService? _instance;
  static AiModerationService get instance {
    _instance ??= AiModerationService._();
    return _instance!;
  }

  // ============================================================
  // 設定
  // ============================================================

  /// Perspective API キー
  String? _perspectiveApiKey;

  /// AWS Comprehend 設定
  String? _awsAccessKeyId;
  String? _awsSecretAccessKey;
  String? _awsRegion;

  /// デフォルトのスコア閾値（これを超えると有害と判定）
  double _toxicityThreshold = 0.7;
  double _severeToxicityThreshold = 0.5;

  /// APIタイムアウト
  Duration _timeout = const Duration(seconds: 5);

  /// キャッシュ（同じテキストの再分析を避ける）
  final Map<String, ModerationResult> _cache = {};
  static const int _maxCacheSize = 100;

  // ============================================================
  // 初期化
  // ============================================================

  /// Perspective API を設定
  void configurePerspective({
    required String apiKey,
    double? toxicityThreshold,
    double? severeToxicityThreshold,
    Duration? timeout,
  }) {
    _perspectiveApiKey = apiKey;
    if (toxicityThreshold != null) _toxicityThreshold = toxicityThreshold;
    if (severeToxicityThreshold != null) {
      _severeToxicityThreshold = severeToxicityThreshold;
    }
    if (timeout != null) _timeout = timeout;
    logger.i('AiModerationService: Perspective API configured');
  }

  /// AWS Comprehend を設定
  void configureAwsComprehend({
    required String accessKeyId,
    required String secretAccessKey,
    String region = 'us-east-1',
    Duration? timeout,
  }) {
    _awsAccessKeyId = accessKeyId;
    _awsSecretAccessKey = secretAccessKey;
    _awsRegion = region;
    if (timeout != null) _timeout = timeout;
    logger.i('AiModerationService: AWS Comprehend configured');
  }

  /// 閾値を設定
  void setThresholds({
    double? toxicity,
    double? severeToxicity,
  }) {
    if (toxicity != null) _toxicityThreshold = toxicity;
    if (severeToxicity != null) _severeToxicityThreshold = severeToxicity;
  }

  // ============================================================
  // メイン分析メソッド
  // ============================================================

  /// テキストを分析してモデレーション結果を返す
  /// 利用可能なAPIを自動選択
  Future<ModerationResult> analyze(String text) async {
    if (text.isEmpty) {
      return ModerationResult.clean();
    }

    // キャッシュチェック
    final cacheKey = text.hashCode.toString();
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    ModerationResult result;

    // 言語を検出してAPIを選択
    final language = TextNormalizer.detectPrimaryLanguage(text);

    // Perspective APIを優先（日本語対応）
    if (_perspectiveApiKey != null) {
      result = await _analyzeWithPerspective(text, language);
    }
    // AWS Comprehendは英語のみ
    else if (_awsAccessKeyId != null && language == TextLanguage.english) {
      result = await _analyzeWithComprehend(text);
    }
    // APIが設定されていない場合
    else {
      logger.w('AiModerationService: No API configured, skipping AI analysis');
      return ModerationResult.skipped();
    }

    // キャッシュに保存
    _cacheResult(cacheKey, result);

    return result;
  }

  /// 複数のテキストをバッチ分析
  Future<List<ModerationResult>> analyzeBatch(List<String> texts) async {
    final results = <ModerationResult>[];
    for (final text in texts) {
      results.add(await analyze(text));
    }
    return results;
  }

  /// クイックチェック（閾値超えのみ判定）
  Future<bool> isToxic(String text) async {
    final result = await analyze(text);
    return result.isToxic(_toxicityThreshold);
  }

  // ============================================================
  // Perspective API
  // ============================================================

  /// Perspective APIでテキストを分析
  Future<ModerationResult> _analyzeWithPerspective(
    String text,
    TextLanguage language,
  ) async {
    if (_perspectiveApiKey == null) {
      return ModerationResult.error('Perspective API key not configured');
    }

    try {
      final uri = Uri.parse(
        'https://commentanalyzer.googleapis.com/v1alpha1/comments:analyze'
        '?key=$_perspectiveApiKey',
      );

      // 言語コード
      final languageCode = language == TextLanguage.japanese ? 'ja' : 'en';

      // リクエストボディ
      final requestBody = <String, dynamic>{
        'comment': <String, dynamic>{'text': text},
        'languages': [languageCode],
        'requestedAttributes': <String, dynamic>{
          'TOXICITY': <String, dynamic>{},
          'SEVERE_TOXICITY': <String, dynamic>{},
          'IDENTITY_ATTACK': <String, dynamic>{},
          'INSULT': <String, dynamic>{},
          'PROFANITY': <String, dynamic>{},
          'THREAT': <String, dynamic>{},
        },
        'doNotStore': true, // プライバシー保護
      };

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return _parsePerspectiveResponse(data);
      } else {
        logger.e(
          'Perspective API error: ${response.statusCode}',
          error: response.body,
        );
        return ModerationResult.error(
          'Perspective API error: ${response.statusCode}',
        );
      }
    } catch (e, stackTrace) {
      logger.e(
        'Perspective API exception',
        error: e,
        stackTrace: stackTrace,
      );
      return ModerationResult.error('Perspective API exception: $e');
    }
  }

  /// Perspective APIレスポンスをパース
  ModerationResult _parsePerspectiveResponse(Map<String, dynamic> data) {
    final attributes = data['attributeScores'] as Map<String, dynamic>?;
    if (attributes == null) {
      return ModerationResult.error('Invalid Perspective API response');
    }

    double getScore(String attribute) {
      final attr = attributes[attribute] as Map<String, dynamic>?;
      final summary = attr?['summaryScore'] as Map<String, dynamic>?;
      return (summary?['value'] as num?)?.toDouble() ?? 0.0;
    }

    final scores = ModerationScores(
      toxicity: getScore('TOXICITY'),
      severeToxicity: getScore('SEVERE_TOXICITY'),
      identityAttack: getScore('IDENTITY_ATTACK'),
      insult: getScore('INSULT'),
      profanity: getScore('PROFANITY'),
      threat: getScore('THREAT'),
    );

    return ModerationResult(
      source: ModerationSource.perspective,
      scores: scores,
      status: ModerationStatus.success,
    );
  }

  // ============================================================
  // AWS Comprehend
  // ============================================================

  /// AWS Comprehendでテキストを分析（Toxicity Detection）
  Future<ModerationResult> _analyzeWithComprehend(String text) async {
    if (_awsAccessKeyId == null || _awsSecretAccessKey == null) {
      return ModerationResult.error('AWS credentials not configured');
    }

    // 注意: 実際の実装ではAWS SDK for Dartを使用するか、
    // Lambda経由でComprehendを呼び出す必要があります。
    // ここでは簡略化のため、直接REST APIを呼び出す形式で示します。

    try {
      // AWS Comprehend Toxicity Detection API
      // 実際の実装ではaws_signatureなどで署名が必要
      // ignore: unused_local_variable
      final _ = Uri.parse(
        'https://comprehend.$_awsRegion.amazonaws.com/',
      );

      // ignore: unused_local_variable
      final __ = <String, dynamic>{
        'TextSegments': [
          <String, dynamic>{'Text': text}
        ],
        'LanguageCode': 'en',
      };

      // AWS署名v4が必要（簡略化のため省略）
      // 実際の実装では aws_common パッケージを使用

      // プレースホルダーレスポンス
      // 実運用ではLambda経由またはAWS SDK使用を推奨
      logger.w(
        'AWS Comprehend: Direct API call requires AWS Signature. '
        'Consider using Lambda proxy.',
      );

      return ModerationResult.skipped();
    } catch (e, stackTrace) {
      logger.e(
        'AWS Comprehend exception',
        error: e,
        stackTrace: stackTrace,
      );
      return ModerationResult.error('AWS Comprehend exception: $e');
    }
  }

  // ============================================================
  // バックエンド経由の分析
  // ============================================================

  /// バックエンドAPIを経由してAI分析を実行
  /// (AWS Lambda + Comprehend/Perspective を推奨)
  Future<ModerationResult> analyzeViaBackend(
    String text, {
    required String backendUrl,
    Map<String, String>? headers,
  }) async {
    try {
      final uri = Uri.parse(backendUrl);

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              ...?headers,
            },
            body: jsonEncode({
              'text': text,
              'language': TextNormalizer.detectPrimaryLanguage(text).name,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ModerationResult.fromJson(data);
      } else {
        return ModerationResult.error(
          'Backend API error: ${response.statusCode}',
        );
      }
    } catch (e, stackTrace) {
      logger.e(
        'Backend moderation exception',
        error: e,
        stackTrace: stackTrace,
      );
      return ModerationResult.error('Backend exception: $e');
    }
  }

  // ============================================================
  // キャッシュ管理
  // ============================================================

  void _cacheResult(String key, ModerationResult result) {
    if (_cache.length >= _maxCacheSize) {
      // 古いエントリを削除
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

  // ============================================================
  // 統計
  // ============================================================

  /// サービス状態を取得
  ModerationServiceStatus getStatus() {
    return ModerationServiceStatus(
      perspectiveConfigured: _perspectiveApiKey != null,
      comprehendConfigured:
          _awsAccessKeyId != null && _awsSecretAccessKey != null,
      toxicityThreshold: _toxicityThreshold,
      severeToxicityThreshold: _severeToxicityThreshold,
      cacheSize: _cache.length,
    );
  }
}

// ============================================================
// データクラス
// ============================================================

/// モデレーションソース
enum ModerationSource {
  perspective,
  comprehend,
  backend,
  local,
  unknown,
}

/// モデレーションステータス
enum ModerationStatus {
  success,
  error,
  skipped,
}

/// モデレーションスコア
class ModerationScores {
  final double toxicity;
  final double severeToxicity;
  final double identityAttack;
  final double insult;
  final double profanity;
  final double threat;

  // AWS Comprehend用の追加スコア
  final double? hateSpeeech;
  final double? graphic;
  final double? harassmentOrAbuse;
  final double? sexualContent;
  final double? violenceOrThreat;

  const ModerationScores({
    this.toxicity = 0.0,
    this.severeToxicity = 0.0,
    this.identityAttack = 0.0,
    this.insult = 0.0,
    this.profanity = 0.0,
    this.threat = 0.0,
    this.hateSpeeech,
    this.graphic,
    this.harassmentOrAbuse,
    this.sexualContent,
    this.violenceOrThreat,
  });

  /// 最大スコアを取得
  double get maxScore => [
        toxicity,
        severeToxicity,
        identityAttack,
        insult,
        profanity,
        threat,
      ].reduce((a, b) => a > b ? a : b);

  /// 重大スコア（暴力・差別系）の最大値
  double get maxSevereScore => [
        severeToxicity,
        identityAttack,
        threat,
      ].reduce((a, b) => a > b ? a : b);

  factory ModerationScores.fromJson(Map<String, dynamic> json) {
    return ModerationScores(
      toxicity: (json['toxicity'] as num?)?.toDouble() ?? 0.0,
      severeToxicity: (json['severeToxicity'] as num?)?.toDouble() ?? 0.0,
      identityAttack: (json['identityAttack'] as num?)?.toDouble() ?? 0.0,
      insult: (json['insult'] as num?)?.toDouble() ?? 0.0,
      profanity: (json['profanity'] as num?)?.toDouble() ?? 0.0,
      threat: (json['threat'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'toxicity': toxicity,
        'severeToxicity': severeToxicity,
        'identityAttack': identityAttack,
        'insult': insult,
        'profanity': profanity,
        'threat': threat,
      };

  @override
  String toString() {
    return 'ModerationScores('
        'toxicity: ${toxicity.toStringAsFixed(2)}, '
        'severeToxicity: ${severeToxicity.toStringAsFixed(2)}, '
        'identityAttack: ${identityAttack.toStringAsFixed(2)}, '
        'insult: ${insult.toStringAsFixed(2)}, '
        'profanity: ${profanity.toStringAsFixed(2)}, '
        'threat: ${threat.toStringAsFixed(2)})';
  }
}

/// モデレーション結果
class ModerationResult {
  final ModerationSource source;
  final ModerationScores? scores;
  final ModerationStatus status;
  final String? errorMessage;
  final DateTime timestamp;

  ModerationResult({
    required this.source,
    this.scores,
    required this.status,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// クリーン結果
  factory ModerationResult.clean() => ModerationResult(
        source: ModerationSource.local,
        scores: const ModerationScores(),
        status: ModerationStatus.success,
      );

  /// スキップ結果
  factory ModerationResult.skipped() => ModerationResult(
        source: ModerationSource.unknown,
        status: ModerationStatus.skipped,
      );

  /// エラー結果
  factory ModerationResult.error(String message) => ModerationResult(
        source: ModerationSource.unknown,
        status: ModerationStatus.error,
        errorMessage: message,
      );

  factory ModerationResult.fromJson(Map<String, dynamic> json) {
    return ModerationResult(
      source: ModerationSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => ModerationSource.unknown,
      ),
      scores: json['scores'] != null
          ? ModerationScores.fromJson(json['scores'] as Map<String, dynamic>)
          : null,
      status: ModerationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ModerationStatus.error,
      ),
      errorMessage: json['errorMessage'] as String?,
    );
  }

  /// 有害かどうか
  bool isToxic(double threshold) {
    if (scores == null) return false;
    return scores!.maxScore >= threshold;
  }

  /// 重大な有害性があるか
  bool isSevereToxic(double threshold) {
    if (scores == null) return false;
    return scores!.maxSevereScore >= threshold;
  }

  /// 成功したか
  bool get isSuccess => status == ModerationStatus.success;

  /// スキップされたか
  bool get isSkipped => status == ModerationStatus.skipped;

  /// エラーか
  bool get isError => status == ModerationStatus.error;

  /// 最も高いリスクカテゴリを取得
  String? get highestRiskCategory {
    if (scores == null) return null;

    final categories = {
      'toxicity': scores!.toxicity,
      'severeToxicity': scores!.severeToxicity,
      'identityAttack': scores!.identityAttack,
      'insult': scores!.insult,
      'profanity': scores!.profanity,
      'threat': scores!.threat,
    };

    String? maxCategory;
    double maxScore = 0;
    categories.forEach((category, score) {
      if (score > maxScore) {
        maxScore = score;
        maxCategory = category;
      }
    });

    return maxCategory;
  }

  Map<String, dynamic> toJson() => {
        'source': source.name,
        'scores': scores?.toJson(),
        'status': status.name,
        'errorMessage': errorMessage,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  String toString() {
    return 'ModerationResult('
        'source: ${source.name}, '
        'status: ${status.name}, '
        'scores: $scores, '
        'error: $errorMessage)';
  }
}

/// モデレーションサービス状態
class ModerationServiceStatus {
  final bool perspectiveConfigured;
  final bool comprehendConfigured;
  final double toxicityThreshold;
  final double severeToxicityThreshold;
  final int cacheSize;

  const ModerationServiceStatus({
    required this.perspectiveConfigured,
    required this.comprehendConfigured,
    required this.toxicityThreshold,
    required this.severeToxicityThreshold,
    required this.cacheSize,
  });

  bool get isConfigured => perspectiveConfigured || comprehendConfigured;

  @override
  String toString() {
    return 'ModerationServiceStatus('
        'perspective: $perspectiveConfigured, '
        'comprehend: $comprehendConfigured, '
        'threshold: $toxicityThreshold, '
        'cache: $cacheSize)';
  }
}

// ============================================================
// ユーティリティ拡張
// ============================================================

extension ModerationResultExtension on ModerationResult {
  /// ユーザー向けメッセージを取得
  String getUserMessage() {
    if (!isSuccess || scores == null) {
      return '';
    }

    final category = highestRiskCategory;
    if (category == null) return '';

    switch (category) {
      case 'toxicity':
        return '攻撃的な表現が含まれている可能性があります';
      case 'severeToxicity':
        return '非常に有害な表現が検出されました';
      case 'identityAttack':
        return '差別的な表現が含まれている可能性があります';
      case 'insult':
        return '侮辱的な表現が含まれている可能性があります';
      case 'profanity':
        return '不適切な言葉遣いが検出されました';
      case 'threat':
        return '脅迫的な表現が検出されました';
      default:
        return '不適切な表現が含まれている可能性があります';
    }
  }

  /// 重大度レベル（1-5）
  int getSeverityLevel() {
    if (scores == null) return 0;

    final maxScore = scores!.maxScore;
    if (maxScore >= 0.9) return 5;
    if (maxScore >= 0.7) return 4;
    if (maxScore >= 0.5) return 3;
    if (maxScore >= 0.3) return 2;
    if (maxScore >= 0.1) return 1;
    return 0;
  }
}
