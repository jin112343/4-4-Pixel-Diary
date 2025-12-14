import 'package:dio/dio.dart';

import '../../core/utils/content_filter.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/text_normalizer.dart';

/// コンテンツモデレーションサービス
/// ローカルフィルタリング + 外部API（Perspective API等）を統合
class ModerationService {
  final Dio _dio;
  final ModerationConfig _config;

  ModerationService({
    required ModerationConfig config,
    Dio? dio,
  })  : _config = config,
        _dio = dio ?? Dio();

  // ============================================================
  // 統合モデレーション
  // ============================================================

  /// 総合モデレーション（ローカル + API）
  Future<ModerationResult> moderate(String text) async {
    // 空チェック
    if (text.trim().isEmpty) {
      return ModerationResult.clean(text);
    }

    // ステップ1: ローカルフィルタリング（高速）
    final localResult = ContentFilter.check(text);

    // ローカルで重大な違反が見つかった場合は即座にブロック
    if (!localResult.isClean && localResult.maxSeverity >= 4) {
      logger.i('ModerationService: ローカルフィルタでブロック');
      return ModerationResult(
        isAllowed: false,
        originalText: text,
        localResult: localResult,
        apiResult: null,
        blockReason: 'ローカルフィルタによるブロック',
        shouldBlock: true,
      );
    }

    // ステップ2: API呼び出し（設定で有効な場合のみ）
    ApiModerationResult? apiResult;
    if (_config.usePerspectiveApi && _config.perspectiveApiKey != null) {
      try {
        apiResult = await _callPerspectiveApi(text);
      } catch (e, stackTrace) {
        logger.e(
          'ModerationService: Perspective API呼び出し失敗',
          error: e,
          stackTrace: stackTrace,
        );
        // API失敗時はローカル結果のみで判定
      }
    }

    // ステップ3: 結果の統合判定
    final shouldBlock = _shouldBlock(localResult, apiResult);

    return ModerationResult(
      isAllowed: !shouldBlock,
      originalText: text,
      localResult: localResult,
      apiResult: apiResult,
      blockReason: shouldBlock ? _getBlockReason(localResult, apiResult) : null,
      shouldBlock: shouldBlock,
    );
  }

  /// クイックモデレーション（ローカルのみ、高速）
  ModerationResult moderateQuick(String text) {
    final localResult = ContentFilter.check(text);

    return ModerationResult(
      isAllowed: localResult.isClean,
      originalText: text,
      localResult: localResult,
      apiResult: null,
      blockReason: localResult.isClean ? null : 'ローカルフィルタによるブロック',
      shouldBlock: !localResult.isClean,
    );
  }

  // ============================================================
  // Perspective API連携
  // ============================================================

