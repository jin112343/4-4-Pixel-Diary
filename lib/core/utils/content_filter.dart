import '../constants/ng_word_dictionary.dart';
import 'logger.dart';
import 'text_normalizer.dart';

/// 多層コンテンツフィルタリングシステム
/// 任天堂レベルの厳格なフィルタリングを実現
///
/// フィルタリング層:
/// 1. 許可リスト（Allowlist）チェック
/// 2. 完全一致NGワードチェック
/// 3. 正規化後のNGワードチェック
/// 4. 正規表現パターンチェック
/// 5. カテゴリ別パターンチェック
/// 6. 変種表現チェック（伏せ字・リートスピーク等）
/// 7. AI補助分析（オプション）
class ContentFilter {
  ContentFilter._();

  // ============================================================
  // 設定
  // ============================================================

  /// フィルタの厳格度
  static FilterStrictness _strictness = FilterStrictness.strict;

  /// カスタムNGワード（実行時追加）
  static final List<String> _customNgWords = [];

  /// カスタム許可ワード（実行時追加）
  static final List<String> _customAllowWords = [];

  /// カテゴリ別ブロック設定
  static final Map<NgWordCategory, bool> _categoryBlocking = {
    NgWordCategory.violence: true,
    NgWordCategory.sexual: true,
    NgWordCategory.discrimination: true,
    NgWordCategory.hate: true,
    NgWordCategory.profanity: true,
    NgWordCategory.copyright: true,
    NgWordCategory.personal: true,
    NgWordCategory.pattern: true,
    NgWordCategory.spam: true,
  };

  /// フィルタ厳格度を設定
  static void setStrictness(FilterStrictness strictness) {
    _strictness = strictness;
    logger.i('ContentFilter: 厳格度を ${strictness.name} に設定');
  }

  /// カテゴリのブロック設定を変更
  static void setCategoryBlocking(NgWordCategory category, bool block) {
    _categoryBlocking[category] = block;
    logger.i(
      'ContentFilter: ${category.displayName} のブロックを ${block ? "有効" : "無効"} に設定',
    );
  }

  // ============================================================
  // メインフィルタリングメソッド
  // ============================================================

  /// 総合コンテンツチェック
  /// 多層フィルタリングを実行し、詳細な結果を返す
  static ContentCheckResult check(String text) {
    if (text.isEmpty) {
      return ContentCheckResult.clean(text);
    }

    final violations = <ContentViolation>[];
    final originalText = text;

    // 層1: 許可リストによる事前除外
    final cleanedText = _removeAllowedWords(text);

    // 層2: 完全一致チェック（オリジナルテキスト）
    violations.addAll(_checkExactMatch(originalText));

    // 層3: 正規化後チェック
    final normalizedText = TextNormalizer.normalize(text);
    violations.addAll(_checkNormalizedMatch(normalizedText, originalText));

    // 層4: 正規表現パターンチェック
    violations.addAll(_checkPatterns(originalText));

    // 層5: カテゴリ別パターンチェック
    violations.addAll(_checkCategoryPatterns(originalText));

    // 層6: 変種表現チェック（厳格モード時のみ）
    if (_strictness == FilterStrictness.strict ||
        _strictness == FilterStrictness.nintendo) {
      violations.addAll(_checkVariations(text));
    }

    // 層7: 超厳格正規化後のチェック（任天堂モード時のみ）
    if (_strictness == FilterStrictness.nintendo) {
      final strictNormalized = TextNormalizer.normalizeStrict(text);
      violations.addAll(_checkNormalizedMatch(strictNormalized, originalText));
    }

    // 重複除去
    final uniqueViolations = _deduplicateViolations(violations);

    // カテゴリ別フィルタリング
    final filteredByCategory = _filterByCategory(uniqueViolations);

    // 厳格度に基づくフィルタリング
    final filteredViolations = _filterBySeverity(filteredByCategory);

    return ContentCheckResult(
      isClean: filteredViolations.isEmpty,
      violations: filteredViolations,
      originalText: originalText,
      normalizedText: normalizedText,
      maxSeverity: _getMaxSeverity(filteredViolations),
    );
  }

