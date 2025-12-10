/**
 * NGワード辞書（バックエンド用）
 * 任天堂レベルの厳格なフィルタリングを実現
 */

// ============================================================
// 日本語NGワード
// ============================================================

/** 暴力的表現（日本語） */
export const VIOLENCE_JA: string[] = [
  // 直接的な暴力表現
  '殺す', '殺せ', '殺した', '殺してやる', '殺される',
  'ころす', 'ころせ', 'ころした',
  '死ね', '死んで', 'しね', 'しんで',
  '氏ね', '氏んで', // 伏せ字バリエーション
  'タヒね', 'ﾀﾋね', 'タヒ', // 隠語
  '4ね', // 数字置換
  // 傷害関連
  '刺す', '刺せ', '刺した',
  '殴る', '殴れ', '殴った',
  '蹴る', '蹴れ', '蹴った',
  // 脅迫
  '消す', '消してやる',
  '潰す', '潰してやる',
  'ぶっ殺', 'ぶっころ',
  // 自傷関連
  '自殺', 'じさつ', '自○',
];

/** 性的表現（日本語） */
export const SEXUAL_JA: string[] = [
  'セックス', 'せっくす', 'sex',
  'エロ', 'えろ',
  'エッチ', 'えっち',
  'おっぱい', 'オッパイ',
  'ちんこ', 'チンコ', 'ちんぽ', 'チンポ',
  'まんこ', 'マンコ',
  'おまんこ', 'オマンコ',
  'パイパン', 'ぱいぱん',
  '乳首', 'ちくび',
  '射精', '中出し',
  'レイプ', 'れいぷ',
  '強姦', '痴漢',
  'フェラ', 'ふぇら',
  'オナニー', 'おなにー', 'オナ',
  'ポルノ', 'ぽるの',
  '風俗', '援交', '援助交際',
  'パパ活', 'ぱぱかつ',
  // 幼児向け俗語（任天堂的厳格さ）
  'うんこ', 'うんち', 'ウンコ', 'ウンチ',
  'おしっこ', 'オシッコ',
  'おなら', 'オナラ',
  'ちんちん', 'チンチン',
];

/** 差別的表現（日本語） */
export const DISCRIMINATION_JA: string[] = [
  // 障害者差別
  'きちがい', 'キチガイ', '基地外', '基地害',
  'ガイジ', 'がいじ',
  '池沼', 'いけぬま',
  '知恵遅れ', 'ちえおくれ',
  'めくら', 'メクラ',
  'つんぼ', 'ツンボ',
  'びっこ', 'ビッコ',
  'かたわ', 'カタワ',
  // 人種・民族差別
  '朝鮮人', 'チョン', 'ちょん',
  'シナ人', '支那',
  'クロンボ', 'くろんぼ',
  '土人', 'どじん',
  'ジャップ', 'じゃっぷ',
  // 部落差別
  'えた', 'エタ', '穢多',
  'ひにん', 'ヒニン', '非人',
  '部落民', 'ぶらくみん',
  // 性差別
  'くそ女', 'クソ女',
  'くそ男', 'クソ男',
  'まんさん', 'マンさん',
];

/** ヘイトスピーチ（日本語） */
export const HATE_JA: string[] = [
  '反日', 'はんにち',
  '売国奴', 'ばいこくど',
  '非国民', 'ひこくみん',
  '帰れ', 'かえれ',
  '出ていけ', 'でていけ',
];

/** 罵倒・冒涜（日本語） */
export const PROFANITY_JA: string[] = [
  // 一般的な罵倒
  'バカ', 'ばか', '馬鹿',
  'アホ', 'あほ', '阿呆',
  'マヌケ', 'まぬけ', '間抜け',
  'ボケ', 'ぼけ', '惚け',
  'カス', 'かす', '粕',
  'クズ', 'くず', '屑',
  'ゴミ', 'ごみ',
  'クソ', 'くそ', '糞',
  'ウザい', 'うざい', 'うぜー', 'ウゼー',
  'キモい', 'きもい', 'キモ', 'きも',
  'ブス', 'ぶす', '不細工',
  'デブ', 'でぶ',
  'ハゲ', 'はげ', '禿',
  'チビ', 'ちび',
  // 強い罵倒
  '死ねばいい', 'しねばいい',
  '消えろ', 'きえろ',
  '失せろ', 'うせろ',
  // 侮辱
  'ザコ', 'ざこ', '雑魚',
  'ノロマ', 'のろま',
  '無能', 'むのう',
  '役立たず', 'やくたたず',
];