  /// Perspective APIを呼び出し
  Future<ApiModerationResult> _callPerspectiveApi(String text) async {
    final url =
        'https://commentanalyzer.googleapis.com/v1alpha1/comments:analyze'
        '?key=${_config.perspectiveApiKey}';

    // 言語を推定
    final language = CharacterTypeUtil.containsJapanese(text) ? 'ja' : 'en';

    final requestBody = <String, dynamic>{
      'comment': <String, dynamic>{'text': text},
      'languages': [language],
      'requestedAttributes': <String, dynamic>{
        'TOXICITY': <String, dynamic>{},
        'SEVERE_TOXICITY': <String, dynamic>{},
        'INSULT': <String, dynamic>{},
        'PROFANITY': <String, dynamic>{},
        'THREAT': <String, dynamic>{},
        'IDENTITY_ATTACK': <String, dynamic>{},
      },
    };

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        url,
        data: requestBody,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      return _parsePerspectiveResponse(response.data!);
    } on DioException catch (e) {
      logger.e(
        'Perspective API error',
        error: e.message,
        stackTrace: e.stackTrace,
      );
      rethrow;
    }
  }

  /// Perspective APIレスポンスをパース
  ApiModerationResult _parsePerspectiveResponse(Map<String, dynamic> data) {
    final attributeScores =
        data['attributeScores'] as Map<String, dynamic>? ?? {};

    double getScore(String attribute) {
      final attr = attributeScores[attribute] as Map<String, dynamic>?;
      if (attr == null) return 0.0;
      final summaryScore = attr['summaryScore'] as Map<String, dynamic>?;
      return (summaryScore?['value'] as num?)?.toDouble() ?? 0.0;
    }

    return ApiModerationResult(
      toxicity: getScore('TOXICITY'),
      severeToxicity: getScore('SEVERE_TOXICITY'),
      insult: getScore('INSULT'),
      profanity: getScore('PROFANITY'),
      threat: getScore('THREAT'),
      identityAttack: getScore('IDENTITY_ATTACK'),
    );
  }

  // ============================================================
  // 判定ロジック
  // ============================================================

  /// ブロックすべきかどうかを判定
  bool _shouldBlock(
    ContentCheckResult localResult,
    ApiModerationResult? apiResult,
  ) {
    // ローカル結果でブロック判定
    if (!localResult.isClean) {
      // 重大度が閾値以上ならブロック
      if (localResult.maxSeverity >= _config.localBlockThreshold) {
        return true;
      }
    }

    // API結果でブロック判定
    if (apiResult != null) {
      // 重大な毒性
      if (apiResult.severeToxicity >= _config.severeToxicityThreshold) {
        return true;
      }
      // 通常の毒性
      if (apiResult.toxicity >= _config.toxicityThreshold) {
        return true;
      }
      // 脅迫
      if (apiResult.threat >= _config.threatThreshold) {
        return true;
      }
      // アイデンティティ攻撃（差別）
      if (apiResult.identityAttack >= _config.identityAttackThreshold) {
        return true;
      }
    }

    return false;
  }

  /// ブロック理由を取得
  String _getBlockReason(
    ContentCheckResult localResult,
    ApiModerationResult? apiResult,
  ) {
    final reasons = <String>[];

    if (!localResult.isClean) {
      final categories = localResult.violatedCategories
          .map((c) => c.displayName)
          .join(', ');
      reasons.add('禁止表現検出: $categories');
    }

    if (apiResult != null) {
      if (apiResult.severeToxicity >= _config.severeToxicityThreshold) {
        reasons.add('重大な有害性: ${(apiResult.severeToxicity * 100).toInt()}%');
      }
      if (apiResult.toxicity >= _config.toxicityThreshold) {
        reasons.add('有害性: ${(apiResult.toxicity * 100).toInt()}%');
      }
      if (apiResult.threat >= _config.threatThreshold) {
        reasons.add('脅迫: ${(apiResult.threat * 100).toInt()}%');
      }
      if (apiResult.identityAttack >= _config.identityAttackThreshold) {
        reasons.add('差別攻撃: ${(apiResult.identityAttack * 100).toInt()}%');
      }
    }

    return reasons.join('; ');
  }
}

// ============================================================
// データクラス
// ============================================================

/// モデレーション設定
class ModerationConfig {
  /// Perspective APIを使用するか
  final bool usePerspectiveApi;

  /// Perspective APIキー
  final String? perspectiveApiKey;

  /// ローカルフィルタのブロック閾値（重大度）
  final int localBlockThreshold;

  /// 毒性スコアのブロック閾値
  final double toxicityThreshold;

  /// 重大な毒性スコアのブロック閾値
  final double severeToxicityThreshold;

  /// 脅迫スコアのブロック閾値
  final double threatThreshold;

  /// アイデンティティ攻撃スコアのブロック閾値
  final double identityAttackThreshold;

  const ModerationConfig({
    this.usePerspectiveApi = false,
    this.perspectiveApiKey,
    this.localBlockThreshold = 3,
    this.toxicityThreshold = 0.7,
    this.severeToxicityThreshold = 0.5,
    this.threatThreshold = 0.6,
    this.identityAttackThreshold = 0.6,
  });

  /// デフォルト設定（ローカルのみ）
  factory ModerationConfig.localOnly() {
    return const ModerationConfig(
      usePerspectiveApi: false,
      localBlockThreshold: 3,
    );
  }

  /// 厳格設定
  factory ModerationConfig.strict({String? perspectiveApiKey}) {
    return ModerationConfig(
      usePerspectiveApi: perspectiveApiKey != null,
      perspectiveApiKey: perspectiveApiKey,
      localBlockThreshold: 2,
      toxicityThreshold: 0.5,
      severeToxicityThreshold: 0.3,
      threatThreshold: 0.4,
      identityAttackThreshold: 0.4,
    );
  }

