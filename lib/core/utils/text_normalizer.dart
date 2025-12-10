/// テキスト正規化ユーティリティ
/// フィルタ回避を防ぐためのテキスト前処理
class TextNormalizer {
  TextNormalizer._();

  // ============================================================
  // 文字マッピング定義
  // ============================================================

  /// 全角 → 半角 変換マップ
  static const Map<String, String> fullWidthToHalfWidth = {
    'Ａ': 'a', 'Ｂ': 'b', 'Ｃ': 'c', 'Ｄ': 'd', 'Ｅ': 'e',
    'Ｆ': 'f', 'Ｇ': 'g', 'Ｈ': 'h', 'Ｉ': 'i', 'Ｊ': 'j',
    'Ｋ': 'k', 'Ｌ': 'l', 'Ｍ': 'm', 'Ｎ': 'n', 'Ｏ': 'o',
    'Ｐ': 'p', 'Ｑ': 'q', 'Ｒ': 'r', 'Ｓ': 's', 'Ｔ': 't',
    'Ｕ': 'u', 'Ｖ': 'v', 'Ｗ': 'w', 'Ｘ': 'x', 'Ｙ': 'y', 'Ｚ': 'z',
    'ａ': 'a', 'ｂ': 'b', 'ｃ': 'c', 'ｄ': 'd', 'ｅ': 'e',
    'ｆ': 'f', 'ｇ': 'g', 'ｈ': 'h', 'ｉ': 'i', 'ｊ': 'j',
    'ｋ': 'k', 'ｌ': 'l', 'ｍ': 'm', 'ｎ': 'n', 'ｏ': 'o',
    'ｐ': 'p', 'ｑ': 'q', 'ｒ': 'r', 'ｓ': 's', 'ｔ': 't',
    'ｕ': 'u', 'ｖ': 'v', 'ｗ': 'w', 'ｘ': 'x', 'ｙ': 'y', 'ｚ': 'z',
    '０': '0', '１': '1', '２': '2', '３': '3', '４': '4',
    '５': '5', '６': '6', '７': '7', '８': '8', '９': '9',
    '！': '!', '？': '?', '＠': '@', '＃': '#', '＄': r'$',
    '％': '%', '＾': '^', '＆': '&', '＊': '*', '（': '(',
    '）': ')', '－': '-', '＝': '=', '＋': '+', '［': '[',
    '］': ']', '｛': '{', '｝': '}', '｜': '|', '＼': r'\',
    '：': ':', '；': ';', '"': '"', "'": "'", '＜': '<',
    '＞': '>', '，': ',', '．': '.', '／': '/', '～': '~',
  };

  /// カタカナ → ひらがな 変換マップ
  static const Map<String, String> katakanaToHiragana = {
    'ア': 'あ', 'イ': 'い', 'ウ': 'う', 'エ': 'え', 'オ': 'お',
    'カ': 'か', 'キ': 'き', 'ク': 'く', 'ケ': 'け', 'コ': 'こ',
    'サ': 'さ', 'シ': 'し', 'ス': 'す', 'セ': 'せ', 'ソ': 'そ',
    'タ': 'た', 'チ': 'ち', 'ツ': 'つ', 'テ': 'て', 'ト': 'と',
    'ナ': 'な', 'ニ': 'に', 'ヌ': 'ぬ', 'ネ': 'ね', 'ノ': 'の',
    'ハ': 'は', 'ヒ': 'ひ', 'フ': 'ふ', 'ヘ': 'へ', 'ホ': 'ほ',
    'マ': 'ま', 'ミ': 'み', 'ム': 'む', 'メ': 'め', 'モ': 'も',
    'ヤ': 'や', 'ユ': 'ゆ', 'ヨ': 'よ',
    'ラ': 'ら', 'リ': 'り', 'ル': 'る', 'レ': 'れ', 'ロ': 'ろ',
    'ワ': 'わ', 'ヲ': 'を', 'ン': 'ん',
    'ガ': 'が', 'ギ': 'ぎ', 'グ': 'ぐ', 'ゲ': 'げ', 'ゴ': 'ご',
    'ザ': 'ざ', 'ジ': 'じ', 'ズ': 'ず', 'ゼ': 'ぜ', 'ゾ': 'ぞ',
    'ダ': 'だ', 'ヂ': 'ぢ', 'ヅ': 'づ', 'デ': 'で', 'ド': 'ど',
    'バ': 'ば', 'ビ': 'び', 'ブ': 'ぶ', 'ベ': 'べ', 'ボ': 'ぼ',
    'パ': 'ぱ', 'ピ': 'ぴ', 'プ': 'ぷ', 'ペ': 'ぺ', 'ポ': 'ぽ',
    'ァ': 'ぁ', 'ィ': 'ぃ', 'ゥ': 'ぅ', 'ェ': 'ぇ', 'ォ': 'ぉ',
    'ッ': 'っ', 'ャ': 'ゃ', 'ュ': 'ゅ', 'ョ': 'ょ',
    'ヴ': 'ゔ', 'ー': 'ー',
  };

