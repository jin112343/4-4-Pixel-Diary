import 'logger.dart';

/// コンテンツフィルタ（NGワードチェック）
class ContentFilter {
  ContentFilter._();

  // 基本的なNGワードリスト
  // 実際の運用では外部ファイルやサーバーから取得
  static const List<String> _ngWords = [
    // 暴力的な表現
    '殺す', '殺せ', '死ね', 'ころす', 'ころせ', 'しね',
    // 差別的な表現
    // （実際の運用ではより包括的なリストを使用）
  ];

  // 部分一致でブロックする単語
  static const List<String> _ngPartialWords = [
    // 暴力的な表現の一部
  ];

  // 正規表現パターン
  static final List<RegExp> _ngPatterns = [
    // URLパターン（スパム対策）
    RegExp(r'https?://[^\s]+', caseSensitive: false),
    // メールアドレスパターン（個人情報保護）
    RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+', caseSensitive: false),
    // 電話番号パターン
    RegExp(r'\d{2,4}[-\s]?\d{2,4}[-\s]?\d{3,4}'),
  ];

  /// NGワードチェック
  static ContentCheckResult check(String text) {
    final violations = <String>[];
    final lowerText = text.toLowerCase();

    // 完全一致チェック
    for (final word in _ngWords) {
      if (lowerText.contains(word.toLowerCase())) {
        violations.add('禁止ワード: $word');
      }
    }

    // 部分一致チェック
    for (final word in _ngPartialWords) {
      if (lowerText.contains(word.toLowerCase())) {
        violations.add('禁止表現: $word');
      }
    }

    // 正規表現パターンチェック
    for (final pattern in _ngPatterns) {
      if (pattern.hasMatch(text)) {
        violations.add('禁止パターン検出');
      }
    }

    return ContentCheckResult(
      isClean: violations.isEmpty,
      violations: violations,
      originalText: text,
    );
  }

  /// NGワードをマスク（****に置換）
  static String mask(String text) {
    var result = text;

    // NGワードをマスク
    for (final word in _ngWords) {
      final pattern = RegExp(RegExp.escape(word), caseSensitive: false);
      result = result.replaceAll(pattern, '*' * word.length);
    }

    // 部分一致ワードをマスク
    for (final word in _ngPartialWords) {
      final pattern = RegExp(RegExp.escape(word), caseSensitive: false);
      result = result.replaceAll(pattern, '*' * word.length);
    }

    // URLをマスク
    result = result.replaceAll(
      RegExp(r'https?://[^\s]+', caseSensitive: false),
      '[URL削除]',
    );

    // メールアドレスをマスク
    result = result.replaceAll(
      RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+', caseSensitive: false),
      '[メール削除]',
    );

    return result;
  }

  /// テキストが安全かどうか（クイックチェック）
  static bool isSafe(String text) {
    return check(text).isClean;
  }

  /// カスタムNGワードを追加（実行時）
  static final List<String> _customNgWords = [];

  static void addCustomNgWord(String word) {
    if (!_customNgWords.contains(word.toLowerCase())) {
      _customNgWords.add(word.toLowerCase());
    }
  }

  static void addCustomNgWords(List<String> words) {
    for (final word in words) {
      addCustomNgWord(word);
    }
  }

  /// サーバーからNGワードリストを更新
  static Future<void> updateFromServer(List<String> serverNgWords) async {
    _customNgWords.clear();
    _customNgWords.addAll(serverNgWords.map((w) => w.toLowerCase()));
    logger.i('NGワードリストを更新: ${_customNgWords.length}件');
  }
}

/// コンテンツチェック結果
class ContentCheckResult {
  final bool isClean;
  final List<String> violations;
  final String originalText;

  const ContentCheckResult({
    required this.isClean,
    required this.violations,
    required this.originalText,
  });

  String get message {
    if (isClean) {
      return 'コンテンツは問題ありません';
    }
    return '不適切なコンテンツが検出されました: ${violations.join(', ')}';
  }

  @override
  String toString() {
    return 'ContentCheckResult(isClean: $isClean, violations: $violations)';
  }
}

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

    // NGワードチェック
    final checkResult = ContentFilter.check(title);
    if (!checkResult.isClean) {
      return FilterResult(
        isValid: false,
        filtered: ContentFilter.mask(title),
        error: '不適切な表現が含まれています',
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
        error: '不適切な表現が含まれています',
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

    // NGワードチェック
    final checkResult = ContentFilter.check(nickname);
    if (!checkResult.isClean) {
      return FilterResult(
        isValid: false,
        filtered: ContentFilter.mask(nickname),
        error: '不適切な表現が含まれています',
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
