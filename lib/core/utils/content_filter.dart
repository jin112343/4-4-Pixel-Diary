import 'logger.dart';
import 'text_normalizer.dart';

/// コンテンツフィルタ（サーバーサイドモデレーション用クライアント）
///
/// サーバーサイドでのモデレーションを前提とし、
/// ローカルでは最小限の事前チェックのみ実行
class ContentFilter {
  ContentFilter._();

  // ============================================================
  // 設定
  // ============================================================

  /// フィルタの厳格度
  static FilterStrictness _strictness = FilterStrictness.nintendo;

  /// カテゴリ別ブロック設定
  static final Map<NgWordCategory, bool> _categoryBlocking = {
    for (final category in NgWordCategory.values) category: true,
  };

  /// フィルタ厳格度を設定
  static void setStrictness(FilterStrictness strictness) {
    _strictness = strictness;
    logger.i('ContentFilter: 厳格度を ${strictness.name} に設定');
  }

  /// 現在の厳格度を取得
  static FilterStrictness get strictness => _strictness;

  /// カテゴリのブロック設定を変更
  static void setCategoryBlocking(NgWordCategory category, bool block) {
    _categoryBlocking[category] = block;
  }

  /// カテゴリがブロック対象か
  static bool isCategoryBlocked(NgWordCategory category) {
    return _categoryBlocking[category] ?? true;
  }

  // ============================================================
  // ローカル事前チェック（サーバー呼び出し前の軽量チェック）
  // ============================================================

  /// ローカルで軽量な事前チェックを実行
  /// サーバーサイドモデレーションの前に呼び出して、
  /// 明らかに問題のあるテキストを事前にブロック
  static ContentCheckResult check(String text) {
    if (text.isEmpty) {
      return ContentCheckResult.clean(text);
    }

    final violations = <ContentViolation>[];

    // 基本的な長さチェック
    if (text.length > 500) {
      violations.add(ContentViolation(
        originalWord: text.substring(0, 50),
        matchedWord: 'テキストが長すぎます',
        category: NgWordCategory.spam,
        severity: 2,
        matchType: MatchType.pattern,
      ));
    }

    // 繰り返し文字チェック（スパム検出）
    if (_hasExcessiveRepetition(text)) {
      violations.add(ContentViolation(
        originalWord: text,
        matchedWord: '繰り返し文字',
        category: NgWordCategory.spam,
        severity: 2,
        matchType: MatchType.pattern,
      ));
    }

    // 空白・特殊文字の過剰使用チェック
    if (_hasExcessiveSpecialChars(text)) {
      violations.add(ContentViolation(
        originalWord: text,
        matchedWord: '特殊文字過剰',
        category: NgWordCategory.spam,
        severity: 1,
        matchType: MatchType.pattern,
      ));
    }

    // 結果を返す（最終判定はサーバーで行う）
    return ContentCheckResult(
      originalText: text,
      violations: violations,
      checkedAt: DateTime.now(),
    );
  }

  /// 繰り返し文字の過剰使用をチェック
  static bool _hasExcessiveRepetition(String text) {
    // 同じ文字が5回以上連続
    final repetitionPattern = RegExp(r'(.)\1{4,}');
    return repetitionPattern.hasMatch(text);
  }

  /// 特殊文字の過剰使用をチェック
  static bool _hasExcessiveSpecialChars(String text) {
    final specialChars = text.replaceAll(RegExp(r'[\w\s\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]'), '');
    return specialChars.length > text.length * 0.3;
  }

  // ============================================================
  // ユーティリティ
  // ============================================================

  /// テキストを正規化（サーバー送信前の前処理）
  static String normalizeForServer(String text) {
    return TextNormalizer.normalize(text);
  }

  /// 統計情報を取得
  static FilterStats getStats() {
    return FilterStats(
      strictness: _strictness,
      localCheckOnly: true,
      serverModerationEnabled: true,
    );
  }
}

// ============================================================
// 列挙型・データクラス
// ============================================================

/// フィルタ厳格度
enum FilterStrictness {
  /// 軽量（基本的なNGワードのみ）
  light,

  /// 通常
  normal,

  /// 厳格
  strict,

  /// 任天堂レベル（最強）
  nintendo,
}

/// NGワードカテゴリ
enum NgWordCategory {
  violence,
  sexual,
  discrimination,
  hate,
  profanity,
  copyright,
  personal,
  pattern,
  spam,
}