  /// クイックチェック（パフォーマンス重視）
  static bool isSafe(String text) {
    if (text.isEmpty) return true;

    // 軽量正規化のみ適用
    final normalizedText = TextNormalizer.normalizeLight(text);

    // 高重大度のNGワードのみチェック
    for (final word in NgWordDictionary.violenceJa) {
      if (normalizedText.contains(word.toLowerCase())) {
        return false;
      }
    }
    for (final word in NgWordDictionary.discriminationJa) {
      if (normalizedText.contains(word.toLowerCase())) {
        return false;
      }
    }
    for (final word in NgWordDictionary.violenceEn) {
      if (normalizedText.contains(word.toLowerCase())) {
        return false;
      }
    }
    for (final word in NgWordDictionary.discriminationEn) {
      if (normalizedText.contains(word.toLowerCase())) {
        return false;
      }
    }

    return true;
  }

  /// 超厳格チェック（任天堂レベル）
  /// すべての回避パターンを検出
  static ContentCheckResult checkStrict(String text) {
    if (text.isEmpty) {
      return ContentCheckResult.clean(text);
    }

    final violations = <ContentViolation>[];
    final originalText = text;

    // チェック対象のテキストバリエーションを生成
    final textVariations = <String>{
      text,
      text.toLowerCase(),
      // 空白をすべて除去
      text.replaceAll(RegExp(r'\s+'), ''),
      // 記号をすべて除去
      text.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''),
      // 正規化版
      TextNormalizer.normalize(text),
      // 軽量正規化版
      TextNormalizer.normalizeLight(text),
      // 超厳格正規化版
      TextNormalizer.normalizeStrict(text),
      // 数字→文字変換版
      TextNormalizer.convertNumbersToChars(text),
      // スペース除去版
      TextNormalizer.removeInterspersedSpaces(text),
      // 記号除去版
      TextNormalizer.removeInterspersedPunctuation(text),
    };

    // さらに変種を追加
    textVariations.addAll(TextNormalizer.generateVariations(text));

    // 伏せ字展開版
    textVariations.addAll(TextNormalizer.expandMaskedPatterns(text));

    // 各バリエーションをチェック
    for (final variant in textVariations) {
      if (variant.isEmpty) continue;

      final lowerVariant = variant.toLowerCase();

      // 全カテゴリのNGワードをチェック
      for (final entry in NgWordDictionary.categoryMap.entries) {
        final category = entry.key;
        final words = entry.value;

        for (final word in words) {
          final lowerWord = word.toLowerCase();
          if (lowerVariant.contains(lowerWord)) {
            // 許可リストに含まれる場合はスキップ
            if (!_isPartOfAllowedWord(variant, word)) {
              violations.add(ContentViolation(
                word: word,
                category: category,
                matchType: MatchType.variation,
                position: lowerVariant.indexOf(lowerWord),
              ));
            }
          }
        }
      }
    }

    // パターンマッチもチェック
    violations.addAll(_checkPatterns(originalText));
    violations.addAll(_checkCategoryPatterns(originalText));

    // 重複除去
    final uniqueViolations = _deduplicateViolations(violations);