  /// 任天堂レベル設定
  factory ModerationConfig.nintendo({String? perspectiveApiKey}) {
    return ModerationConfig(
      usePerspectiveApi: perspectiveApiKey != null,
      perspectiveApiKey: perspectiveApiKey,
      localBlockThreshold: 1,
      toxicityThreshold: 0.3,
      severeToxicityThreshold: 0.2,
      threatThreshold: 0.3,
      identityAttackThreshold: 0.3,
    );
  }
}

/// APIモデレーション結果
class ApiModerationResult {
  /// 毒性スコア（0.0-1.0）
  final double toxicity;

  /// 重大な毒性スコア
  final double severeToxicity;

  /// 侮辱スコア
  final double insult;

  /// 冒涜スコア
  final double profanity;

  /// 脅迫スコア
  final double threat;

  /// アイデンティティ攻撃スコア
  final double identityAttack;

  const ApiModerationResult({
    required this.toxicity,
    required this.severeToxicity,
    required this.insult,
    required this.profanity,
    required this.threat,
    required this.identityAttack,
  });

  /// 最大スコアを取得
  double get maxScore {
    return [toxicity, severeToxicity, insult, profanity, threat, identityAttack]
        .reduce((a, b) => a > b ? a : b);
  }

  /// スコアサマリーを取得
  Map<String, double> get scores => {
        'toxicity': toxicity,
        'severeToxicity': severeToxicity,
        'insult': insult,
        'profanity': profanity,
        'threat': threat,
        'identityAttack': identityAttack,
      };

  @override
  String toString() {
    return 'ApiModerationResult('
        'toxicity: ${(toxicity * 100).toInt()}%, '
        'severeToxicity: ${(severeToxicity * 100).toInt()}%, '
        'insult: ${(insult * 100).toInt()}%, '
        'profanity: ${(profanity * 100).toInt()}%, '
        'threat: ${(threat * 100).toInt()}%, '
        'identityAttack: ${(identityAttack * 100).toInt()}%)';
  }
}

/// モデレーション結果
class ModerationResult {
  /// 投稿が許可されるか
  final bool isAllowed;

  /// 元のテキスト
  final String originalText;

  /// ローカルフィルタ結果
  final ContentCheckResult? localResult;

  /// API結果
  final ApiModerationResult? apiResult;

  /// ブロック理由
  final String? blockReason;

  /// ブロックすべきか
  final bool shouldBlock;

  const ModerationResult({
    required this.isAllowed,
    required this.originalText,
    required this.localResult,
    required this.apiResult,
    required this.blockReason,
    required this.shouldBlock,
  });

  /// クリーンな結果を生成
  factory ModerationResult.clean(String text) {
    return ModerationResult(
      isAllowed: true,
      originalText: text,
      localResult: ContentCheckResult.clean(text),
      apiResult: null,
      blockReason: null,
      shouldBlock: false,
    );
  }

  /// ユーザー向けメッセージ
  String get userMessage {
    if (isAllowed) return '';
    return '不適切な表現が含まれています。内容を修正してください。';
  }

  /// 詳細なブロック理由（管理者向け）
  String get detailedReason {
    if (isAllowed) return 'コンテンツは問題ありません';

    final parts = <String>[];

    if (localResult != null && !localResult!.isClean) {
      parts.add('ローカルフィルタ: ${localResult!.message}');
    }

    if (apiResult != null) {
      parts.add('API評価: $apiResult');
    }

    return parts.join('\n');
  }

  @override
  String toString() {
    return 'ModerationResult('
        'isAllowed: $isAllowed, '
        'shouldBlock: $shouldBlock, '
        'reason: $blockReason)';
  }
}

/// モデレーションログ（監査用）
class ModerationLog {
  final String id;
  final DateTime timestamp;
  final String userId;
  final String originalText;
  final ModerationResult result;
  final String? action; // 'blocked', 'allowed', 'flagged'

  const ModerationLog({
    required this.id,
    required this.timestamp,
    required this.userId,
    required this.originalText,
    required this.result,
    this.action,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
      'originalText': originalText,
      'isAllowed': result.isAllowed,
      'blockReason': result.blockReason,
      'action': action,
      'localViolations':
          result.localResult?.violations.map((v) => v.toString()).toList(),
      'apiScores': result.apiResult?.scores,
    };
  }
}
