import '../constants/ng_word_dictionary.dart';

/// テキスト正規化ユーティリティ
/// フィルタ回避を防ぐためのテキスト前処理
class TextNormalizer {
  TextNormalizer._();

  /// テキストを正規化
  /// フィルタリング前にこのメソッドを使用して入力を正規化する
  static String normalize(String text) {
    var result = text;

    // 1. 空白の正規化
    result = _normalizeWhitespace(result);

    // 2. 全角 → 半角 変換
    result = _convertFullWidthToHalfWidth(result);

    // 3. 大文字 → 小文字
    result = result.toLowerCase();

    // 4. カタカナ → ひらがな 変換
    result = _convertKatakanaToHiragana(result);

    // 5. 類似文字の正規化
    result = _normalizeSimilarChars(result);

    // 6. 繰り返し文字の圧縮
    result = _compressRepeatingChars(result);

    // 7. 特殊文字の除去
    result = _removeSpecialChars(result);

    return result;
  }

  /// 軽量正規化（パフォーマンス重視の場合）
  static String normalizeLight(String text) {
    var result = text.toLowerCase();
    result = _convertFullWidthToHalfWidth(result);
    result = _normalizeWhitespace(result);
    return result;
  }

  /// 空白の正規化
  static String _normalizeWhitespace(String text) {
    // 連続する空白を単一スペースに
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// 全角 → 半角 変換
  static String _convertFullWidthToHalfWidth(String text) {
    final buffer = StringBuffer();
    for (final char in text.runes) {
      final charStr = String.fromCharCode(char);
      buffer.write(
        NgWordDictionary.fullWidthToHalfWidth[charStr] ?? charStr,
      );
    }
    return buffer.toString();
  }

  /// カタカナ → ひらがな 変換
  static String _convertKatakanaToHiragana(String text) {
    final buffer = StringBuffer();
    for (final char in text.runes) {
      final charStr = String.fromCharCode(char);
      buffer.write(
        NgWordDictionary.katakanaToHiragana[charStr] ?? charStr,
      );
    }
    return buffer.toString();
  }

  /// 類似文字の正規化
  static String _normalizeSimilarChars(String text) {
    var result = text;
    NgWordDictionary.similarCharMap.forEach((from, to) {
      result = result.replaceAll(from, to);
    });
    return result;
  }

  /// 繰り返し文字の圧縮（aaaa → aa）
  static String _compressRepeatingChars(String text) {
    // 3文字以上の繰り返しを2文字に圧縮
    return text.replaceAllMapped(
      RegExp(r'(.)\1{2,}'),
      (match) => '${match.group(1)}${match.group(1)}',
    );
  }

  /// 特殊文字の除去（文字間に挿入された記号等）
  static String _removeSpecialChars(String text) {
    // 文字間の装飾記号を除去
    // ただし意味のある記号は残す
    return text.replaceAll(
      RegExp(r'[*_~`|\\^]'),
      '',
    );
  }

  /// 伏せ字パターンの展開
  /// 「死○」→「死ね」「死んで」等に展開
  static List<String> expandMaskedPatterns(String text) {
    final results = <String>[text];

    // 「○」「●」「〇」を可能性のある文字に置換
    final maskedChars = ['○', '●', '〇', '◯', '*', '＊'];
    final replacements = {
      '死': ['ね', 'んで', 'のう'],
      '殺': ['す', 'せ', 'した'],
      'f': ['uck'],
      's': ['hit', 'ex'],
      'd': ['ie', 'ick'],
    };

    for (final masked in maskedChars) {
      if (text.contains(masked)) {
        // 伏せ字の前の文字を取得
        final pattern = RegExp('(.)$masked');
        final match = pattern.firstMatch(text);
        if (match != null) {
          final prefix = match.group(1)!;
          final possibleSuffixes = replacements[prefix] ?? [];
          for (final suffix in possibleSuffixes) {
            results.add(text.replaceFirst('$prefix$masked', '$prefix$suffix'));
          }
        }
      }
    }

    return results;
  }

  /// 文字間スペースを除去した文字列を生成
  /// 「f u c k」→「fuck」
  static String removeInterspersedSpaces(String text) {
    // 単一文字がスペースで区切られているパターンを検出
    final pattern = RegExp(r'^([a-z])\s+([a-z])(\s+[a-z])*$');
    if (pattern.hasMatch(text)) {
      return text.replaceAll(' ', '');
    }
    return text;
  }

  /// 数字を文字に変換したバリエーションを生成
  /// 「4ね」→「しね」、「h3ll0」→「hello」
  static String convertNumbersToChars(String text) {
    final numberMap = {
      '0': 'o',
      '1': 'i',
      '2': 'z',
      '3': 'e',
      '4': 'し', // 日本語特有
      '5': 's',
      '6': 'g',
      '7': 't',
      '8': 'b',
      '9': 'g',
    };

    var result = text;
    numberMap.forEach((num, char) {
      result = result.replaceAll(num, char);
    });
    return result;
  }

  /// 複数の正規化バリエーションを生成
  /// より厳格なチェックが必要な場合に使用
  static List<String> generateVariations(String text) {
    final variations = <String>{};

    // 基本の正規化
    variations.add(normalize(text));

    // 数字→文字変換版
    variations.add(convertNumbersToChars(text));
    variations.add(normalize(convertNumbersToChars(text)));

    // スペース除去版
    variations.add(removeInterspersedSpaces(text));
    variations.add(normalize(removeInterspersedSpaces(text)));

    // 伏せ字展開版
    variations.addAll(expandMaskedPatterns(text));

    return variations.toList();
  }
}

/// 文字種別判定ユーティリティ
class CharacterTypeUtil {
  CharacterTypeUtil._();

