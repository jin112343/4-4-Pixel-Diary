import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/content_filter.dart';
import '../services/moderation/ai_moderation_service.dart' as ai;
import '../services/moderation/moderation_service.dart';
import '../services/moderation/remote_moderation_service.dart';

// ============================================================
// AI モデレーション設定プロバイダー
// ============================================================

/// AI モデレーションサービスプロバイダー
final aiModerationServiceProvider = Provider<ai.AiModerationService>((ref) {
  final service = ai.AiModerationService.instance;

  // 環境変数からAPIキーを取得して設定
  const perspectiveApiKey = String.fromEnvironment(
    'PERSPECTIVE_API_KEY',
    defaultValue: '',
  );

  const awsAccessKeyId = String.fromEnvironment(
    'AWS_ACCESS_KEY_ID',
    defaultValue: '',
  );

  const awsSecretAccessKey = String.fromEnvironment(
    'AWS_SECRET_ACCESS_KEY',
    defaultValue: '',
  );

  const awsRegion = String.fromEnvironment(
    'AWS_REGION',
    defaultValue: 'us-east-1',
  );

  // Perspective API設定
  if (perspectiveApiKey.isNotEmpty) {
    service.configurePerspective(
      apiKey: perspectiveApiKey,
      toxicityThreshold: 0.3, // 任天堂レベル
      severeToxicityThreshold: 0.2,
    );
  }

  // AWS Comprehend設定
  if (awsAccessKeyId.isNotEmpty && awsSecretAccessKey.isNotEmpty) {
    service.configureAwsComprehend(
      accessKeyId: awsAccessKeyId,
      secretAccessKey: awsSecretAccessKey,
      region: awsRegion,
    );
  }

  return service;
});

/// モデレーション設定プロバイダー
final moderationConfigProvider = Provider<ModerationConfig>((ref) {
  // 環境変数からAPIキーを取得
  const apiKey = String.fromEnvironment(
    'PERSPECTIVE_API_KEY',
    defaultValue: '',
  );

  // APIキーがある場合は任天堂レベルの厳格設定
  if (apiKey.isNotEmpty) {
    return ModerationConfig.nintendo(perspectiveApiKey: apiKey);
  }

  // APIキーがない場合でも任天堂レベルのローカル設定
  return const ModerationConfig(
    usePerspectiveApi: false,
    localBlockThreshold: 1, // 任天堂レベル: すべての違反を検出
    toxicityThreshold: 0.3,
    severeToxicityThreshold: 0.2,
    threatThreshold: 0.3,
    identityAttackThreshold: 0.3,
  );
});

/// モデレーションサービスプロバイダー
final moderationServiceProvider = Provider<ModerationService>((ref) {
  final config = ref.watch(moderationConfigProvider);
  return ModerationService(config: config);
});

// ============================================================
// リモートモデレーションサービス（サーバーサイド処理）
// ============================================================

/// リモートモデレーションサービスプロバイダー
final remoteModerationServiceProvider = Provider<RemoteModerationService>((ref) {
  return RemoteModerationService();
});

/// リモートコンテンツチェックプロバイダー
final remoteContentCheckProvider =
    FutureProvider.family<RemoteModerationResult, String>((ref, text) async {
  final service = ref.read(remoteModerationServiceProvider);
  return service.check(text);
});

/// リモートモデレーションが有効か（サーバーへの接続確認）
final isRemoteModerationAvailableProvider = FutureProvider<bool>((ref) async {
  final service = ref.read(remoteModerationServiceProvider);
  try {
    // 空文字列でテストリクエスト
    final result = await service.check('test');
    return !result.isError;
  } catch (e) {
    return false;
  }
});

/// モデレーションサービスプロバイダー（旧、互換性用）
final legacyModerationServiceProvider = Provider<ModerationService>((ref) {
  final config = ref.watch(moderationConfigProvider);
  return ModerationService(config: config);
});

// ============================================================
// カテゴリブロッキング設定プロバイダー
// ============================================================

/// カテゴリブロッキング設定
class CategoryBlockingConfig {
  final Map<NgWordCategory, bool> blocking;

  const CategoryBlockingConfig({required this.blocking});

  /// 任天堂レベル（すべてブロック）
  factory CategoryBlockingConfig.nintendo() {
    return CategoryBlockingConfig(
      blocking: {
        for (final category in NgWordCategory.values) category: true,
      },
    );
  }

