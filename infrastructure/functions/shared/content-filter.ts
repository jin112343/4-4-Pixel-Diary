/**
 * 多層コンテンツフィルタリングシステム（バックエンド用）
 * 任天堂レベルの厳格なフィルタリングを実現
 */

import {
  ALL_NG_WORDS,
  ALLOWLIST,
  NG_PATTERNS,
  NgWordCategory,
  CATEGORY_WORDS,
  CATEGORY_SEVERITY,
} from './ng-word-dictionary';

// ============================================================
// 型定義
// ============================================================

export interface ContentViolation {
  word: string;
  category: NgWordCategory;
  matchType: 'exact' | 'normalized' | 'pattern' | 'variation';
  position: number;
}

export interface ContentCheckResult {
  isClean: boolean;
  violations: ContentViolation[];
  originalText: string;
  normalizedText: string;
  maxSeverity: number;
}

export enum FilterStrictness {
  Light = 'light',       // severity >= 4
  Normal = 'normal',     // severity >= 3
  Strict = 'strict',     // severity >= 2
  Nintendo = 'nintendo', // severity >= 1
}

const STRICTNESS_MIN_SEVERITY: Record<FilterStrictness, number> = {
  [FilterStrictness.Light]: 4,
  [FilterStrictness.Normal]: 3,
  [FilterStrictness.Strict]: 2,
  [FilterStrictness.Nintendo]: 1,
};

// ============================================================
// テキスト正規化
// ============================================================

/** 類似文字マッピング */
const SIMILAR_CHAR_MAP: Record<string, string> = {
  '0': 'o',
  '1': 'i',
  '3': 'e',
  '4': 'a',
  '5': 's',
  '7': 't',
  '8': 'b',
  '9': 'g',
  '@': 'a',
  '$': 's',
  '!': 'i',
  '+': 't',
  '氏': '死',
};

/** 全角→半角マッピング */
const FULLWIDTH_TO_HALFWIDTH: Record<string, string> = {
  'Ａ': 'A', 'Ｂ': 'B', 'Ｃ': 'C', 'Ｄ': 'D', 'Ｅ': 'E',
  'Ｆ': 'F', 'Ｇ': 'G', 'Ｈ': 'H', 'Ｉ': 'I', 'Ｊ': 'J',
  'Ｋ': 'K', 'Ｌ': 'L', 'Ｍ': 'M', 'Ｎ': 'N', 'Ｏ': 'O',
  'Ｐ': 'P', 'Ｑ': 'Q', 'Ｒ': 'R', 'Ｓ': 'S', 'Ｔ': 'T',
  'Ｕ': 'U', 'Ｖ': 'V', 'Ｗ': 'W', 'Ｘ': 'X', 'Ｙ': 'Y',
  'Ｚ': 'Z',
  'ａ': 'a', 'ｂ': 'b', 'ｃ': 'c', 'ｄ': 'd', 'ｅ': 'e',
  'ｆ': 'f', 'ｇ': 'g', 'ｈ': 'h', 'ｉ': 'i', 'ｊ': 'j',
  'ｋ': 'k', 'ｌ': 'l', 'ｍ': 'm', 'ｎ': 'n', 'ｏ': 'o',
  'ｐ': 'p', 'ｑ': 'q', 'ｒ': 'r', 'ｓ': 's', 'ｔ': 't',
  'ｕ': 'u', 'ｖ': 'v', 'ｗ': 'w', 'ｘ': 'x', 'ｙ': 'y',
  'ｚ': 'z',
  '０': '0', '１': '1', '２': '2', '３': '3', '４': '4',
  '５': '5', '６': '6', '７': '7', '８': '8', '９': '9',
};