    return ContentCheckResult(
      isClean: uniqueViolations.isEmpty,
      violations: uniqueViolations,
      originalText: originalText,
      normalizedText: TextNormalizer.normalize(text),
      maxSeverity: _getMaxSeverity(uniqueViolations),
    );
  }

  // ============================================================
  // 層別チェックメソッド
  // ============================================================

  /// 許可ワードを除去
  static String _removeAllowedWords(String text) {
    var result = text;
    final allAllowWords = [
      ...NgWordDictionary.allowlist,
      ..._customAllowWords,
    ];

    for (final word in allAllowWords) {
      // 許可ワードを一時的なプレースホルダーに置換
      result = result.replaceAll(
        RegExp(RegExp.escape(word), caseSensitive: false),
        '\u0000' * word.length, // NULL文字に置換
      );
    }
    return result;
  }

  /// 完全一致チェック
  static List<ContentViolation> _checkExactMatch(String text) {
    final violations = <ContentViolation>[];
    final lowerText = text.toLowerCase();

    // カテゴリ別にチェック
    for (final entry in NgWordDictionary.categoryMap.entries) {
      final category = entry.key;
      final words = entry.value;

      for (final word in words) {
        if (lowerText.contains(word.toLowerCase())) {
          // 許可リストに含まれる単語内でのマッチは除外
          if (!_isPartOfAllowedWord(text, word)) {
            violations.add(ContentViolation(
              word: word,
              category: category,
              matchType: MatchType.exact,
              position: lowerText.indexOf(word.toLowerCase()),
            ));
          }
        }
      }
    }

    // カスタムNGワードもチェック
    for (final word in _customNgWords) {
      if (lowerText.contains(word.toLowerCase())) {
        violations.add(ContentViolation(
          word: word,
          category: NgWordCategory.profanity,
          matchType: MatchType.exact,
          position: lowerText.indexOf(word.toLowerCase()),
        ));
      }
    }

    return violations;
  }

  /// 正規化後マッチチェック
  static List<ContentViolation> _checkNormalizedMatch(
    String normalizedText,
    String originalText,
  ) {
    final violations = <ContentViolation>[];

    for (final entry in NgWordDictionary.categoryMap.entries) {
      final category = entry.key;
      final words = entry.value;

      for (final word in words) {
        final normalizedWord = TextNormalizer.normalize(word);
        if (normalizedText.contains(normalizedWord)) {
          // オリジナルテキストでの位置を推定
          violations.add(ContentViolation(
            word: word,
            category: category,
            matchType: MatchType.normalized,
            position: normalizedText.indexOf(normalizedWord),
          ));
        }
      }
    }

    return violations;
  }

  /// パターンマッチチェック
  static List<ContentViolation> _checkPatterns(String text) {
    final violations = <ContentViolation>[];

    for (final pattern in NgWordDictionary.ngPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        violations.add(ContentViolation(
          word: match.group(0) ?? 'パターン検出',
          category: NgWordCategory.pattern,
          matchType: MatchType.pattern,
          position: match.start,
        ));
      }
    }

    return violations;
  }

  /// カテゴリ別パターンチェック
  static List<ContentViolation> _checkCategoryPatterns(String text) {
    final violations = <ContentViolation>[];

    for (final entry in NgWordDictionary.patternMap.entries) {
      final category = entry.key;
      final patterns = entry.value;

      for (final pattern in patterns) {
        final match = pattern.firstMatch(text);
        if (match != null) {
          violations.add(ContentViolation(
            word: match.group(0) ?? 'パターン検出',
            category: category,
            matchType: MatchType.categoryPattern,
            position: match.start,
          ));
        }
      }
    }

    return violations;
  }

  /// 変種表現チェック（伏せ字、数字置換など）
  static List<ContentViolation> _checkVariations(String text) {
    final violations = <ContentViolation>[];
    final variations = TextNormalizer.generateVariations(text);

    for (final variation in variations) {
      if (variation == text) continue; // 元のテキストはスキップ

      for (final entry in NgWordDictionary.categoryMap.entries) {
        final category = entry.key;
        final words = entry.value;

        for (final word in words) {
          if (variation.toLowerCase().contains(word.toLowerCase())) {
            violations.add(ContentViolation(
              word: word,
              category: category,
              matchType: MatchType.variation,
              position: -1, // 変種からの検出は位置不明
            ));
          }
        }
      }
    }

    return violations;
  }

  /// 許可ワードの一部かどうかチェック
  static bool _isPartOfAllowedWord(String text, String ngWord) {
    final lowerText = text.toLowerCase();
    final lowerNgWord = ngWord.toLowerCase();
    final allAllowWords = [
      ...NgWordDictionary.allowlist,
      ..._customAllowWords,
    ];

    for (final allowWord in allAllowWords) {
      final lowerAllowWord = allowWord.toLowerCase();
      if (lowerAllowWord.contains(lowerNgWord)) {
        // 許可ワードがテキストに含まれているかチェック
        if (lowerText.contains(lowerAllowWord)) {
          return true;
        }
      }
    }
    return false;
  }

  /// 重複除去
  static List<ContentViolation> _deduplicateViolations(
    List<ContentViolation> violations,
  ) {
    final seen = <String>{};
    final unique = <ContentViolation>[];

    for (final v in violations) {
      final key = '${v.word}_${v.category}';
      if (!seen.contains(key)) {
        seen.add(key);
        unique.add(v);
      }
    }

    return unique;
  }

  /// カテゴリ別フィルタリング
  static List<ContentViolation> _filterByCategory(
    List<ContentViolation> violations,
  ) {
    return violations.where((v) {
      return _categoryBlocking[v.category] ?? true;
    }).toList();
  }

  /// 厳格度に基づくフィルタリング
  static List<ContentViolation> _filterBySeverity(
    List<ContentViolation> violations,
  ) {
    final minSeverity = _strictness.minSeverity;
    return violations
        .where((v) => v.category.severity >= minSeverity)
        .toList();
  }

  /// 最大重大度を取得
  static int _getMaxSeverity(List<ContentViolation> violations) {
    if (violations.isEmpty) return 0;
    return violations
        .map((v) => v.category.severity)
        .reduce((a, b) => a > b ? a : b);
  }

  // ============================================================
  // マスキング機能
  // ============================================================

  /// NGワードをマスク
  static String mask(String text, {String maskChar = '*'}) {
    var result = text;

    // 全カテゴリのNGワードをマスク
    for (final words in NgWordDictionary.categoryMap.values) {
      for (final word in words) {
        // 許可リストに含まれる場合はスキップ
        if (_isPartOfAllowedWord(text, word)) continue;

        final pattern = RegExp(RegExp.escape(word), caseSensitive: false);
        result = result.replaceAll(pattern, maskChar * word.length);
      }
    }

    // カスタムNGワードもマスク
    for (final word in _customNgWords) {
      final pattern = RegExp(RegExp.escape(word), caseSensitive: false);
      result = result.replaceAll(pattern, maskChar * word.length);
    }

    // パターンマッチしたものもマスク
    // URL
    result = result.replaceAll(
      RegExp(r'https?://[^\s]+', caseSensitive: false),
      '[URL削除]',
    );
    // メールアドレス
    result = result.replaceAll(
      RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+', caseSensitive: false),
      '[メール削除]',
    );
    // 電話番号
    result = result.replaceAll(
      RegExp(r'\d{2,4}[-\s]?\d{2,4}[-\s]?\d{3,4}'),
      '[電話番号削除]',
    );

    return result;
  }

  /// 部分マスク（最初と最後の文字を残す）
  static String maskPartial(String text, {String maskChar = '*'}) {
    var result = text;

    for (final words in NgWordDictionary.categoryMap.values) {
      for (final word in words) {
        if (_isPartOfAllowedWord(text, word)) continue;
        if (word.length <= 2) continue;

        final pattern = RegExp(RegExp.escape(word), caseSensitive: false);
        result = result.replaceAllMapped(pattern, (match) {
          final matched = match.group(0)!;
          if (matched.length <= 2) return maskChar * matched.length;
          return matched[0] +
              maskChar * (matched.length - 2) +
              matched[matched.length - 1];
        });
      }
    }

    return result;
  }

  // ============================================================
  // カスタムワード管理
  // ============================================================

  /// カスタムNGワードを追加
  static void addCustomNgWord(String word) {
    final normalized = word.toLowerCase().trim();
    if (normalized.isNotEmpty && !_customNgWords.contains(normalized)) {
      _customNgWords.add(normalized);
      logger.d('ContentFilter: カスタムNGワード追加: $word');
    }
  }

  /// カスタムNGワードを一括追加
  static void addCustomNgWords(List<String> words) {
    for (final word in words) {
      addCustomNgWord(word);
    }
  }

  /// カスタム許可ワードを追加
  static void addCustomAllowWord(String word) {
    final normalized = word.toLowerCase().trim();
    if (normalized.isNotEmpty && !_customAllowWords.contains(normalized)) {
      _customAllowWords.add(normalized);
      logger.d('ContentFilter: カスタム許可ワード追加: $word');
    }
  }

  /// カスタム許可ワードを一括追加
  static void addCustomAllowWords(List<String> words) {
    for (final word in words) {
      addCustomAllowWord(word);
    }
  }

  /// サーバーからNGワードリストを更新
  static Future<void> updateFromServer({
    List<String>? ngWords,
    List<String>? allowWords,
  }) async {
    if (ngWords != null) {
      _customNgWords.clear();
      _customNgWords.addAll(ngWords.map((w) => w.toLowerCase()));
      logger.i('ContentFilter: NGワードリストを更新: ${_customNgWords.length}件');
    }
    if (allowWords != null) {
      _customAllowWords.clear();
      _customAllowWords.addAll(allowWords.map((w) => w.toLowerCase()));
      logger.i(
        'ContentFilter: 許可ワードリストを更新: ${_customAllowWords.length}件',
      );
    }
  }

  /// カスタムワードをクリア
  static void clearCustomWords() {
    _customNgWords.clear();
    _customAllowWords.clear();
    logger.i('ContentFilter: カスタムワードをクリア');
  }

  // ============================================================
  // 統計・デバッグ
  // ============================================================

  /// フィルタ統計情報を取得
  static FilterStats getStats() {
    return FilterStats(
      totalNgWords: NgWordDictionary.allNgWords.length + _customNgWords.length,
      totalAllowWords:
          NgWordDictionary.allowlist.length + _customAllowWords.length,
      customNgWords: _customNgWords.length,
      customAllowWords: _customAllowWords.length,
      strictness: _strictness,
      categoryStats: NgWordDictionary.stats,
    );
  }
}