  /// 厳格設定（ほとんどブロック）
  factory CategoryBlockingConfig.strict() {
    return CategoryBlockingConfig(
      blocking: {
        NgWordCategory.violence: true,
        NgWordCategory.sexual: true,
        NgWordCategory.discrimination: true,
        NgWordCategory.hate: true,
        NgWordCategory.profanity: true,
        NgWordCategory.copyright: true,
        NgWordCategory.personal: true,
        NgWordCategory.spam: true,
      },
    );
  }

  /// 通常設定
  factory CategoryBlockingConfig.normal() {
    return CategoryBlockingConfig(
      blocking: {
        NgWordCategory.violence: true,
        NgWordCategory.sexual: true,
        NgWordCategory.discrimination: true,
        NgWordCategory.hate: true,
        NgWordCategory.profanity: false, // 軽い罵倒は許容
        NgWordCategory.copyright: true,
        NgWordCategory.personal: true,
        NgWordCategory.spam: true,
      },
    );
  }

  /// カテゴリがブロックされているか
  bool isBlocked(NgWordCategory category) {
    return blocking[category] ?? true;
  }

  /// カテゴリブロック設定をコピー
  CategoryBlockingConfig copyWith({
    Map<NgWordCategory, bool>? blocking,
  }) {
    return CategoryBlockingConfig(
      blocking: blocking ?? Map.from(this.blocking),
    );
  }

  /// 特定カテゴリのブロック状態を更新
  CategoryBlockingConfig withCategoryBlocking(
    NgWordCategory category,
    bool blocked,
  ) {
    final newBlocking = Map<NgWordCategory, bool>.from(blocking);
    newBlocking[category] = blocked;
    return CategoryBlockingConfig(blocking: newBlocking);
  }
}

/// カテゴリブロッキング設定プロバイダー
final categoryBlockingProvider =
    StateNotifierProvider<CategoryBlockingNotifier, CategoryBlockingConfig>(
  (ref) {
    final notifier = CategoryBlockingNotifier();
    // 初期設定をContentFilterに反映
    notifier._syncToContentFilter();
    return notifier;
  },
);

/// カテゴリブロッキングNotifier
class CategoryBlockingNotifier extends StateNotifier<CategoryBlockingConfig> {
  CategoryBlockingNotifier() : super(CategoryBlockingConfig.nintendo());

  /// 設定を任天堂レベルに
  void setNintendo() {
    state = CategoryBlockingConfig.nintendo();
    _syncToContentFilter();
  }

  /// 設定を厳格に
  void setStrict() {
    state = CategoryBlockingConfig.strict();
    _syncToContentFilter();
  }

  /// 設定を通常に
  void setNormal() {
    state = CategoryBlockingConfig.normal();
    _syncToContentFilter();
  }

  /// 特定カテゴリのブロック状態を更新
  void setCategoryBlocking(NgWordCategory category, bool blocked) {
    state = state.withCategoryBlocking(category, blocked);
    _syncToContentFilter();
  }

  /// ContentFilterに設定を同期
  void _syncToContentFilter() {
    state.blocking.forEach((category, blocked) {
      ContentFilter.setCategoryBlocking(category, blocked);
    });
  }
}

/// フィルタ厳格度プロバイダー
final filterStrictnessProvider =
    StateProvider<FilterStrictness>((ref) => FilterStrictness.strict);

/// フィルタ厳格度が変更されたときにContentFilterを更新
final filterStrictnessNotifierProvider =
    Provider<FilterStrictnessNotifier>((ref) {
  return FilterStrictnessNotifier(ref);
});

class FilterStrictnessNotifier {
  final Ref _ref;

  FilterStrictnessNotifier(this._ref) {
    // 初期設定を適用
    _applyStrictness(_ref.read(filterStrictnessProvider));

    // 変更を監視
    _ref.listen<FilterStrictness>(filterStrictnessProvider, (previous, next) {
      _applyStrictness(next);
    });
  }

  void _applyStrictness(FilterStrictness strictness) {
    ContentFilter.setStrictness(strictness);
  }

  void setStrictness(FilterStrictness strictness) {
    _ref.read(filterStrictnessProvider.notifier).state = strictness;
  }
}

/// フィルタ統計プロバイダー
final filterStatsProvider = Provider<FilterStats>((ref) {
  // 厳格度の変更を監視して再計算
  ref.watch(filterStrictnessProvider);
  return ContentFilter.getStats();
});