// ============================================================
// 英語NGワード
// ============================================================

/** 暴力的表現（英語） */
export const VIOLENCE_EN: string[] = [
  'kill', 'killing', 'killed', 'killer',
  'murder', 'murdered', 'murderer',
  'die', 'dead', 'death',
  'suicide', 'suicidal',
  'stab', 'stabbing', 'stabbed',
  'shoot', 'shooting', 'shot',
  'bomb', 'bombing',
  'attack', 'attacked',
  'threat', 'threaten', 'threatening',
  'destroy', 'destroying',
];

/** 性的表現（英語） */
export const SEXUAL_EN: string[] = [
  'fuck', 'fucking', 'fucked', 'fucker', 'fck', 'f*ck',
  'sex', 'sexual', 'sexy',
  'porn', 'porno', 'pornography',
  'nude', 'naked', 'nudity',
  'dick', 'd1ck', 'dck',
  'cock', 'c0ck',
  'penis',
  'pussy', 'puss', 'p*ssy',
  'vagina',
  'boob', 'boobs', 'boobie', 'tits', 'titty', 'titties',
  'ass', 'arse', 'a$$', '@ss',
  'butt', 'butthole',
  'cum', 'cumming',
  'orgasm',
  'masturbate', 'masturbation', 'wank',
  'blowjob', 'bj',
  'handjob', 'hj',
  'rape', 'raped', 'rapist',
  'molest', 'molester',
  'whore', 'wh0re',
  'slut', 'sl*t',
  'prostitute', 'hooker',
  'hentai',
  'poop', 'poopy', 'poo',
  'pee', 'peepee',
  'fart', 'farting',
];

/** 差別的表現（英語） */
export const DISCRIMINATION_EN: string[] = [
  'nigger', 'n1gger', 'nigga', 'n1gga',
  'negro',
  'chink',
  'gook',
  'spic', 'spick',
  'wetback',
  'cracker',
  'honky',
  'jap',
  'coon',
  'towelhead', 'raghead',
  'retard', 'retarded', 'tard',
  'cripple', 'crippled',
  'spaz', 'spastic',
  'faggot', 'fag', 'f@g', 'f4g',
  'dyke', 'd1ke',
  'tranny',
  'bitch', 'b1tch', 'b*tch',
  'cunt', 'c*nt', 'c0nt',
  'kike',
];

/** ヘイトスピーチ（英語） */
export const HATE_EN: string[] = [
  'nazi', 'naz1',
  'hitler', 'h1tler',
  'kkk',
  'white power',
  'white supremacy',
  'heil',
  'genocide',
  'holocaust',
  'ethnic cleansing',
];

/** 罵倒・冒涜（英語） */
export const PROFANITY_EN: string[] = [
  'shit', 'sh1t', 'sh!t', 'shyt', 'sht',
  'crap', 'crappy',
  'damn', 'dammit', 'damned',
  'hell',
  'bastard', 'b@stard',
  'asshole', 'a-hole', '@sshole',
  'douchebag', 'douche',
  'prick',
  'scum', 'scumbag',
  'loser',
  'idiot', 'idi0t',
  'moron', 'mor0n',
  'dumb', 'dumbass',
  'stupid', 'stup1d',
  'jerk',
  'creep', 'creepy',
  'pervert', 'perv',
  'weirdo',
  'freak',
  'suck', 'sucks', 'sucker',
  'lame',
  'wtf', 'wth',
  'stfu',
  'lmfao',
  'omfg',
];

/** 著作権関連NGワード */
export const COPYRIGHT_TERMS: string[] = [
  'torrent', 'トレント',
  '無料ダウンロード', 'free download',
  'クラック', 'crack', 'cracked',
  '海賊版', 'pirate', 'piracy',
  'warez',
  '割れ', 'われ',
  'keygen',
  'serial key', 'シリアルキー',
  'nulled',
  'leaked', 'リーク',
  '違法コピー', 'illegal copy',
  '著作権侵害', 'copyright infringement',
];

// ============================================================
// 許可リスト（誤検知防止）
// ============================================================