  /// 類似文字マッピング（Unicodeホモグリフ対策）
  static const Map<String, String> similarCharMap = {
    // キリル文字 → ラテン文字
    'а': 'a', 'А': 'a', 'в': 'b', 'В': 'b',
    'с': 'c', 'С': 'c', 'е': 'e', 'Е': 'e',
    'һ': 'h', 'Һ': 'h', 'і': 'i', 'І': 'i',
    'ј': 'j', 'Ј': 'j', 'к': 'k', 'К': 'k',
    'м': 'm', 'М': 'm', 'о': 'o', 'О': 'o',
    'р': 'p', 'Р': 'p', 'ѕ': 's', 'Ѕ': 's',
    'т': 't', 'Т': 't', 'у': 'y', 'У': 'y',
    'х': 'x', 'Х': 'x',
    // ギリシャ文字
    'α': 'a', 'Α': 'a', 'β': 'b', 'Β': 'b',
    'γ': 'y', 'Γ': 'y', 'ε': 'e', 'Ε': 'e',
    'η': 'n', 'Η': 'n', 'ι': 'i', 'Ι': 'i',
    'κ': 'k', 'Κ': 'k', 'ν': 'v', 'Ν': 'n',
    'ο': 'o', 'Ο': 'o', 'ρ': 'p', 'Ρ': 'p',
    'τ': 't', 'Τ': 't', 'υ': 'u', 'Υ': 'y',
    'χ': 'x', 'Χ': 'x',
    // リートスピーク
    '0': 'o', '1': 'l', '3': 'e', '4': 'a',
    '5': 's', '7': 't', '8': 'b', '@': 'a',
    r'$': 's', '!': 'i', '+': 't',
    // 特殊文字
    'ℓ': 'l', '℮': 'e', '№': 'no',
    '™': 'tm', '©': 'c', '®': 'r',
  };

  // ============================================================
  // ゼロ幅文字・不可視文字の定義
  // ============================================================

  /// ゼロ幅文字・不可視文字のコードポイント
  static const List<int> invisibleCharCodes = [
    0x0000, // Null
    0x00AD, // Soft Hyphen
    0x034F, // Combining Grapheme Joiner
    0x061C, // Arabic Letter Mark
    0x115F, // Hangul Choseong Filler
    0x1160, // Hangul Jungseong Filler
    0x17B4, // Khmer Vowel Inherent Aq
    0x17B5, // Khmer Vowel Inherent Aa
    0x180E, // Mongolian Vowel Separator
    0x2000, // En Quad
    0x2001, // Em Quad
    0x2002, // En Space
    0x2003, // Em Space
    0x2004, // Three-Per-Em Space
    0x2005, // Four-Per-Em Space
    0x2006, // Six-Per-Em Space
    0x2007, // Figure Space
    0x2008, // Punctuation Space
    0x2009, // Thin Space
    0x200A, // Hair Space
    0x200B, // Zero Width Space
    0x200C, // Zero Width Non-Joiner
    0x200D, // Zero Width Joiner
    0x200E, // Left-To-Right Mark
    0x200F, // Right-To-Left Mark
    0x202A, // Left-To-Right Embedding
    0x202B, // Right-To-Left Embedding
    0x202C, // Pop Directional Formatting
    0x202D, // Left-To-Right Override
    0x202E, // Right-To-Left Override
    0x2060, // Word Joiner
    0x2061, // Function Application
    0x2062, // Invisible Times
    0x2063, // Invisible Separator
    0x2064, // Invisible Plus
    0x206A, // Inhibit Symmetric Swapping
    0x206B, // Activate Symmetric Swapping
    0x206C, // Inhibit Arabic Form Shaping
    0x206D, // Activate Arabic Form Shaping
    0x206E, // National Digit Shapes
    0x206F, // Nominal Digit Shapes
    0xFEFF, // Zero Width No-Break Space (BOM)
    0xFFA0, // Halfwidth Hangul Filler
    0xFFF9, // Interlinear Annotation Anchor
    0xFFFA, // Interlinear Annotation Separator
    0xFFFB, // Interlinear Annotation Terminator
  ];

