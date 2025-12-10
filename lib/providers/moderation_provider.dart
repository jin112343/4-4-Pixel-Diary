import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/ng_word_dictionary.dart';
import '../core/utils/content_filter.dart';
import '../services/moderation/ai_moderation_service.dart';
import '../services/moderation/moderation_service.dart';

// ============================================================
// AI モデレーション設定プロバイダー
// ============================================================

/// AI モデレーションサービスプロバイダー
final aiModerationServiceProvider = Provider<AiModerationService>((ref) {
  final service = AiModerationService.instance;

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