/** カタカナ→ひらがなマッピング */
const KATAKANA_TO_HIRAGANA: Record<string, string> = {
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
  // 半角カタカナ
  'ｱ': 'あ', 'ｲ': 'い', 'ｳ': 'う', 'ｴ': 'え', 'ｵ': 'お',
  'ｶ': 'か', 'ｷ': 'き', 'ｸ': 'く', 'ｹ': 'け', 'ｺ': 'こ',
  'ｻ': 'さ', 'ｼ': 'し', 'ｽ': 'す', 'ｾ': 'せ', 'ｿ': 'そ',
  'ﾀ': 'た', 'ﾁ': 'ち', 'ﾂ': 'つ', 'ﾃ': 'て', 'ﾄ': 'と',
  'ﾅ': 'な', 'ﾆ': 'に', 'ﾇ': 'ぬ', 'ﾈ': 'ね', 'ﾉ': 'の',
  'ﾊ': 'は', 'ﾋ': 'ひ', 'ﾌ': 'ふ', 'ﾍ': 'へ', 'ﾎ': 'ほ',
  'ﾏ': 'ま', 'ﾐ': 'み', 'ﾑ': 'む', 'ﾒ': 'め', 'ﾓ': 'も',
  'ﾔ': 'や', 'ﾕ': 'ゆ', 'ﾖ': 'よ',
  'ﾗ': 'ら', 'ﾘ': 'り', 'ﾙ': 'る', 'ﾚ': 'れ', 'ﾛ': 'ろ',
  'ﾜ': 'わ', 'ﾝ': 'ん',
};