// ============================================================
// データクラス
// ============================================================

/// フィルタ厳格度
enum FilterStrictness {
  /// 軽度: 重大な違反のみ検出（severity >= 4）
  light,

  /// 標準: 一般的な違反を検出（severity >= 3）
  normal,

  /// 厳格: ほとんどの違反を検出（severity >= 2）
  strict,

  /// 任天堂レベル: 全ての違反を検出、変種表現も検査
  nintendo,
}

extension FilterStrictnessExtension on FilterStrictness {
  int get minSeverity {
    switch (this) {
      case FilterStrictness.light:
        return 4;
      case FilterStrictness.normal:
        return 3;
      case FilterStrictness.strict:
        return 2;
      case FilterStrictness.nintendo:
        return 1;
    }
  }

  String get displayName {
    switch (this) {
      case FilterStrictness.light:
        return '軽度';
      case FilterStrictness.normal:
        return '標準';
      case FilterStrictness.strict:
        return '厳格';
      case FilterStrictness.nintendo:
        return '任天堂レベル';
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

extension MatchTypeExtension on MatchType {
  String get displayName {
    switch (this) {
      case MatchType.exact:
        return '完全一致';
      case MatchType.normalized:
        return '正規化一致';
      case MatchType.pattern:
        return 'パターン一致';
      case MatchType.categoryPattern:
        return 'カテゴリパターン一致';
      case MatchType.variation:
        return '変種一致';
    }
  }
}

/// コンテンツ違反
class ContentViolation {
  final String word;
  final NgWordCategory category;
  final MatchType matchType;
  final int position;

  const ContentViolation({
    required this.word,
    required this.category,
    required this.matchType,
    required this.position,
  });

  @override
  String toString() {
    return 'ContentViolation('
        'word: $word, '
        'category: ${category.displayName}, '
        'matchType: ${matchType.displayName}, '
        'position: $position)';
  }
}

/// コンテンツチェック結果
class ContentCheckResult {
  final bool isClean;
  final List<ContentViolation> violations;
  final String originalText;
  final String normalizedText;
  final int maxSeverity;

  const ContentCheckResult({
    required this.isClean,
    required this.violations,
    required this.originalText,
    required this.normalizedText,
    required this.maxSeverity,
  });

  /// クリーンな結果を生成
  factory ContentCheckResult.clean(String text) {
    return ContentCheckResult(
      isClean: true,
      violations: [],
      originalText: text,
      normalizedText: TextNormalizer.normalize(text),
      maxSeverity: 0,
    );
  }

  /// メッセージを取得
  String get message {
    if (isClean) {
      return 'コンテンツは問題ありません';
    }
    final categories =
        violations.map((v) => v.category.displayName).toSet().join(', ');
    return '不適切なコンテンツが検出されました: $categories';
  }

  /// ユーザー向けメッセージ
  String get userMessage {
    if (isClean) return '';

    // 最も重大なカテゴリのメッセージを返す
    final maxCategory = violations
        .reduce((a, b) => a.category.severity > b.category.severity ? a : b)
        .category;
    return maxCategory.blockMessage;
  }

  /// 違反カテゴリ一覧
  List<NgWordCategory> get violatedCategories {
    return violations.map((v) => v.category).toSet().toList();
  }

  /// 検出されたNGワード一覧
  List<String> get detectedWords {
    return violations.map((v) => v.word).toSet().toList();
  }

  @override
  String toString() {
    return 'ContentCheckResult('
        'isClean: $isClean, '
        'violations: ${violations.length}, '
        'maxSeverity: $maxSeverity)';
  }
}

/// フィルタ統計
class FilterStats {
  final int totalNgWords;
  final int totalAllowWords;
  final int customNgWords;
  final int customAllowWords;
  final FilterStrictness strictness;
  final Map<String, int> categoryStats;

  const FilterStats({
    required this.totalNgWords,
    required this.totalAllowWords,
    required this.customNgWords,
    required this.customAllowWords,
    required this.strictness,
    this.categoryStats = const {},
  });

  @override
  String toString() {
    return 'FilterStats('
        'ngWords: $totalNgWords (custom: $customNgWords), '
        'allowWords: $totalAllowWords (custom: $customAllowWords), '
        'strictness: ${strictness.displayName})';
  }
}

// ============================================================
// 専用フィルタ（既存互換）
// ============================================================

/// タイトル専用フィルタ
class TitleFilter {
  TitleFilter._();

  static const int maxLength = 5;

  static FilterResult filter(String? title) {
    if (title == null || title.isEmpty) {
      return const FilterResult(
        isValid: true,
        filtered: '',
        error: null,
      );
    }

    // 長さチェック
    if (title.length > maxLength) {
      return FilterResult(
        isValid: false,
        filtered: title.substring(0, maxLength),
        error: 'タイトルは${maxLength}文字以内で入力してください',
      );
    }

    // 超厳格NGワードチェック（任天堂レベル）
    final checkResult = ContentFilter.checkStrict(title);
    if (!checkResult.isClean) {
      return FilterResult(
        isValid: false,
        filtered: ContentFilter.mask(title),
        error: checkResult.userMessage,
      );
    }

    return FilterResult(
      isValid: true,
      filtered: title,
      error: null,
    );
  }
}

/// コメント専用フィルタ
class CommentFilter {
  CommentFilter._();

  static const int maxLength = 50;

  static FilterResult filter(String content) {
    // 空チェック
    if (content.trim().isEmpty) {
      return const FilterResult(
        isValid: false,
        filtered: '',
        error: 'コメントを入力してください',
      );
    }

    // 長さチェック
    if (content.length > maxLength) {
      return FilterResult(
        isValid: false,
        filtered: content.substring(0, maxLength),
        error: 'コメントは${maxLength}文字以内で入力してください',
      );
    }

    // NGワードチェック
    final checkResult = ContentFilter.check(content);
    if (!checkResult.isClean) {
      return FilterResult(
        isValid: false,
        filtered: ContentFilter.mask(content),
        error: checkResult.userMessage,
      );
    }

    return FilterResult(
      isValid: true,
      filtered: content,
      error: null,
    );
  }
}

/// ニックネーム専用フィルタ
class NicknameFilter {
  NicknameFilter._();

  static const int maxLength = 5;

  static FilterResult filter(String? nickname) {
    if (nickname == null || nickname.isEmpty) {
      return const FilterResult(
        isValid: true,
        filtered: '',
        error: null,
      );
    }

    // 長さチェック
    if (nickname.length > maxLength) {
      return FilterResult(
        isValid: false,
        filtered: nickname.substring(0, maxLength),
        error: 'ニックネームは${maxLength}文字以内で入力してください',
      );
    }

    // 超厳格NGワードチェック（任天堂レベル）
    final checkResult = ContentFilter.checkStrict(nickname);
    if (!checkResult.isClean) {
      return FilterResult(
        isValid: false,
        filtered: ContentFilter.mask(nickname),
        error: checkResult.userMessage,
      );
    }

    return FilterResult(
      isValid: true,
      filtered: nickname,
      error: null,
    );
  }
}

/// フィルタ結果
class FilterResult {
  final bool isValid;
  final String filtered;
  final String? error;

  const FilterResult({
    required this.isValid,
    required this.filtered,
    this.error,
  });
}
