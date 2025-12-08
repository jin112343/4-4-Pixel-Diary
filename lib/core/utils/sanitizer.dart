/// 入力サニタイズユーティリティ
class Sanitizer {
  Sanitizer._();

  /// HTMLエスケープ
  static String escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#039;');
  }

  /// HTMLタグを除去
  static String stripHtml(String input) {
    return input.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  /// 制御文字を除去
  static String stripControlCharacters(String input) {
    return input.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
  }

  /// 空白を正規化（連続する空白を1つに）
  static String normalizeWhitespace(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// SQLインジェクション対策（基本的なエスケープ）
  /// 注意: DynamoDBではSQLインジェクションはないが、他のDB連携時に使用
  static String escapeSql(String input) {
    return input
        .replaceAll("'", "''")
        .replaceAll('\\', '\\\\')
        .replaceAll('\x00', '\\0')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\x1a', '\\Z');
  }

  /// URLエンコード
  static String encodeUrl(String input) {
    return Uri.encodeComponent(input);
  }

  /// 安全な文字列に変換（総合サニタイズ）
  static String sanitize(String input) {
    var result = input;
    result = stripControlCharacters(result);
    result = normalizeWhitespace(result);
    result = escapeHtml(result);
    return result;
  }

  /// ユーザー入力用サニタイズ（タイトル、ニックネームなど）
  static String sanitizeUserInput(String input, {int? maxLength}) {
    var result = input;
    result = stripControlCharacters(result);
    result = stripHtml(result);
    result = normalizeWhitespace(result);

    if (maxLength != null && result.length > maxLength) {
      result = result.substring(0, maxLength);
    }

    return result;
  }

  /// ファイル名サニタイズ（パストラバーサル対策）
  static String sanitizeFileName(String input) {
    return input
        .replaceAll(RegExp(r'[/\\:*?"<>|]'), '_')
        .replaceAll('..', '_')
        .trim();
  }

  /// JSONエスケープ
  static String escapeJson(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  /// 数値のみを抽出
  static String extractNumbers(String input) {
    return input.replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// 英数字のみを抽出
  static String extractAlphanumeric(String input) {
    return input.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  }

  /// 日本語文字（ひらがな、カタカナ、漢字）と英数字のみを抽出
  static String extractJapaneseAndAlphanumeric(String input) {
    return input.replaceAll(
      RegExp(r'[^\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFFa-zA-Z0-9\s]'),
      '',
    );
  }
}

/// サニタイズ結果
class SanitizeResult {
  final String sanitized;
  final bool wasModified;
  final List<String> modifications;

  const SanitizeResult({
    required this.sanitized,
    required this.wasModified,
    this.modifications = const [],
  });
}

/// 詳細なサニタイズ（変更を追跡）
class DetailedSanitizer {
  DetailedSanitizer._();

  static SanitizeResult sanitizeWithDetails(String input) {
    final modifications = <String>[];
    var result = input;

    // 制御文字の除去
    final afterControlChars = Sanitizer.stripControlCharacters(result);
    if (afterControlChars != result) {
      modifications.add('制御文字を除去');
      result = afterControlChars;
    }

    // HTMLタグの除去
    final afterHtml = Sanitizer.stripHtml(result);
    if (afterHtml != result) {
      modifications.add('HTMLタグを除去');
      result = afterHtml;
    }

    // 空白の正規化
    final afterWhitespace = Sanitizer.normalizeWhitespace(result);
    if (afterWhitespace != result) {
      modifications.add('空白を正規化');
      result = afterWhitespace;
    }

    return SanitizeResult(
      sanitized: result,
      wasModified: modifications.isNotEmpty,
      modifications: modifications,
    );
  }
}