/** テキストを正規化 */
export function normalizeText(text: string): string {
  let result = text;

  // 空白の正規化
  result = result.replace(/\s+/g, ' ').trim();

  // 全角→半角
  result = [...result].map(char => FULLWIDTH_TO_HALFWIDTH[char] || char).join('');

  // 小文字化
  result = result.toLowerCase();

  // カタカナ→ひらがな
  result = [...result].map(char => KATAKANA_TO_HIRAGANA[char] || char).join('');

  // 類似文字の正規化
  for (const [from, to] of Object.entries(SIMILAR_CHAR_MAP)) {
    result = result.split(from).join(to);
  }

  // 繰り返し文字の圧縮
  result = result.replace(/(.)\1{2,}/g, '$1$1');

  // 特殊文字の除去
  result = result.replace(/[*_~`|\\^]/g, '');

  return result;
}

// ============================================================
// コンテンツフィルター
// ============================================================

/** カスタムNGワード（ランタイム追加） */
let customNgWords: string[] = [];
let customAllowWords: string[] = [];
let currentStrictness: FilterStrictness = FilterStrictness.Strict;

/** 厳格度を設定 */
export function setStrictness(strictness: FilterStrictness): void {
  currentStrictness = strictness;
}

/** カスタムNGワードを追加 */
export function addCustomNgWords(words: string[]): void {
  customNgWords = [...customNgWords, ...words.map(w => w.toLowerCase())];
}

/** カスタム許可ワードを追加 */
export function addCustomAllowWords(words: string[]): void {
  customAllowWords = [...customAllowWords, ...words.map(w => w.toLowerCase())];
}

/** サーバーからNGワードリストを更新 */
export function updateNgWords(ngWords: string[], allowWords: string[]): void {
  customNgWords = ngWords.map(w => w.toLowerCase());
  customAllowWords = allowWords.map(w => w.toLowerCase());
}

/** 許可ワードの一部かどうかチェック */
function isPartOfAllowedWord(text: string, ngWord: string): boolean {
  const lowerText = text.toLowerCase();
  const lowerNgWord = ngWord.toLowerCase();
  const allAllowWords = [...ALLOWLIST, ...customAllowWords];

  for (const allowWord of allAllowWords) {
    const lowerAllowWord = allowWord.toLowerCase();
    if (lowerAllowWord.includes(lowerNgWord) && lowerText.includes(lowerAllowWord)) {
      return true;
    }
  }
  return false;
}

/** 完全一致チェック */
function checkExactMatch(text: string): ContentViolation[] {
  const violations: ContentViolation[] = [];
  const lowerText = text.toLowerCase();

  for (const [category, words] of Object.entries(CATEGORY_WORDS)) {
    for (const word of words) {
      if (lowerText.includes(word.toLowerCase())) {
        if (!isPartOfAllowedWord(text, word)) {
          violations.push({
            word,
            category: category as NgWordCategory,
            matchType: 'exact',
            position: lowerText.indexOf(word.toLowerCase()),
          });
        }
      }
    }
  }

  // カスタムNGワードもチェック
  for (const word of customNgWords) {
    if (lowerText.includes(word)) {
      violations.push({
        word,
        category: NgWordCategory.Profanity,
        matchType: 'exact',
        position: lowerText.indexOf(word),
      });
    }
  }

  return violations;
}

/** 正規化後マッチチェック */
function checkNormalizedMatch(normalizedText: string): ContentViolation[] {
  const violations: ContentViolation[] = [];

  for (const [category, words] of Object.entries(CATEGORY_WORDS)) {
    for (const word of words) {
      const normalizedWord = normalizeText(word);
      if (normalizedText.includes(normalizedWord)) {
        violations.push({
          word,
          category: category as NgWordCategory,
          matchType: 'normalized',
          position: normalizedText.indexOf(normalizedWord),
        });
      }
    }
  }

  return violations;
}

/** パターンマッチチェック */
function checkPatterns(text: string): ContentViolation[] {
  const violations: ContentViolation[] = [];

  for (const pattern of NG_PATTERNS) {
    const match = pattern.exec(text);
    if (match) {
      violations.push({
        word: match[0],
        category: NgWordCategory.Pattern,
        matchType: 'pattern',
        position: match.index,
      });
    }
  }

  return violations;
}

/** 重複除去 */
function deduplicateViolations(violations: ContentViolation[]): ContentViolation[] {
  const seen = new Set<string>();
  return violations.filter(v => {
    const key = `${v.word}_${v.category}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

/** 厳格度に基づくフィルタリング */
function filterBySeverity(violations: ContentViolation[]): ContentViolation[] {
  const minSeverity = STRICTNESS_MIN_SEVERITY[currentStrictness];
  return violations.filter(v => CATEGORY_SEVERITY[v.category] >= minSeverity);
}

/** 最大重大度を取得 */
function getMaxSeverity(violations: ContentViolation[]): number {
  if (violations.length === 0) return 0;
  return Math.max(...violations.map(v => CATEGORY_SEVERITY[v.category]));
}

/** 総合コンテンツチェック */
export function checkContent(text: string): ContentCheckResult {
  if (!text || text.trim() === '') {
    return {
      isClean: true,
      violations: [],
      originalText: text,
      normalizedText: '',
      maxSeverity: 0,
    };
  }

  const violations: ContentViolation[] = [];
  const originalText = text;
  const normalizedText = normalizeText(text);

  // 層1: 完全一致チェック
  violations.push(...checkExactMatch(originalText));

  // 層2: 正規化後チェック
  violations.push(...checkNormalizedMatch(normalizedText));

  // 層3: パターンチェック
  violations.push(...checkPatterns(originalText));

  // 重複除去
  const uniqueViolations = deduplicateViolations(violations);

  // 厳格度に基づくフィルタリング
  const filteredViolations = filterBySeverity(uniqueViolations);

  return {
    isClean: filteredViolations.length === 0,
    violations: filteredViolations,
    originalText,
    normalizedText,
    maxSeverity: getMaxSeverity(filteredViolations),
  };
}

/** クイックチェック（パフォーマンス重視） */
export function isSafe(text: string): boolean {
  if (!text || text.trim() === '') return true;

  const lowerText = text.toLowerCase();

  // 高重大度のNGワードのみチェック
  const highSeverityCategories = [
    NgWordCategory.Violence,
    NgWordCategory.Discrimination,
    NgWordCategory.Hate,
  ];

  for (const category of highSeverityCategories) {
    for (const word of CATEGORY_WORDS[category]) {
      if (lowerText.includes(word.toLowerCase())) {
        return false;
      }
    }
  }

  return true;
}

/** NGワードをマスク */
export function maskContent(text: string, maskChar = '*'): string {
  let result = text;

  for (const words of Object.values(CATEGORY_WORDS)) {
    for (const word of words) {
      if (isPartOfAllowedWord(text, word)) continue;
      const pattern = new RegExp(escapeRegExp(word), 'gi');
      result = result.replace(pattern, maskChar.repeat(word.length));
    }
  }

  // カスタムNGワードもマスク
  for (const word of customNgWords) {
    const pattern = new RegExp(escapeRegExp(word), 'gi');
    result = result.replace(pattern, maskChar.repeat(word.length));
  }

  // パターンマッチもマスク
  result = result.replace(/https?:\/\/[^\s]+/gi, '[URL削除]');
  result = result.replace(/[\w.+-]+@[\w-]+\.[\w.-]+/gi, '[メール削除]');
  result = result.replace(/\d{2,4}[-\s]?\d{2,4}[-\s]?\d{3,4}/g, '[電話番号削除]');

  return result;
}

/** 正規表現特殊文字をエスケープ */
function escapeRegExp(string: string): string {
  return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// ============================================================
// バリデーション用エクスポート（後方互換性）
// ============================================================

/** NGワードが含まれているかチェック（後方互換） */
export function containsNgWord(text: string): boolean {
  return !isSafe(text);
}