/// コンテンツチェックプロバイダー（FutureProvider.family）
final contentCheckProvider =
    FutureProvider.family<ModerationResult, String>((ref, text) async {
  final service = ref.read(moderationServiceProvider);
  return service.moderate(text);
});

/// クイックコンテンツチェックプロバイダー
final quickContentCheckProvider =
    Provider.family<ModerationResult, String>((ref, text) {
  final service = ref.read(moderationServiceProvider);
  return service.moderateQuick(text);
});

/// リアルタイムテキスト検証用ステート
class TextValidationState {
  final String text;
  final bool isValid;
  final String? errorMessage;
  final bool isChecking;

  const TextValidationState({
    required this.text,
    required this.isValid,
    this.errorMessage,
    this.isChecking = false,
  });

  factory TextValidationState.initial() {
    return const TextValidationState(
      text: '',
      isValid: true,
      errorMessage: null,
      isChecking: false,
    );
  }

  TextValidationState copyWith({
    String? text,
    bool? isValid,
    String? errorMessage,
    bool? isChecking,
  }) {
    return TextValidationState(
      text: text ?? this.text,
      isValid: isValid ?? this.isValid,
      errorMessage: errorMessage,
      isChecking: isChecking ?? this.isChecking,
    );
  }
}

/// テキスト検証Notifier
class TextValidationNotifier extends StateNotifier<TextValidationState> {
  final ModerationService _service;

  TextValidationNotifier(this._service) : super(TextValidationState.initial());

  /// テキストを検証（デバウンス用に非同期）
  Future<void> validate(String text) async {
    if (text.isEmpty) {
      state = TextValidationState.initial();
      return;
    }

    state = state.copyWith(text: text, isChecking: true);

    // クイックチェック（ローカルのみ）
    final result = _service.moderateQuick(text);

    state = state.copyWith(
      text: text,
      isValid: result.isAllowed,
      errorMessage: result.isAllowed ? null : result.userMessage,
      isChecking: false,
    );
  }

  /// クリア
  void clear() {
    state = TextValidationState.initial();
  }
}

/// テキスト検証Notifierプロバイダー
final textValidationProvider =
    StateNotifierProvider<TextValidationNotifier, TextValidationState>((ref) {
  final service = ref.watch(moderationServiceProvider);
  return TextValidationNotifier(service);
});

/// タイトル検証プロバイダー
final titleValidationProvider =
    StateNotifierProvider<TextValidationNotifier, TextValidationState>((ref) {
  final service = ref.watch(moderationServiceProvider);
  return TextValidationNotifier(service);
});

/// ニックネーム検証プロバイダー
final nicknameValidationProvider =
    StateNotifierProvider<TextValidationNotifier, TextValidationState>((ref) {
  final service = ref.watch(moderationServiceProvider);
  return TextValidationNotifier(service);
});

/// コメント検証プロバイダー
final commentValidationProvider =
    StateNotifierProvider<TextValidationNotifier, TextValidationState>((ref) {
  final service = ref.watch(moderationServiceProvider);
  return TextValidationNotifier(service);
});

// ============================================================
// 統合モデレーションプロバイダー（ローカル + AI）
// ============================================================

/// 統合モデレーション結果
class UnifiedModerationResult {
  /// ローカルフィルタ結果
  final ContentCheckResult localResult;

  /// AI分析結果（利用可能な場合）
  final ai.ModerationResult? aiResult;

  /// 最終判定: 許可するか
  final bool isAllowed;

  /// ブロック理由
  final String? blockReason;

  /// 詳細メッセージ（管理者向け）
  final String? detailedMessage;

  /// 総合危険度スコア（0.0-1.0）
  final double riskScore;

  /// 検出されたカテゴリ
  final Set<NgWordCategory> detectedCategories;

  const UnifiedModerationResult({
    required this.localResult,
    this.aiResult,
    required this.isAllowed,
    this.blockReason,
    this.detailedMessage,
    required this.riskScore,
    required this.detectedCategories,
  });

  /// ユーザー向けメッセージ
  String get userMessage {
    if (isAllowed) return '';
    return '不適切な表現が含まれています。内容を修正してください。';
  }