/** 許可リスト */
export const ALLOWLIST: string[] = [
  // 「死」を含むが問題ない表現
  '必死', 'ひっし',
  '死角', 'しかく',
  '死守', 'ししゅ',
  '死活問題', 'しかつもんだい',
  '決死', 'けっし',
  '瀕死', 'ひんし',
  '生死', 'せいし',
  // 「殺」を含むが問題ない表現
  '殺菌', 'さっきん',
  '殺虫', 'さっちゅう',
  '相殺', 'そうさい',
  // 英語の許可ワード
  'class', 'classic', 'classical',
  'glass', 'glasses',
  'mass', 'massive',
  'pass', 'passage', 'passed', 'passing', 'passenger',
  'compass',
  'grass', 'grassland',
  'brass',
  'bass',
  'assassin',
  'embassy',
  'hello', 'shell', 'shellfish',
  'helium', 'helicopter',
  'document', 'documentation',
  'cucumber',
  'circumstance',
  'accumulate',
  'white', 'exhibit',
  'prohibit', 'architecture',
  'diesel',
  'diet',
  'audience',
  'ingredient',
  'skill', 'skills', 'skilled',
  'kilogram', 'kilometer',
  'therapist',
  'analysis', 'analyst',
  'title', 'titled',
  'cocktail', 'peacock',
];

// ============================================================
// 正規表現パターン
// ============================================================

/** NGパターン */
export const NG_PATTERNS: RegExp[] = [
  // URL（スパム対策）
  /https?:\/\/[^\s]+/i,
  // メールアドレス（個人情報保護）
  /[\w.+-]+@[\w-]+\.[\w.-]+/i,
  // 電話番号
  /\d{2,4}[-\s]?\d{2,4}[-\s]?\d{3,4}/,
  // LINE ID等
  /line\s*[:：]\s*\S+/i,
  // SNSアカウント
  /@[a-zA-Z0-9_]+/,
  // 伏せ字パターン
  /[死殺][○●〇◯]/,
  // 文字間スペース回避
  /f\s*u\s*c\s*k/i,
  /s\s*h\s*i\s*t/i,
  /d\s*i\s*e/i,
  /k\s*i\s*l\s*l/i,
  // 繰り返し文字
  /f+u+c+k+/i,
  /s+h+i+t+/i,
];

// ============================================================
// ユーティリティ
// ============================================================

/** 全日本語NGワード */
export const ALL_JAPANESE_NG_WORDS: string[] = [
  ...VIOLENCE_JA,
  ...SEXUAL_JA,
  ...DISCRIMINATION_JA,
  ...HATE_JA,
  ...PROFANITY_JA,
];

/** 全英語NGワード */
export const ALL_ENGLISH_NG_WORDS: string[] = [
  ...VIOLENCE_EN,
  ...SEXUAL_EN,
  ...DISCRIMINATION_EN,
  ...HATE_EN,
  ...PROFANITY_EN,
];

/** 全NGワード */
export const ALL_NG_WORDS: string[] = [
  ...ALL_JAPANESE_NG_WORDS,
  ...ALL_ENGLISH_NG_WORDS,
  ...COPYRIGHT_TERMS,
];

/** カテゴリ定義 */
export enum NgWordCategory {
  Violence = 'violence',
  Sexual = 'sexual',
  Discrimination = 'discrimination',
  Hate = 'hate',
  Profanity = 'profanity',
  Copyright = 'copyright',
  Personal = 'personal',
  Pattern = 'pattern',
}

/** カテゴリ別重大度 */
export const CATEGORY_SEVERITY: Record<NgWordCategory, number> = {
  [NgWordCategory.Violence]: 5,
  [NgWordCategory.Sexual]: 4,
  [NgWordCategory.Discrimination]: 5,
  [NgWordCategory.Hate]: 5,
  [NgWordCategory.Profanity]: 2,
  [NgWordCategory.Copyright]: 3,
  [NgWordCategory.Personal]: 4,
  [NgWordCategory.Pattern]: 3,
};

/** カテゴリ別NGワードマップ */
export const CATEGORY_WORDS: Record<NgWordCategory, string[]> = {
  [NgWordCategory.Violence]: [...VIOLENCE_JA, ...VIOLENCE_EN],
  [NgWordCategory.Sexual]: [...SEXUAL_JA, ...SEXUAL_EN],
  [NgWordCategory.Discrimination]: [...DISCRIMINATION_JA, ...DISCRIMINATION_EN],
  [NgWordCategory.Hate]: [...HATE_JA, ...HATE_EN],
  [NgWordCategory.Profanity]: [...PROFANITY_JA, ...PROFANITY_EN],
  [NgWordCategory.Copyright]: COPYRIGHT_TERMS,
  [NgWordCategory.Personal]: [],
  [NgWordCategory.Pattern]: [],
};