/// カテゴリ拡張
extension NgWordCategoryExtension on NgWordCategory {
  String get displayName {
    switch (this) {
      case NgWordCategory.violence:
        return '暴力';
      case NgWordCategory.sexual:
        return '性的';
      case NgWordCategory.discrimination:
        return '差別';
      case NgWordCategory.hate:
        return 'ヘイト';
      case NgWordCategory.profanity:
        return '罵倒';
      case NgWordCategory.copyright:
        return '著作権';
      case NgWordCategory.personal:
        return '個人情報';
      case NgWordCategory.pattern:
        return 'パターン';
      case NgWordCategory.spam:
        return 'スパム';
    }
  }

  String get blockMessage {
    switch (this) {
      case NgWordCategory.violence:
        return '暴力的な表現は使用できません';
      case NgWordCategory.sexual:
        return '性的な表現は使用できません';
      case NgWordCategory.discrimination:
        return '差別的な表現は使用できません';
      case NgWordCategory.hate:
        return 'ヘイトスピーチは使用できません';
      case NgWordCategory.profanity:
        return '不適切な言葉遣いは使用できません';
      case NgWordCategory.copyright:
        return '著作権に関わる表現は使用できません';
      case NgWordCategory.personal:
        return '個人情報は入力できません';
      case NgWordCategory.pattern:
        return '不適切なパターンが検出されました';
      case NgWordCategory.spam:
        return 'スパム的な内容は投稿できません';
    }
  }

  int get severity {
    switch (this) {
      case NgWordCategory.violence:
        return 5;
      case NgWordCategory.sexual:
        return 5;
      case NgWordCategory.discrimination:
        return 5;
      case NgWordCategory.hate:
        return 5;
      case NgWordCategory.profanity:
        return 3;
      case NgWordCategory.copyright:
        return 4;
      case NgWordCategory.personal:
        return 4;
      case NgWordCategory.pattern:
        return 3;
      case NgWordCategory.spam:
        return 2;
    }
  }
}

/// マッチタイプ
enum MatchType {
  exact,
  normalized,
  pattern,
  categoryPattern,
  variation,
}

/// コンテンツ違反情報
class ContentViolation {
  final String originalWord;
  final String matchedWord;
  final NgWordCategory category;
  final int severity;
  final MatchType matchType;

  const ContentViolation({
    required this.originalWord,
    required this.matchedWord,
    required this.category,
    required this.severity,
    required this.matchType,
  });

  @override
  String toString() {
    return 'ContentViolation('
        'word: $matchedWord, '
        'category: ${category.displayName}, '
        'severity: $severity)';
  }
}

/// コンテンツチェック結果
class ContentCheckResult {
  final String originalText;
  final List<ContentViolation> violations;
  final DateTime checkedAt;

  const ContentCheckResult({
    required this.originalText,
    required this.violations,
    required this.checkedAt,
  });

  /// クリーンな結果
  factory ContentCheckResult.clean(String text) {
    return ContentCheckResult(
      originalText: text,
      violations: const [],
      checkedAt: DateTime.now(),
    );
  }

  /// 違反があるか
  bool get isClean => violations.isEmpty;

  /// 違反カテゴリのリスト
  List<NgWordCategory> get violatedCategories =>
      violations.map((v) => v.category).toSet().toList();

  /// 最大重大度
  int get maxSeverity =>
      violations.isEmpty ? 0 : violations.map((v) => v.severity).reduce((a, b) => a > b ? a : b);

  /// メッセージ
  String get message {
    if (isClean) return '';
    return violations.map((v) => v.category.blockMessage).toSet().join('\n');
  }

  @override
  String toString() {
    return 'ContentCheckResult('
        'clean: $isClean, '
        'violations: ${violations.length}, '
        'maxSeverity: $maxSeverity)';
  }
}

/// フィルタ統計
class FilterStats {
  final FilterStrictness strictness;
  final bool localCheckOnly;
  final bool serverModerationEnabled;

  const FilterStats({
    required this.strictness,
    required this.localCheckOnly,
    required this.serverModerationEnabled,
  });

  @override
  String toString() {
    return 'FilterStats('
        'strictness: ${strictness.name}, '
        'localOnly: $localCheckOnly, '
        'serverEnabled: $serverModerationEnabled)';
  }
}