  /// カテゴリ別の詳細メッセージ
  String getCategoryMessage() {
    if (detectedCategories.isEmpty) return '';

    final messages = detectedCategories.map((c) => c.blockMessage).toList();
    return messages.join('\n');
  }
}

/// 統合モデレーションNotifier
class UnifiedModerationNotifier
    extends StateNotifier<AsyncValue<UnifiedModerationResult?>> {
  final ai.AiModerationService _aiService;
  final ModerationConfig _config;

  UnifiedModerationNotifier(this._aiService, this._config)
      : super(const AsyncValue.data(null));

  /// フルモデレーション（ローカル + AI）
  Future<UnifiedModerationResult> moderate(String text) async {
    if (text.trim().isEmpty) {
      final result = UnifiedModerationResult(
        localResult: ContentCheckResult.clean(text),
        isAllowed: true,
        riskScore: 0.0,
        detectedCategories: {},
      );
      state = AsyncValue.data(result);
      return result;
    }

    state = const AsyncValue.loading();

    try {
      // ステップ1: ローカルフィルタリング
      final localResult = ContentFilter.check(text);

      // ステップ2: 重大な違反は即座にブロック
      if (!localResult.isClean && localResult.maxSeverity >= 4) {
        final result = UnifiedModerationResult(
          localResult: localResult,
          isAllowed: false,
          blockReason: 'ローカルフィルタで重大な違反を検出',
          detailedMessage: localResult.message,
          riskScore: 1.0,
          detectedCategories: localResult.violatedCategories.toSet(),
        );
        state = AsyncValue.data(result);
        return result;
      }

      // ステップ3: AI分析（設定されている場合）
      ai.ModerationResult? aiResult;
      final aiStatus = _aiService.getStatus();

      if (aiStatus.isConfigured) {
        try {
          aiResult = await _aiService.analyze(text);
        } catch (e) {
          // AI分析失敗時はローカル結果のみで判定
          aiResult = null;
        }
      }

      // ステップ4: 結果の統合
      final result = _combineResults(localResult, aiResult);

      state = AsyncValue.data(result);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// クイックモデレーション（ローカルのみ）
  UnifiedModerationResult moderateQuick(String text) {
    if (text.trim().isEmpty) {
      return UnifiedModerationResult(
        localResult: ContentCheckResult.clean(text),
        isAllowed: true,
        riskScore: 0.0,
        detectedCategories: {},
      );
    }

    final localResult = ContentFilter.check(text);

    return UnifiedModerationResult(
      localResult: localResult,
      isAllowed: localResult.isClean,
      blockReason: localResult.isClean ? null : 'ローカルフィルタで違反を検出',
      detailedMessage: localResult.message,
      riskScore: _calculateRiskScore(localResult, null),
      detectedCategories: localResult.violatedCategories.toSet(),
    );
  }

  /// ローカル + AI 結果を統合
  UnifiedModerationResult _combineResults(
    ContentCheckResult localResult,
    ai.ModerationResult? aiResult,
  ) {
    final detectedCategories = localResult.violatedCategories.toSet();

    // AIスコアからカテゴリを推定
    if (aiResult != null && aiResult.isSuccess && aiResult.scores != null) {
      final scores = aiResult.scores!;

      if (scores.threat >= _config.threatThreshold) {
        detectedCategories.add(NgWordCategory.violence);
      }
      if (scores.identityAttack >= _config.identityAttackThreshold) {
        detectedCategories.add(NgWordCategory.discrimination);
      }
      if (scores.profanity >= _config.toxicityThreshold) {
        detectedCategories.add(NgWordCategory.profanity);
      }
    }

    // 総合リスクスコア計算
    final riskScore = _calculateRiskScore(localResult, aiResult);

    // 最終判定
    final shouldBlock = _shouldBlock(localResult, aiResult);

    // ブロック理由生成
    String? blockReason;
    if (shouldBlock) {
      final reasons = <String>[];
      if (!localResult.isClean) {
        reasons.add('禁止表現検出');
      }
      if (aiResult != null && aiResult.isSuccess) {
        if (aiResult.isToxic(_config.toxicityThreshold)) {
          reasons.add('AI判定: 有害性${(aiResult.scores!.maxScore * 100).toInt()}%');
        }
      }
      blockReason = reasons.join(', ');
    }

    // 詳細メッセージ
    final detailedParts = <String>[];
    if (!localResult.isClean) {
      detailedParts.add('ローカル: ${localResult.message}');
    }
    if (aiResult != null && aiResult.isSuccess) {
      detailedParts.add('AI: ${aiResult.scores}');
    }

    return UnifiedModerationResult(
      localResult: localResult,
      aiResult: aiResult,
      isAllowed: !shouldBlock,
      blockReason: blockReason,
      detailedMessage: detailedParts.isNotEmpty ? detailedParts.join('\n') : null,
      riskScore: riskScore,
      detectedCategories: detectedCategories,
    );
  }

  /// リスクスコアを計算（0.0-1.0）
  double _calculateRiskScore(
    ContentCheckResult localResult,
    ai.ModerationResult? aiResult,
  ) {
    double score = 0.0;

    // ローカル結果からのスコア（重大度 1-5 を 0.0-1.0 に変換）
    if (!localResult.isClean) {
      score = localResult.maxSeverity / 5.0;
    }

    // AI結果からのスコア
    if (aiResult != null && aiResult.isSuccess && aiResult.scores != null) {
      final aiScore = aiResult.scores!.maxScore;
      // ローカルとAIの高い方を採用
      score = score > aiScore ? score : aiScore;
    }

    return score.clamp(0.0, 1.0);
  }

  /// ブロックすべきか判定
  bool _shouldBlock(
    ContentCheckResult localResult,
    ai.ModerationResult? aiResult,
  ) {
    // ローカル結果でブロック判定
    if (!localResult.isClean) {
      if (localResult.maxSeverity >= _config.localBlockThreshold) {
        return true;
      }
    }

    // AI結果でブロック判定
    if (aiResult != null && aiResult.isSuccess && aiResult.scores != null) {
      final scores = aiResult.scores!;

      if (scores.severeToxicity >= _config.severeToxicityThreshold) {
        return true;
      }
      if (scores.toxicity >= _config.toxicityThreshold) {
        return true;
      }
      if (scores.threat >= _config.threatThreshold) {
        return true;
      }
      if (scores.identityAttack >= _config.identityAttackThreshold) {
        return true;
      }
    }

    return false;
  }

  /// 結果をクリア
  void clear() {
    state = const AsyncValue.data(null);
  }
}

/// 統合モデレーションプロバイダー
final unifiedModerationProvider = StateNotifierProvider<
    UnifiedModerationNotifier, AsyncValue<UnifiedModerationResult?>>((ref) {
  final aiService = ref.watch(aiModerationServiceProvider);
  final config = ref.watch(moderationConfigProvider);
  return UnifiedModerationNotifier(aiService, config);
});

/// 統合コンテンツチェックプロバイダー（FutureProvider.family）
final unifiedContentCheckProvider =
    FutureProvider.family<UnifiedModerationResult, String>((ref, text) async {
  final notifier = ref.read(unifiedModerationProvider.notifier);
  return notifier.moderate(text);
});

/// クイックユニファイドチェックプロバイダー
final quickUnifiedCheckProvider =
    Provider.family<UnifiedModerationResult, String>((ref, text) {
  final notifier = ref.read(unifiedModerationProvider.notifier);
  return notifier.moderateQuick(text);
});

// ============================================================
// モデレーション状態プロバイダー
// ============================================================

/// モデレーションシステム全体の状態
class ModerationSystemState {
  final FilterStrictness strictness;
  final CategoryBlockingConfig categoryBlocking;
  final bool aiEnabled;
  final ai.ModerationServiceStatus? aiStatus;

  const ModerationSystemState({
    required this.strictness,
    required this.categoryBlocking,
    required this.aiEnabled,
    this.aiStatus,
  });
}

/// モデレーションシステム状態プロバイダー
final moderationSystemStateProvider = Provider<ModerationSystemState>((ref) {
  final strictness = ref.watch(filterStrictnessProvider);
  final categoryBlocking = ref.watch(categoryBlockingProvider);
  final aiService = ref.watch(aiModerationServiceProvider);
  final aiStatus = aiService.getStatus();

  return ModerationSystemState(
    strictness: strictness,
    categoryBlocking: categoryBlocking,
    aiEnabled: aiStatus.isConfigured,
    aiStatus: aiStatus,
  );
});

/// AI モデレーションが有効かどうか
final isAiModerationEnabledProvider = Provider<bool>((ref) {
  final aiService = ref.watch(aiModerationServiceProvider);
  return aiService.getStatus().isConfigured;
});

// ============================================================
// 統合モデレーションプロバイダー（サーバー優先 + ローカルフォールバック）
// ============================================================

/// ハイブリッドモデレーション結果
class HybridModerationResult {
  /// サーバーサイド結果
  final RemoteModerationResult? remoteResult;

  /// ローカル結果（フォールバック時）
  final ContentCheckResult? localResult;

  /// 最終判定: 許可するか
  final bool isAllowed;

  /// ブロック理由
  final String? blockReason;

  /// ユーザー向けメッセージ
  final String userMessage;

  /// 処理方法
  final ModerationSource source;

  /// リスクスコア（0.0-1.0）
  final double riskScore;

  const HybridModerationResult({
    this.remoteResult,
    this.localResult,
    required this.isAllowed,
    this.blockReason,
    required this.userMessage,
    required this.source,
    required this.riskScore,
  });

  /// クリーンな結果
  factory HybridModerationResult.clean() {
    return const HybridModerationResult(
      isAllowed: true,
      userMessage: '',
      source: ModerationSource.local,
      riskScore: 0.0,
    );
  }
}

/// モデレーションソース
enum ModerationSource {
  /// サーバーサイドで処理
  server,

  /// ローカルで処理（フォールバック）
  local,

  /// 両方を使用
  hybrid,
}

/// ハイブリッドモデレーションNotifier
class HybridModerationNotifier
    extends StateNotifier<AsyncValue<HybridModerationResult?>> {
  final RemoteModerationService _remoteService;
  final ModerationService _localService;

  HybridModerationNotifier(this._remoteService, this._localService)
      : super(const AsyncValue.data(null));

  /// モデレーション実行（サーバー優先）
  Future<HybridModerationResult> moderate(String text) async {
    if (text.trim().isEmpty) {
      final result = HybridModerationResult.clean();
      state = AsyncValue.data(result);
      return result;
    }

    state = const AsyncValue.loading();

    try {
      // ステップ1: ローカル事前チェック（軽量）
      final localPreCheck = ContentFilter.check(text);

      // 明らかにNGな場合は即ブロック（サーバー呼び出しを省略）
      if (!localPreCheck.isClean && localPreCheck.maxSeverity >= 4) {
        final result = HybridModerationResult(
          localResult: localPreCheck,
          isAllowed: false,
          blockReason: 'コンテンツポリシー違反',
          userMessage: localPreCheck.message,
          source: ModerationSource.local,
          riskScore: 1.0,
        );
        state = AsyncValue.data(result);
        return result;
      }

      // ステップ2: サーバーサイドモデレーション
      final remoteResult = await _remoteService.check(text);

      // サーバーがエラーを返した場合はローカルフォールバック
      if (remoteResult.isError) {
        return _fallbackToLocal(text, localPreCheck);
      }

      // サーバー結果を使用
      final result = HybridModerationResult(
        remoteResult: remoteResult,
        localResult: localPreCheck,
        isAllowed: !remoteResult.shouldBlock,
        blockReason: remoteResult.shouldBlock
            ? remoteResult.userMessage ?? 'コンテンツポリシー違反'
            : null,
        userMessage: remoteResult.shouldBlock
            ? remoteResult.userMessage ?? '不適切な表現が含まれています'
            : '',
        source: ModerationSource.server,
        riskScore: remoteResult.riskScore,
      );

      state = AsyncValue.data(result);
      return result;
    } catch (e, stack) {
      // エラー時はローカルフォールバック
      try {
        final localResult = ContentFilter.check(text);
        final fallback = _fallbackToLocal(text, localResult);
        state = AsyncValue.data(fallback);
        return fallback;
      } catch (localError) {
        state = AsyncValue.error(e, stack);
        rethrow;
      }
    }
  }

  /// クイックモデレーション（ローカルのみ、リアルタイム入力用）
  HybridModerationResult moderateQuick(String text) {
    if (text.trim().isEmpty) {
      return HybridModerationResult.clean();
    }

    final localResult = ContentFilter.check(text);

    return HybridModerationResult(
      localResult: localResult,
      isAllowed: localResult.isClean,
      blockReason: localResult.isClean ? null : localResult.message,
      userMessage: localResult.isClean ? '' : localResult.message,
      source: ModerationSource.local,
      riskScore: localResult.isClean ? 0.0 : localResult.maxSeverity / 5.0,
    );
  }

  /// ローカルフォールバック処理
  HybridModerationResult _fallbackToLocal(
    String text,
    ContentCheckResult localResult,
  ) {
    // ローカルフィルタのみで判定
    final localModeration = _localService.moderateQuick(text);

    return HybridModerationResult(
      localResult: localModeration.localResult,
      isAllowed: localModeration.isAllowed,
      blockReason: localModeration.blockReason,
      userMessage: localModeration.isAllowed ? '' : localModeration.userMessage,
      source: ModerationSource.local,
      riskScore: localModeration.shouldBlock
          ? (localModeration.localResult?.maxSeverity ?? 0) / 5.0
          : 0.0,
    );
  }

  /// 結果をクリア
  void clear() {
    state = const AsyncValue.data(null);
  }
}

/// ハイブリッドモデレーションプロバイダー
final hybridModerationProvider = StateNotifierProvider<
    HybridModerationNotifier, AsyncValue<HybridModerationResult?>>((ref) {
  final remoteService = ref.watch(remoteModerationServiceProvider);
  final localService = ref.watch(moderationServiceProvider);
  return HybridModerationNotifier(remoteService, localService);
});

/// ハイブリッドコンテンツチェックプロバイダー（推奨）
final hybridContentCheckProvider =
    FutureProvider.family<HybridModerationResult, String>((ref, text) async {
  final notifier = ref.read(hybridModerationProvider.notifier);
  return notifier.moderate(text);
});

/// クイックハイブリッドチェックプロバイダー（リアルタイム入力用）
final quickHybridCheckProvider =
    Provider.family<HybridModerationResult, String>((ref, text) {
  final notifier = ref.read(hybridModerationProvider.notifier);
  return notifier.moderateQuick(text);
});

/// ハイブリッドテキスト検証Notifier（リアルタイム入力用）
class HybridTextValidationNotifier
    extends StateNotifier<TextValidationState> {
  final HybridModerationNotifier _moderationNotifier;

  HybridTextValidationNotifier(this._moderationNotifier)
      : super(TextValidationState.initial());

  /// クイック検証（ローカルのみ、リアルタイム入力用）
  void validateQuick(String text) {
    if (text.isEmpty) {
      state = TextValidationState.initial();
      return;
    }

    final result = _moderationNotifier.moderateQuick(text);

    state = TextValidationState(
      text: text,
      isValid: result.isAllowed,
      errorMessage: result.isAllowed ? null : result.userMessage,
      isChecking: false,
    );
  }

  /// フル検証（サーバー優先、送信前チェック用）
  Future<void> validateFull(String text) async {
    if (text.isEmpty) {
      state = TextValidationState.initial();
      return;
    }

    state = state.copyWith(text: text, isChecking: true);

    final result = await _moderationNotifier.moderate(text);

    state = TextValidationState(
      text: text,
      isValid: result.isAllowed,
      errorMessage: result.isAllowed ? null : result.userMessage,
      isChecking: false,
    );
  }

  /// クリア
  void clear() {
    state = TextValidationState.initial();
  }
}

/// ハイブリッドテキスト検証プロバイダー
final hybridTextValidationProvider =
    StateNotifierProvider<HybridTextValidationNotifier, TextValidationState>(
        (ref) {
  final moderationNotifier = ref.watch(hybridModerationProvider.notifier);
  return HybridTextValidationNotifier(moderationNotifier);
});

/// ハイブリッドタイトル検証プロバイダー
final hybridTitleValidationProvider =
    StateNotifierProvider<HybridTextValidationNotifier, TextValidationState>(
        (ref) {
  final moderationNotifier = ref.watch(hybridModerationProvider.notifier);
  return HybridTextValidationNotifier(moderationNotifier);
});

/// ハイブリッドニックネーム検証プロバイダー
final hybridNicknameValidationProvider =
    StateNotifierProvider<HybridTextValidationNotifier, TextValidationState>(
        (ref) {
  final moderationNotifier = ref.watch(hybridModerationProvider.notifier);
  return HybridTextValidationNotifier(moderationNotifier);
});

/// ハイブリッドコメント検証プロバイダー
final hybridCommentValidationProvider =
    StateNotifierProvider<HybridTextValidationNotifier, TextValidationState>(
        (ref) {
  final moderationNotifier = ref.watch(hybridModerationProvider.notifier);
  return HybridTextValidationNotifier(moderationNotifier);
});