  /// ひらがなかどうか
  static bool isHiragana(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return code >= 0x3040 && code <= 0x309F;
  }

  /// カタカナかどうか
  static bool isKatakana(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return (code >= 0x30A0 && code <= 0x30FF) ||
        (code >= 0xFF66 && code <= 0xFF9F); // 半角カタカナ
  }

  /// 漢字かどうか
  static bool isKanji(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return (code >= 0x4E00 && code <= 0x9FFF) || // CJK統合漢字
        (code >= 0x3400 && code <= 0x4DBF); // CJK統合漢字拡張A
  }

  /// 日本語文字かどうか
  static bool isJapanese(String char) {
    return isHiragana(char) || isKatakana(char) || isKanji(char);
  }

  /// ASCII英数字かどうか
  static bool isAsciiAlphanumeric(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return (code >= 0x30 && code <= 0x39) || // 0-9
        (code >= 0x41 && code <= 0x5A) || // A-Z
        (code >= 0x61 && code <= 0x7A); // a-z
  }

  /// テキストに日本語が含まれるかどうか
  static bool containsJapanese(String text) {
    for (final char in text.runes) {
      final charStr = String.fromCharCode(char);
      if (isJapanese(charStr)) return true;
    }
    return false;
  }

  /// テキストの主要言語を推定
  static TextLanguage detectPrimaryLanguage(String text) {
    var japaneseCount = 0;
    var englishCount = 0;
    var totalCount = 0;

    for (final char in text.runes) {
      final charStr = String.fromCharCode(char);
      if (isJapanese(charStr)) {
        japaneseCount++;
        totalCount++;
      } else if (isAsciiAlphanumeric(charStr)) {
        englishCount++;
        totalCount++;
      }
    }

    if (totalCount == 0) return TextLanguage.unknown;
    if (japaneseCount > englishCount) return TextLanguage.japanese;
    if (englishCount > japaneseCount) return TextLanguage.english;
    return TextLanguage.mixed;
  }
}

/// テキストの言語
enum TextLanguage {
  japanese,
  english,
  mixed,
  unknown,
}