  // ============================================================
  // メイン正規化メソッド
  // ============================================================

  /// テキストを正規化
  /// フィルタリング前にこのメソッドを使用して入力を正規化する
  static String normalize(String text) {
    if (text.isEmpty) return text;

    var result = text;

    // 1. ゼロ幅文字・不可視文字の除去
    result = removeInvisibleChars(result);

    // 2. Unicode正規化（NFKC）
    result = unicodeNormalize(result);

    // 3. 空白の正規化
    result = _normalizeWhitespace(result);

    // 4. 全角 → 半角 変換
    result = _convertFullWidthToHalfWidth(result);

    // 5. 大文字 → 小文字
    result = result.toLowerCase();

    // 6. カタカナ → ひらがな 変換
    result = _convertKatakanaToHiragana(result);

    // 7. 類似文字の正規化（Unicodeホモグリフ対策）
    result = _normalizeSimilarChars(result);

    // 8. 日本語特殊置換（漢字当て字対策）
    result = _normalizeJapaneseSubstitutions(result);

    // 9. 繰り返し文字の圧縮
    result = _compressRepeatingChars(result);

    // 10. 特殊文字の除去
    result = _removeSpecialChars(result);

    return result;
  }

  /// 軽量正規化（パフォーマンス重視の場合）
  static String normalizeLight(String text) {
    if (text.isEmpty) return text;

    var result = text;
    result = removeInvisibleChars(result);
    result = result.toLowerCase();
    result = _convertFullWidthToHalfWidth(result);
    result = _normalizeWhitespace(result);
    return result;
  }

  /// 超厳格正規化（任天堂レベル）
  static String normalizeStrict(String text) {
    if (text.isEmpty) return text;

    var result = normalize(text);

    // 追加: 数字→文字変換
    result = convertNumbersToChars(result);

    // 追加: 日本語数字置換（4ね→しね）
    result = convertJapaneseNumberSubstitutions(result);

    // 追加: すべての空白・記号を除去
    result = result.replaceAll(RegExp(r'[\s\p{P}\p{S}]', unicode: true), '');

    return result;
  }

  // ============================================================
  // ゼロ幅文字・不可視文字の処理
  // ============================================================

  /// ゼロ幅文字・不可視文字を除去
  static String removeInvisibleChars(String text) {
    if (text.isEmpty) return text;

    final buffer = StringBuffer();
    for (final rune in text.runes) {
      // 不可視文字リストに含まれていなければ追加
      if (!invisibleCharCodes.contains(rune)) {
        // 制御文字（U+0000-U+001F, U+007F-U+009F）も除去
        if (!_isControlChar(rune)) {
          buffer.writeCharCode(rune);
        }
      }
    }
    return buffer.toString();
  }

  /// 制御文字かどうか判定
  static bool _isControlChar(int codePoint) {
    return (codePoint >= 0x0000 && codePoint <= 0x001F) ||
        (codePoint >= 0x007F && codePoint <= 0x009F);
  }

  // ============================================================
  // Unicode正規化
  // ============================================================

