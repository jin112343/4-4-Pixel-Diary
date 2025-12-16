/// 入力サニタイズユーティリティ
///
/// セキュリティ対策として、以下の2種類のサニタイズを提供:
/// 1. 入力時サニタイズ: ユーザー入力をサーバーに送信する前に適用
/// 2. 表示時サニタイズ: サーバーから受け取ったデータを表示する前に適用
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

  // ============================================================
  // 表示時サニタイズ（XSS対策）
  // ============================================================

  /// 表示用にサニタイズ（他ユーザーのコンテンツを表示する際に使用）
  ///
  /// - HTMLタグを除去
  /// - 制御文字を除去
  /// - 危険なURLスキームをブロック
  /// - 絵文字は許可
  static String sanitizeForDisplay(String input) {
    if (input.isEmpty) return input;

    var result = input;

    // HTMLタグを除去
    result = stripHtml(result);

    // 制御文字を除去（絵文字は保持）
    result = stripControlCharacters(result);

    // 危険なURLスキームを無効化
    result = neutralizeDangerousUrls(result);

    return result;
  }

  /// ニックネーム表示用サニタイズ
  static String sanitizeNicknameForDisplay(String? input) {
    if (input == null || input.isEmpty) {
      return '匿名';
    }

    var result = sanitizeForDisplay(input);

    // 長すぎる場合は切り詰め
    if (result.length > 10) {
      result = '${result.substring(0, 10)}…';
    }

    return result.isEmpty ? '匿名' : result;
  }

  /// コメント表示用サニタイズ
  static String sanitizeCommentForDisplay(String input) {
    if (input.isEmpty) return input;

    var result = sanitizeForDisplay(input);

    // 連続する改行を制限
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return result;
  }

  /// タイトル表示用サニタイズ
  static String sanitizeTitleForDisplay(String input) {
    if (input.isEmpty) return input;

    var result = sanitizeForDisplay(input);

    // 改行を除去（タイトルは1行）
    result = result.replaceAll(RegExp(r'[\r\n]'), ' ');

    // 空白を正規化
    result = normalizeWhitespace(result);

    return result;
  }

  /// 危険なURLスキームを無効化
  ///
  /// javascript:, data:, vbscript: などの危険なスキームを検出して無効化
  static String neutralizeDangerousUrls(String input) {
    // 危険なURLスキームのパターン
    final dangerousSchemes = RegExp(
      r'(javascript|vbscript|data|file|about|blob):\s*',
      caseSensitive: false,
    );

    return input.replaceAllMapped(dangerousSchemes, (match) {
      // スキームを無効化（表示はするが機能しない）
      return '[blocked]:';
    });
  }

  /// URLが安全かどうかをチェック
  static bool isUrlSafe(String url) {
    if (url.isEmpty) return false;

    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    // 許可されるスキーム
    const allowedSchemes = ['http', 'https', 'mailto'];

    return allowedSchemes.contains(uri.scheme.toLowerCase());
  }

  /// URLをサニタイズして安全な形式に変換
  static String? sanitizeUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // 危険なスキームのチェック
    final dangerousSchemes = ['javascript:', 'vbscript:', 'data:', 'file:', 'about:', 'blob:'];
    final lowerInput = trimmed.toLowerCase();

    for (final scheme in dangerousSchemes) {
      if (lowerInput.startsWith(scheme)) {
        return null;
      }
    }

    // スキームがない場合はhttpsを付与
    if (!trimmed.contains('://')) {
      return 'https://$trimmed';
    }

    // http/httpsのみ許可
    if (!lowerInput.startsWith('http://') && !lowerInput.startsWith('https://')) {
      return null;
    }

    return trimmed;
  }
}

/// サニタイズ結果
class SanitizeResult {
  const SanitizeResult({
    required this.sanitized,
    required this.wasModified,
    this.modifications = const [],
  });

  final String sanitized;
  final bool wasModified;
  final List<String> modifications;
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