  /// Unicode正規化（NFKC互換分解・正規合成）
  /// Dartでは組み込みNFKCがないため、主要なケースを手動で処理
  static String unicodeNormalize(String text) {
    if (text.isEmpty) return text;

    var result = text;

    // 合字の分解
    result = _decomposeUnicodeLigatures(result);

    // 上付き・下付き文字の正規化
    result = _normalizeSubSuperscripts(result);

    // 囲み文字の正規化
    result = _normalizeEnclosedChars(result);

    // 特殊スタイル文字の正規化（数学記号、装飾文字など）
    result = _normalizeStyledChars(result);

    return result;
  }

  /// 合字の分解
  static String _decomposeUnicodeLigatures(String text) {
    const ligatureMap = {
      'ﬁ': 'fi',
      'ﬂ': 'fl',
      'ﬀ': 'ff',
      'ﬃ': 'ffi',
      'ﬄ': 'ffl',
      'ﬅ': 'st',
      'ﬆ': 'st',
      'Ꜳ': 'AA',
      'ꜳ': 'aa',
      'Æ': 'AE',
      'æ': 'ae',
      'Œ': 'OE',
      'œ': 'oe',
      'ĳ': 'ij',
      'Ĳ': 'IJ',
      'ǉ': 'lj',
      'ǌ': 'nj',
      'ǆ': 'dz',
    };

    var result = text;
    ligatureMap.forEach((ligature, decomposed) {
      result = result.replaceAll(ligature, decomposed);
    });
    return result;
  }

  /// 上付き・下付き文字の正規化
  static String _normalizeSubSuperscripts(String text) {
    const superscriptMap = {
      '⁰': '0', '¹': '1', '²': '2', '³': '3', '⁴': '4',
      '⁵': '5', '⁶': '6', '⁷': '7', '⁸': '8', '⁹': '9',
      'ᵃ': 'a', 'ᵇ': 'b', 'ᶜ': 'c', 'ᵈ': 'd', 'ᵉ': 'e',
      'ᶠ': 'f', 'ᵍ': 'g', 'ʰ': 'h', 'ⁱ': 'i', 'ʲ': 'j',
      'ᵏ': 'k', 'ˡ': 'l', 'ᵐ': 'm', 'ⁿ': 'n', 'ᵒ': 'o',
      'ᵖ': 'p', 'ʳ': 'r', 'ˢ': 's', 'ᵗ': 't', 'ᵘ': 'u',
      'ᵛ': 'v', 'ʷ': 'w', 'ˣ': 'x', 'ʸ': 'y', 'ᶻ': 'z',
    };

    const subscriptMap = {
      '₀': '0', '₁': '1', '₂': '2', '₃': '3', '₄': '4',
      '₅': '5', '₆': '6', '₇': '7', '₈': '8', '₉': '9',
      'ₐ': 'a', 'ₑ': 'e', 'ₕ': 'h', 'ᵢ': 'i', 'ⱼ': 'j',
      'ₖ': 'k', 'ₗ': 'l', 'ₘ': 'm', 'ₙ': 'n', 'ₒ': 'o',
      'ₚ': 'p', 'ᵣ': 'r', 'ₛ': 's', 'ₜ': 't', 'ᵤ': 'u',
      'ᵥ': 'v', 'ₓ': 'x',
    };

    var result = text;
    superscriptMap.forEach((sup, normal) {
      result = result.replaceAll(sup, normal);
    });
    subscriptMap.forEach((sub, normal) {
      result = result.replaceAll(sub, normal);
    });
    return result;
  }

  /// 囲み文字の正規化
  static String _normalizeEnclosedChars(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final normalized = _normalizeEnclosedChar(rune);
      if (normalized != null) {
        buffer.write(normalized);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  /// 単一囲み文字の正規化
  static String? _normalizeEnclosedChar(int codePoint) {
    // 囲み英数字（①②③...等）
    if (codePoint >= 0x2460 && codePoint <= 0x2473) {
      return (codePoint - 0x2460 + 1).toString();
    }
    // 囲みCJK文字
    if (codePoint >= 0x3200 && codePoint <= 0x321E) {
      return String.fromCharCode(codePoint - 0x3200 + 0x1100);
    }
    // 丸付き数字（黒丸）
    if (codePoint >= 0x2776 && codePoint <= 0x277F) {
      return (codePoint - 0x2776 + 1).toString();
    }
    // 丸付きアルファベット（大文字）
    if (codePoint >= 0x24B6 && codePoint <= 0x24CF) {
      return String.fromCharCode(codePoint - 0x24B6 + 0x41);
    }
    // 丸付きアルファベット（小文字）
    if (codePoint >= 0x24D0 && codePoint <= 0x24E9) {
      return String.fromCharCode(codePoint - 0x24D0 + 0x61);
    }
    return null;
  }

  /// 特殊スタイル文字の正規化（数学記号、装飾文字など）
  static String _normalizeStyledChars(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final normalized = _normalizeStyledChar(rune);
      buffer.write(normalized);
    }
    return buffer.toString();
  }

  /// 単一スタイル文字の正規化
  static String _normalizeStyledChar(int codePoint) {
    // 数学用太字アルファベット（A-Z）
    if (codePoint >= 0x1D400 && codePoint <= 0x1D419) {
      return String.fromCharCode(codePoint - 0x1D400 + 0x41);
    }
    // 数学用太字アルファベット（a-z）
    if (codePoint >= 0x1D41A && codePoint <= 0x1D433) {
      return String.fromCharCode(codePoint - 0x1D41A + 0x61);
    }
    // 数学用イタリックアルファベット
    if (codePoint >= 0x1D434 && codePoint <= 0x1D44D) {
      return String.fromCharCode(codePoint - 0x1D434 + 0x41);
    }
    if (codePoint >= 0x1D44E && codePoint <= 0x1D467) {
      return String.fromCharCode(codePoint - 0x1D44E + 0x61);
    }
    // 二重線文字（𝔸𝔹ℂ等）
    if (codePoint >= 0x1D538 && codePoint <= 0x1D551) {
      return String.fromCharCode(codePoint - 0x1D538 + 0x41);
    }
    // フラクトゥール文字
    if (codePoint >= 0x1D504 && codePoint <= 0x1D51C) {
      return String.fromCharCode(codePoint - 0x1D504 + 0x41);
    }
    // 筆記体文字
    if (codePoint >= 0x1D49C && codePoint <= 0x1D4B5) {
      return String.fromCharCode(codePoint - 0x1D49C + 0x41);
    }
    // サンセリフ太字
    if (codePoint >= 0x1D5A0 && codePoint <= 0x1D5B9) {
      return String.fromCharCode(codePoint - 0x1D5A0 + 0x41);
    }
    if (codePoint >= 0x1D5BA && codePoint <= 0x1D5D3) {
      return String.fromCharCode(codePoint - 0x1D5BA + 0x61);
    }
    // モノスペース
    if (codePoint >= 0x1D670 && codePoint <= 0x1D689) {
      return String.fromCharCode(codePoint - 0x1D670 + 0x41);
    }
    if (codePoint >= 0x1D68A && codePoint <= 0x1D6A3) {
      return String.fromCharCode(codePoint - 0x1D68A + 0x61);
    }
    // 数学用数字
    if (codePoint >= 0x1D7CE && codePoint <= 0x1D7D7) {
      return String.fromCharCode(codePoint - 0x1D7CE + 0x30);
    }
    if (codePoint >= 0x1D7D8 && codePoint <= 0x1D7E1) {
      return String.fromCharCode(codePoint - 0x1D7D8 + 0x30);
    }

    return String.fromCharCode(codePoint);
  }

  // ============================================================
  // 基本的な正規化
  // ============================================================

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
        fullWidthToHalfWidth[charStr] ?? charStr,
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
        katakanaToHiragana[charStr] ?? charStr,
      );
    }
    return buffer.toString();
  }

  /// 類似文字の正規化（Unicodeホモグリフ対策）
  static String _normalizeSimilarChars(String text) {
    var result = text;
    similarCharMap.forEach((from, to) {
      result = result.replaceAll(from, to);
    });
    return result;
  }

  /// 日本語特殊置換（漢字当て字対策）
  static String _normalizeJapaneseSubstitutions(String text) {
    const substitutions = {
      // 漢字→カタカナ/ひらがな当て字
      '工口': 'えろ', // エロ
      '口ロ': 'ろろ',
      '夕卜': 'たと',
      '八ン': 'はん',
      '力ス': 'かす',
      '人ス': 'にす',
      '口口': 'ろろ',
      // 氏ね→死ね
      '氏ね': 'しね',
      '市ね': 'しね',
      '詩ね': 'しね',
      // タヒ→死
      'タヒ': 'し',
      'ﾀﾋ': 'し',
      // その他
      '逝': 'し', // 逝ってよし→しってよし
    };

    var result = text;
    substitutions.forEach((from, to) {
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
    // 文字間の装飾記号を除去（ただし意味のある記号は残す）
    return text.replaceAll(
      RegExp(r'[*_~`|\\^]'),
      '',
    );
  }

  // ============================================================
  // 数字・記号の変換
  // ============================================================

  /// 数字を文字に変換したバリエーションを生成
  /// 「h3ll0」→「hello」、「4ck」→「ack」
  static String convertNumbersToChars(String text) {
    const numberMap = {
      '0': 'o',
      '1': 'i',
      '2': 'z',
      '3': 'e',
      '4': 'a',
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

  /// 日本語の数字置換を変換
  /// 「4ね」→「しね」、「56す」→「ころす」
  static String convertJapaneseNumberSubstitutions(String text) {
    var result = text;

    // 4→し（「4ね」対策）
    result = result.replaceAllMapped(
      RegExp(r'4([ねネ])'),
      (match) => 'し${match.group(1)}',
    );

    // 56→ころ（「56す」対策）
    result = result.replaceAllMapped(
      RegExp(r'56([すせ])'),
      (match) => 'ころ${match.group(1)}',
    );

    return result;
  }

  // ============================================================
  // 伏せ字・変種表現の処理
  // ============================================================

  /// 伏せ字パターンの展開
  /// 「死○」→「死ね」「死んで」等に展開
  static List<String> expandMaskedPatterns(String text) {
    final results = <String>{text};

    // 伏せ字マーカー
    final maskedChars = ['○', '●', '〇', '◯', '*', '＊', '×', '☆', '★'];

    // 伏せ字の後に来る可能性のある文字
    final replacements = {
      '死': ['ね', 'んで', 'のう', 'ぬ', 'にたい'],
      '殺': ['す', 'せ', 'した', 'される', 'してやる'],
      'し': ['ね', 'んで'],
      'ころ': ['す', 'せ', 'した'],
      'f': ['uck', 'ag', 'ucker'],
      's': ['hit', 'ex', 'lut'],
      'd': ['ie', 'ick', 'ead'],
      'c': ['ock', 'unt', 'rap'],
      'b': ['itch', 'astard'],
      'p': ['ussy', 'enis', 'orn'],
      'a': ['ss', 'nal', 'sshole'],
      'n': ['igger', 'igga'],
    };

    for (final masked in maskedChars) {
      if (text.contains(masked)) {
        // 伏せ字の前の文字を取得してパターンマッチ
        final pattern = RegExp('(.)$masked');
        for (final match in pattern.allMatches(text)) {
          final prefix = match.group(1)!.toLowerCase();
          final possibleSuffixes = replacements[prefix] ?? [];
          for (final suffix in possibleSuffixes) {
            results.add(text.replaceFirst(
              '${match.group(1)}$masked',
              '${match.group(1)}$suffix',
            ));
          }
        }

        // 伏せ字の後の文字を取得してパターンマッチ
        final patternAfter = RegExp('$masked(.)');
        for (final match in patternAfter.allMatches(text)) {
          final suffix = match.group(1)!.toLowerCase();
          // 「○ね」→「死ね」など
          if (suffix == 'ね') {
            results.add(text.replaceFirst('$masked$suffix', '死$suffix'));
            results.add(text.replaceFirst('$masked$suffix', 'し$suffix'));
          }
          if (suffix == 'す') {
            results.add(text.replaceFirst('$masked$suffix', '殺$suffix'));
            results.add(text.replaceFirst('$masked$suffix', 'ころ$suffix'));
          }
        }
      }
    }

    return results.toList();
  }

  /// 文字間スペースを除去した文字列を生成
  /// 「f u c k」→「fuck」
  static String removeInterspersedSpaces(String text) {
    // 単一文字がスペースで区切られているパターンを検出して結合
    // 例: "f u c k" → "fuck", "し ね" → "しね"
    final singleCharSpaced = RegExp(r'^(\S)\s+(\S)(\s+\S)*$');
    if (singleCharSpaced.hasMatch(text)) {
      return text.replaceAll(RegExp(r'\s+'), '');
    }

    // パターンマッチしなくても、短い単語がスペースで区切られていたら結合
    // 例: "f u c k you" → "fuck you"
    var result = text;
    result = result.replaceAllMapped(
      RegExp(r'(\b\S)\s+(\S)\s+(\S)\s+(\S)\b'),
      (match) =>
          '${match.group(1)}${match.group(2)}${match.group(3)}${match.group(4)}',
    );
    result = result.replaceAllMapped(
      RegExp(r'(\b\S)\s+(\S)\s+(\S)\b'),
      (match) => '${match.group(1)}${match.group(2)}${match.group(3)}',
    );

    return result;
  }

  /// 記号挿入による回避を正規化
  /// 「f.u.c.k」「f_u_c_k」→「fuck」
  static String removeInterspersedPunctuation(String text) {
    // 文字間に挿入された記号を除去
    return text.replaceAllMapped(
      RegExp(r'(\w)[.\-_\/\\*#@!+]+(\w)'),
      (match) => '${match.group(1)}${match.group(2)}',
    );
  }

  /// 複数の正規化バリエーションを生成
  /// より厳格なチェックが必要な場合に使用
  static List<String> generateVariations(String text) {
    final variations = <String>{};

    // 基本の正規化
    variations.add(normalize(text));

    // 軽量正規化
    variations.add(normalizeLight(text));

    // 超厳格正規化
    variations.add(normalizeStrict(text));

    // 数字→文字変換版
    variations.add(convertNumbersToChars(text));
    variations.add(normalize(convertNumbersToChars(text)));

    // スペース除去版
    variations.add(removeInterspersedSpaces(text));
    variations.add(normalize(removeInterspersedSpaces(text)));

    // 記号除去版
    variations.add(removeInterspersedPunctuation(text));
    variations.add(normalize(removeInterspersedPunctuation(text)));

    // 伏せ字展開版
    for (final expanded in expandMaskedPatterns(text)) {
      variations.add(expanded);
      variations.add(normalize(expanded));
    }

    // 空白・記号完全除去版
    final noWhitespace = text.replaceAll(RegExp(r'\s+'), '');
    variations.add(noWhitespace);
    variations.add(normalize(noWhitespace));

    // 記号完全除去版
    final noPunctuation =
        text.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
    variations.add(noPunctuation);
    variations.add(normalize(noPunctuation));

    return variations.toList();
  }

  // ============================================================
  // 文字種別判定ユーティリティ
  // ============================================================

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

/// 文字種別判定ユーティリティ（後方互換用エイリアス）
class CharacterTypeUtil {
  CharacterTypeUtil._();

  static bool isHiragana(String char) => TextNormalizer.isHiragana(char);
  static bool isKatakana(String char) => TextNormalizer.isKatakana(char);
  static bool isKanji(String char) => TextNormalizer.isKanji(char);
  static bool isJapanese(String char) => TextNormalizer.isJapanese(char);
  static bool isAsciiAlphanumeric(String char) =>
      TextNormalizer.isAsciiAlphanumeric(char);
  static bool containsJapanese(String text) =>
      TextNormalizer.containsJapanese(text);
  static TextLanguage detectPrimaryLanguage(String text) =>
      TextNormalizer.detectPrimaryLanguage(text);
}
