/// NGワード辞書
/// 任天堂レベルの厳格なフィルタリングを目指す
/// 参考: LDNOOBW, inappropriate-words-ja, WebPurify
///
/// カテゴリ:
/// - violence: 暴力的表現
/// - sexual: 性的表現
/// - discrimination: 差別的表現
/// - hate: ヘイトスピーチ
/// - profanity: 罵倒・冒涜
/// - copyright: 著作権関連
/// - personal: 個人情報関連
/// - spam: スパム・宣伝
class NgWordDictionary {
  NgWordDictionary._();

  // ============================================================
  // 日本語NGワード（大幅拡充版）
  // ============================================================

  /// 暴力的表現（日本語）- 伏せ字・隠語含む
  static const List<String> violenceJa = [
    // 直接的な暴力表現
    '殺す', '殺せ', '殺した', '殺してやる', '殺される', '殺しちゃう',
    '殺っちゃう', '殺るぞ', '殺ってやる',
    'ころす', 'ころせ', 'ころした', 'ころしてやる',
    '56す', '564', '56せ', // 数字置換
    // 「死ね」系（全バリエーション）
    '死ね', '死んで', '死にさらせ', '死ねよ', '死ねば',
    'しね', 'しんで', 'しねよ',
    '氏ね', '氏んで', '市ね', '詩ね', // 伏せ字バリエーション
    'タヒね', 'ﾀﾋね', 'タヒ', // 隠語
    '4ね', 'しネ', 'シネ', 'sine', // 数字・混合置換
    '逝ね', '逝け', '逝ってよし', // 2ch語
    '○ね', '●ね', '死○', // 伏せ字
    // 傷害関連
    '刺す', '刺せ', '刺した', '刺してやる', '刺し殺す',
    '殴る', '殴れ', '殴った', '殴ってやる', 'ぶん殴る',
    '蹴る', '蹴れ', '蹴った', '蹴ってやる',
    'ぶっ飛ばす', 'ぶっとばす', 'ぶったたく',
    'ぼこぼこ', 'ボコボコ', 'ボコる', 'ぼこる',
    'リンチ', 'りんち',
    // 脅迫
    '消す', '消してやる', '消すぞ',
    '潰す', '潰してやる', 'つぶす',
    'ぶっ殺', 'ぶっころ', 'ぶっ56',
    '燃やす', '焼く', '焼き殺す',
    '爆破', 'ばくは', '爆発',
    'テロ', 'てろ',
    // 自傷関連
    '自殺', 'じさつ', '自○', '自さつ',
    '自害', 'じがい',
    'リスカ', 'りすか', 'リストカット',
    '首吊り', 'くびつり',
    '飛び降り', 'とびおり',
    // 犯罪関連
    '誘拐', 'ゆうかい',
    '監禁', 'かんきん',
    '拉致', 'らち',
    '殺人', 'さつじん',
    '傷害', 'しょうがい',
    '暴行', 'ぼうこう',
    '脅迫', 'きょうはく',
    '復讐', 'ふくしゅう',
    '報復', 'ほうふく',
  ];

  /// 性的表現（日本語）- 任天堂レベルの厳格さ
  static const List<String> sexualJa = [
    // 直接的な性的表現
    'セックス', 'せっくす', 'セク', 'せく',
    'エッチ', 'えっち', 'エチ', 'えち', 'Ｈ',
    'やる', 'やらせて', 'やらせろ', // 文脈依存だが警戒
    '挿入', 'そうにゅう',
    '性行為', 'せいこうい',
    '性交', 'せいこう',
    '交尾', 'こうび',
    // 性器関連
    'おっぱい', 'オッパイ', 'おぱい', 'オパイ',
    'おっぱ', 'オッパ', '乳', 'ちち', 'パイオツ',
    'ちんこ', 'チンコ', 'ちんぽ', 'チンポ', 'ちんちん', 'チンチン',
    'ちん○', 'チン○', '珍子', '珍棒',
    'まんこ', 'マンコ', 'まん○', 'マン○', '万個',
    'おまんこ', 'オマンコ', 'お万個',
    'ちくび', 'チクビ', '乳首', 'にゅうしゅ',
    '陰茎', 'いんけい', 'ペニス', 'ぺにす',
    '睾丸', 'こうがん', 'きんたま', 'キンタマ', '金玉',
    '陰部', 'いんぶ',
    '膣', 'ちつ', 'ヴァギナ', 'バギナ',
    '亀頭', 'きとう',
    '包茎', 'ほうけい',
    // 性的行為
    '射精', 'しゃせい', '発射',
    '中出し', 'なかだし',
    '外出し', 'そとだし',
    'ぶっかけ', 'ブッカケ',
    '顔射', 'がんしゃ',
    'イク', 'いく', 'イッた', 'いった',
    '絶頂', 'ぜっちょう',
    '潮吹き', 'しおふき',
    // 性犯罪
    'レイプ', 'れいぷ', 'rape',
    '強姦', 'ごうかん',
    '痴漢', 'ちかん',
    '盗撮', 'とうさつ',
    '覗き', 'のぞき',
    '露出', 'ろしゅつ',
    // 性風俗・売春
    'フェラ', 'ふぇら', 'フェラチオ',
    'クンニ', 'くんに', 'クンニリングス',
    '手コキ', 'てこき', '手マン', 'てまん',
    'オナニー', 'おなにー', 'オナ', 'おな', '自慰',
    '抜く', 'ぬく', '抜ける', 'ぬける', // 文脈依存
    'オナホ', 'おなほ',
    'バイブ', 'ばいぶ', 'ローター',
    'AV', 'えーぶい', 'エーブイ', 'アダルトビデオ',
    'ポルノ', 'ぽるの', 'pornо',
    '風俗', 'ふうぞく',
    'ソープ', 'そーぷ', 'ソープランド',
    'ヘルス', 'へるす', 'デリヘル', 'でりへる',
    '援交', 'えんこう', '援助交際',
    'パパ活', 'ぱぱかつ', 'ママ活', 'ままかつ',
    '売春', 'ばいしゅん',
    '買春', 'かいしゅん',
    '円光', 'えんこう',
    'JK', 'じぇーけー', // ビジネス文脈以外
    // 幼児向け俗語（任天堂的厳格さ）
    'うんこ', 'うんち', 'ウンコ', 'ウンチ', 'うんぴー', 'うんP',
    'おしっこ', 'オシッコ', 'しっこ', 'シッコ',
    'おなら', 'オナラ', 'へ', 'おへ',
    'げり', 'ゲリ', '下痢',
    'ちんこ', 'チンチン', 'おちんちん',
    // エロゲー・同人関連
    'エロゲ', 'えろげ', 'エロゲー',
    '同人誌', 'どうじんし',
    '薄い本', 'うすいほん',
    'R18', 'R-18', '18禁', '18きん',
    '成人向け', 'せいじんむけ',
    // ネットスラング
    'えろい', 'エロい', 'エロ', 'えろ',
    'エチエチ', 'えちえち',
    'シコ', 'しこ', 'シコる', 'しこる',
    'ムラムラ', 'むらむら',
    '発情', 'はつじょう',
    'ヤリマン', 'やりまん', 'ヤリチン', 'やりちん',
    'ビッチ', 'びっち',
    '変態', 'へんたい', 'hentai',
  ];

  /// 差別的表現（日本語）
  static const List<String> discriminationJa = [
    // 障害者差別
    'きちがい', 'キチガイ', '基地外', '基地害', 'キチ', 'きち',
    'ガイジ', 'がいじ', '害児', '外字',
    '池沼', 'いけぬま', 'ちしょう',
    '知恵遅れ', 'ちえおくれ',
    '精薄', 'せいはく',
    '白痴', 'はくち',
    'めくら', 'メクラ', '盲',
    'つんぼ', 'ツンボ', '聾',
    'おし', 'オシ', '唖',
    'びっこ', 'ビッコ', 'ちんば',
    'かたわ', 'カタワ', '片輪', '片端',
    '不具', 'ふぐ',
    '奇形', 'きけい',
    'アスペ', 'あすぺ',
    '糖質', 'とうしつ', // 統合失調症への蔑称
    'メンヘラ', 'めんへら',
    // 人種・民族差別
    '朝鮮人', 'ちょうせんじん',
    'チョン', 'ちょん', 'チョンコ', 'ちょんこ',
    '在日', 'ざいにち',
    'シナ人', '支那人', '支那', 'しな',
    '中国人', // 文脈依存だが警戒
    'チャンコロ', 'ちゃんころ',
    'クロンボ', 'くろんぼ',
    '黒人', 'こくじん', // 文脈依存
    'ニガー', 'にがー',
    '土人', 'どじん',
    '蛮人', 'ばんじん',
    '毛唐', 'けとう',
    'ジャップ', 'じゃっぷ', 'JAP',
    '倭人', 'わじん',
    '島国根性', 'しまぐにこんじょう',
    // 部落差別
    'えた', 'エタ', '穢多',
    'ひにん', 'ヒニン', '非人',
    '部落', 'ぶらく', '部落民', 'ぶらくみん',
    '同和', 'どうわ',
    '被差別部落', 'ひさべつぶらく',
    '四つ', 'よつ', // 部落差別用語
    // 性差別
    'くそ女', 'クソ女', '糞女',
    'くそ男', 'クソ男', '糞男',
    'まんさん', 'マンさん', 'マンさん',
    'ちんさん', 'チンさん',
    'フェミ', 'ふぇみ', // 蔑称として
    'ま〜ん', 'まーん',
    'ち〜ん', 'ちーん',
    '女は', 'おんなは',
    '女って', 'おんなって',
    '男は', 'おとこは',
    '男って', 'おとこって',
    // 宗教差別
    'カルト', 'cult', 'かると',
    '邪教', 'じゃきょう',
    '統一教会', 'とういつきょうかい',
    '創価', 'そうか',
    // 職業差別
    '乞食', 'こじき', 'コジキ',
    'ホームレス', 'ほーむれす', '浮浪者',
    'ルンペン', 'るんぺん',
    '土方', 'どかた',
    '百姓', 'ひゃくしょう',
    // 外見差別
    'ブス', 'ぶす', '不細工', 'ぶさいく', 'ブサイク',
    'デブ', 'でぶ', 'デヴ', 'でヴ', '豚', 'ぶた',
    'ハゲ', 'はげ', '禿', 'ハゲカス',
    'チビ', 'ちび', 'チビカス',
    'ガリ', 'がり', 'ガリガリ',
    'キモい', 'きもい', 'キモ', 'きも', 'キモオタ',
    'ブサメン', 'ぶさめん',
    // 年齢差別
    'ジジイ', 'じじい', 'クソジジイ',
    'ババア', 'ばばあ', 'クソババア',
    'ガキ', 'がき', 'クソガキ',
    '老害', 'ろうがい',
    'ゆとり', 'ゆとり世代',
  ];

  /// ヘイトスピーチ（日本語）
  static const List<String> hateJa = [
    '反日', 'はんにち',
    '売国奴', 'ばいこくど',
    '非国民', 'ひこくみん',
    '国賊', 'こくぞく',
    '帰れ', 'かえれ',
    '出ていけ', 'でていけ',
    'ゴキブリ', 'ごきぶり', // 蔑称として
    '害虫', 'がいちゅう',
    '駆除', 'くじょ',
    '滅びろ', 'ほろびろ',
    '絶滅しろ', 'ぜつめつしろ',
    '日本から出ていけ',
    '国に帰れ', 'くににかえれ',
    // 特定集団への攻撃
    '特亜', 'とくあ',
    '三国人', 'さんごくじん',
    '在特', 'ざいとく',
    'ネトウヨ', 'ねとうよ',
    'パヨク', 'ぱよく',
    'サヨク', 'さよく', '左翼',
    'ウヨク', 'うよく', '右翼',
  ];

  /// 罵倒・冒涜（日本語）
  static const List<String> profanityJa = [
    // 一般的な罵倒
    'バカ', 'ばか', '馬鹿', 'ﾊﾞｶ', 'バーカ', 'ばーか',
    'アホ', 'あほ', '阿呆', 'ｱﾎ', 'アーホ',
    'マヌケ', 'まぬけ', '間抜け', 'ﾏﾇｹ',
    'ボケ', 'ぼけ', '惚け', 'ﾎﾞｹ', 'ぼけなす',
    'カス', 'かす', '粕', 'ｶｽ', 'カスが',
    'クズ', 'くず', '屑', 'ｸｽﾞ', 'クズが',
    'ゴミ', 'ごみ', 'ｺﾞﾐ', 'ゴミが', 'ゴミカス',
    'クソ', 'くそ', '糞', 'ｸｿ', 'クッソ', 'くっそ', 'クソが',
    'シネ', 'しね', 'シネヨ', 'しねよ',
    'ウザい', 'うざい', 'うぜー', 'ウゼー', 'うぜえ', 'ウザ',
    'ウザッ', 'うざっ', 'うっざ',
    'キモい', 'きもい', 'キモ', 'きも', 'キモッ', 'きもっ',
    'きっしょ', 'キッショ',
    'きっも', 'キッモ',
    'こわ', 'コワ', 'こわっ',
    // 強い罵倒
    '死ねばいい', 'しねばいい',
    '消えろ', 'きえろ',
    '失せろ', 'うせろ',
    '黙れ', 'だまれ',
    '黙れよ', 'だまれよ',
    '消えてくれ', 'きえてくれ',
    '邪魔', 'じゃま', 'じゃまだ',
    '目障り', 'めざわり',
    '耳障り', 'みみざわり',
    // 侮辱
    'ザコ', 'ざこ', '雑魚', 'ｻﾞｺ',
    'ノロマ', 'のろま',
    '無能', 'むのう',
    '役立たず', 'やくたたず',
    'ポンコツ', 'ぽんこつ',
    'ノータリン', 'のーたりん',
    '低脳', 'ていのう',
    '低能', 'ていのう',
    '脳みそ', 'のうみそ',
    '腐ってる', 'くさってる',
    'オワコン', 'おわこん',
    '終わってる', 'おわってる',
    // ネットスラング罵倒
    'ワロタ', 'わろた', // 場合による
    '草', 'くさ', 'ｗｗｗ',
    'カス野郎', 'かすやろう',
    'クズ野郎', 'くずやろう',
    'ゴミ野郎', 'ごみやろう',
    'クソ野郎', 'くそやろう',
    'やろう', 'ヤロウ', '野郎',
    'てめえ', 'テメエ', 'てめー',
    'きさま', 'キサマ', '貴様',
    'おまえ', 'オマエ', 'お前',
    'てめぇ', 'テメェ',
    'あんた', 'アンタ',
  ];

  // ============================================================
  // 英語NGワード（LDNOOBW準拠 + 拡充）
  // ============================================================

  /// 暴力的表現（英語）
  static const List<String> violenceEn = [
    // Direct violence
    'kill', 'killing', 'killed', 'killer', 'k1ll', 'ki11',
    'murder', 'murdered', 'murderer', 'murdering',
    'die', 'dying', 'death', 'd13', 'd1e',
    'dead', 'deadly',
    'suicide', 'suicidal', 'su1c1de',
    // Physical violence
    'stab', 'stabbing', 'stabbed', 'stabber',
    'shoot', 'shooting', 'shot', 'sh00t',
    'gun', 'gunner', 'gunshot',
    'bomb', 'bombing', 'bomber', 'b0mb',
    'explode', 'explosion', 'explosive',
    'attack', 'attacked', 'attacker', 'attacking',
    'assault', 'assaulted', 'assaulting',
    'beat', 'beating', 'beaten',
    'punch', 'punching', 'punched',
    'kick', 'kicking', 'kicked',
    'strangle', 'strangling', 'strangled',
    'choke', 'choking', 'choked',
    'drown', 'drowning', 'drowned',
    'burn', 'burning', 'burned', 'burnt',
    'torture', 'tortured', 'torturing',
    'execute', 'execution', 'executed',
    'slaughter', 'slaughtered', 'slaughtering',
    'massacre', 'massacred',
    'bloodshed', 'bloodbath',
    // Threats
    'threat', 'threaten', 'threatening', 'threatened',
    'destroy', 'destroying', 'destroyed', 'destruction',
    'annihilate', 'annihilated', 'annihilation',
    'exterminate', 'exterminated', 'extermination',
    'eliminate', 'eliminated', 'elimination',
    // Self-harm
    'selfharm', 'self-harm', 'self harm',
    'cutting', 'cutter',
    'overdose', 'od',
    // Crime
    'kidnap', 'kidnapping', 'kidnapped',
    'abduct', 'abduction', 'abducted',
    'hostage',
    'ransom',
    'terror', 'terrorist', 'terrorism',
  ];

  /// 性的表現（英語）- LDNOOBW準拠
  static const List<String> sexualEn = [
    // Explicit terms
    'fuck', 'fucking', 'fucked', 'fucker', 'fucks',
    'fck', 'f*ck', 'f**k', 'fuk', 'fuc', 'phuck', 'phuk',
    'f u c k', 'f-u-c-k',
    'motherfucker', 'motherfucking', 'mf', 'mofo',
    'sex', 'sexual', 'sexually', 'sexy', 's3x', 'sexx',
    'porn', 'porno', 'pornography', 'pornographic', 'pr0n', 'p0rn',
    'nude', 'naked', 'nudity', 'nudes',
    'xxx', 'xxxx',
    // Male genitalia
    'dick', 'd1ck', 'dck', 'd!ck', 'dikc',
    'cock', 'c0ck', 'c*ck', 'cok',
    'penis', 'pen1s', 'p3nis',
    'balls', 'ballsack', 'nutsack',
    'schlong', 'dong', 'weiner', 'wiener',
    'boner', 'erection', 'erect',
    // Female genitalia
    'pussy', 'puss', 'p*ssy', 'pussie', 'pussies', 'pu55y',
    'vagina', 'vag', 'vaj',
    'clit', 'clitoris',
    'labia',
    'twat',
    // Breasts and buttocks
    'boob', 'boobs', 'boobie', 'boobies', 'b00bs', 'bewbs',
    'tits', 'titty', 'titties', 't1ts', 'tit',
    'breast', 'breasts',
    'nipple', 'nipples', 'nips',
    'ass', 'arse', r'a$$', '@ss', 'a55', 'azz',
    'butt', 'buttock', 'buttocks', 'butthole', 'bum',
    'anus', 'anal',
    // Sexual acts
    'cum', 'cumming', 'cumshot', 'jizz', 'jism',
    'orgasm', 'orgasms', '0rgasm',
    'masturbate', 'masturbation', 'masturbating',
    'wank', 'wanker', 'wanking',
    'jerk off', 'jerking off', 'jerkoff',
    'fap', 'fapping',
    'blowjob', 'blow job', 'bj', 'bl0wjob',
    'handjob', 'hand job', 'hj',
    'footjob', 'foot job',
    'rimjob', 'rim job',
    'fingering', 'finger',
    'penetrate', 'penetration',
    'intercourse',
    'fornicate', 'fornication',
    'sodomy', 'sodomize',
    'fellatio', 'cunnilingus',
    'sixty-nine', '69',
    'gangbang', 'gang bang',
    'threesome', '3some', 'foursome',
    'orgy', 'orgies',
    'bukakke', 'bukkake',
    'creampie', 'cream pie',
    'facial',
    'deepthroat', 'deep throat',
    'squirt', 'squirting',
    // Sexual violence
    'rape', 'raped', 'rapist', 'raping', 'r@pe',
    'molest', 'molester', 'molestation', 'molesting',
    'grope', 'groping', 'groped',
    'incest', 'incestuous',
    'pedophile', 'pedo', 'paedophile', 'ped0',
    'child porn', 'cp', 'child pornography',
    // Prostitution
    'whore', 'wh0re', 'wh*re', 'hoar', 'hore',
    'slut', 'sl*t', 'slutty', 's1ut',
    'prostitute', 'prostitution', 'prost',
    'hooker', 'h00ker',
    'escort', 'call girl',
    'stripper', 'stripping', 'stripclub', 'strip club',
    // Fetish
    'bdsm', 'bondage',
    'fetish', 'kink', 'kinky',
    'hentai', 'h3ntai',
    'milf', 'm1lf',
    'dildo', 'd1ldo',
    'vibrator', 'vibe',
    'fleshlight',
    'lube', 'lubricant',
    // Bodily functions (child-safe)
    'poop', 'poopy', 'poo', 'p00p',
    'pee', 'peepee', 'piss', 'pissing', 'pissed',
    'fart', 'farting', 'farts', 'farted',
    'crap', 'crapping', 'crapped',
    'shit', 'shitting',
    'dump', 'taking a dump',
  ];

  /// 差別的表現（英語）- LDNOOBW準拠
  static const List<String> discriminationEn = [
    // Racial slurs (strongest)
    'nigger', 'n1gger', 'n!gger', 'nigg3r', 'niggr', 'niga',
    'nigga', 'n1gga', 'nigg@', 'n!gga',
    'negro', 'negroid',
    'coon', 'c00n',
    'darkie', 'darky',
    'sambo',
    'spade',
    'jigaboo', 'jiggaboo',
    'porch monkey',
    'spook', // racial context
    'chink', 'ch1nk', 'chinky',
    'gook', 'g00k',
    'slope', 'slant', 'slant-eye',
    'zipperhead',
    'spic', 'spick', 'sp1c',
    'beaner', 'b3aner',
    'wetback', 'w3tback',
    'gringo',
    'cracker', 'cr@cker',
    'honky', 'honkey',
    'jap', 'j@p', 'nip',
    'towelhead', 'raghead',
    'camel jockey',
    'sand nigger',
    'paki', 'pak1',
    'curry muncher',
    'wop', 'dago', 'guido',
    'mick', 'paddy',
    'kike', 'k1ke', 'kyke',
    'heeb', 'hebe',
    'sheeny',
    'gypsy', 'gyp', 'gipsy',
    // Disability slurs
    'retard', 'retarded', 'tard', 'r3tard', 'ret@rd',
    'cripple', 'crippled', 'crip',
    'spaz', 'spazz', 'spastic',
    'handicapped', // context-dependent
    'lame', // literal disability context
    'dumb', // literal disability context
    'mute', // literal disability context
    'deaf', // literal disability context
    'blind', // literal disability context
    'autist', 'autistic', 'aut1st', // as slur
    'downie', 'downs',
    'mongo', 'mongoloid',
    'schizo', 'psycho',
    'lunatic', 'loony',
    'mental', 'mentall',
    // LGBTQ+ slurs
    'faggot', 'fag', 'f@g', 'f4g', 'fagg0t', 'fagget',
    'fags', 'faggots',
    'dyke', 'd1ke', 'dike',
    'lesbo', 'lezbo', 'lezzie',
    'tranny', 'tr@nny', 'trannie',
    'shemale', 'she-male', 'ladyboy',
    'homo', 'h0mo', // as slur
    'queer', // can be slur or reclaimed
    'pansy', 'fairy', 'sissy',
    'butt pirate', 'pillow biter',
    'carpet muncher',
    // Misogynistic slurs
    'bitch', 'b1tch', 'b*tch', 'biatch', 'b!tch',
    'bitches', 'bitchy',
    'cunt', 'c*nt', 'c0nt', 'kunt',
    'cunts',
    'hoe', 'ho', 'h03',
    'skank', 'skanky',
    'thot',
    'broad',
    'feminazi',
    // Religious slurs
    'kike', // Jewish
    'christ killer',
    'muzzie', 'muzz', // Muslim
    'bible thumper', 'bible basher',
    // General
    'inbred',
    'redneck', // context-dependent
    'hillbilly', // context-dependent
    'white trash',
    'trailer trash',
  ];

  /// ヘイトスピーチ（英語）
  static const List<String> hateEn = [
    // Nazi/White supremacist
    'nazi', 'naz1', 'n@zi',
    'hitler', 'h1tler', 'h!tler', 'heil',
    'führer', 'fuhrer',
    'kkk', 'ku klux klan',
    'white power', 'white pride',
    'white supremacy', 'white supremacist',
    'aryan', '14 words', '14/88', '1488',
    'sieg heil',
    'swastika',
    'neo-nazi', 'neonazi',
    'skinhead', // context-dependent
    // Genocidal language
    'genocide', 'genoc1de',
    'holocaust', 'h0locaust',
    'ethnic cleansing',
    'exterminate', 'extermination',
    'gas chamber', 'gas the',
    'final solution',
    // Exclusionary phrases
    'go back to',
    'go home',
    'get out of my country',
    'build the wall',
    'deport them',
    'keep them out',
    // Dehumanization
    'subhuman', 'sub-human',
    'untermensch',
    'vermin', 'cockroach', 'roach',
    'animal', 'animals', // when used for people
    'parasite', 'parasites',
    'invader', 'invaders',
    'illegal alien',
    // Hate groups
    'proud boys',
    'kkk',
    'alt-right', 'altright',
    'identitarian',
  ];

  /// 罵倒・冒涜（英語）
  static const List<String> profanityEn = [
    // Strong profanity
    'shit', 'sh1t', 'sh!t', 'shyt', 'sht', 's#it',
    'shits', 'shitty', 'shitting', 'shitted',
    'bullshit', 'bs', 'horseshit',
    'damn', 'dammit', 'damned', 'damnit',
    'goddamn', 'goddamnit', 'goddam',
    'hell', 'h3ll', // standalone use
    'crap', 'crappy', 'crapola',
    'bastard', 'b@stard', 'b4stard',
    'bastards', 'bastad',
    'asshole', 'a-hole', '@sshole', 'arsehole',
    'assholes', 'a$$hole',
    'douchebag', 'douche', 'douchenozzle',
    'prick', 'pr1ck',
    'scum', 'scumbag', 'scummy',
    'jackass', 'jack@ss',
    // Personal insults
    'loser', 'l0ser',
    'idiot', 'idi0t', '1diot',
    'idiots', 'idiotic',
    'moron', 'mor0n', 'moronic',
    'dumb', 'dumbass', 'dumbo',
    'stupid', 'stup1d', 'stoopid',
    'jerk', 'j3rk',
    'creep', 'creepy', 'creeper',
    'pervert', 'perv', 'perverted',
    'weirdo', 'weird',
    'freak', 'freaky', 'freakin',
    'suck', 'sucks', 'sucker', 'sucked',
    'blow', 'blows', 'blew',
    'pathetic', 'path3tic',
    'worthless', 'w0rthless',
    'useless',
    'trash', 'trashy',
    'garbage',
    'tool', // as insult
    'douche',
    'turd',
    // Dismissive
    'stfu', 'shut up', 'shut the fuck up',
    'gtfo', 'get the fuck out',
    'wtf', 'wth', 'what the fuck', 'what the hell',
    'lmfao', 'lmao', 'rofl',
    'omfg', 'omg',
    'ffs', 'for fucks sake',
    // Intensifiers
    'freaking', 'freakin', 'frickin', 'friggin',
    'effing',
    'bloody', 'blooming', 'blimey',
    'bugger', 'buggery',
    'bollocks', 'bollox',
    'wanker', 'tosser',
    'git', 'twit', 'prat',
    'arse',
  ];

  /// 著作権関連NGワード
  static const List<String> copyrightTerms = [
    // 違法ダウンロード関連
    'torrent', 'トレント', 'トレント',
    '無料ダウンロード', 'free download',
    'クラック', 'crack', 'cracked', 'cracks',
    '海賊版', 'pirate', 'piracy', 'pirated',
    'warez', 'w@rez',
    '割れ', 'われ', 'ワレ',
    'keygen', 'key generator',
    'serial key', 'シリアルキー', 'シリアルナンバー',
    'nulled', 'null3d',
    'leaked', 'リーク', 'リークした',
    // 著作権侵害
    '違法コピー', 'illegal copy',
    '著作権侵害', 'copyright infringement',
    '無断転載', '転載禁止',
    // 違法サイト関連
    'nyaa', 'sukebei',
    'mangadex', 'manga raw',
    '漫画村', 'まんがむら',
    'anitube', '9anime', 'kissanime',
  ];

  /// スパム・宣伝関連
  static const List<String> spamTerms = [
    // 金銭関連
    '今すぐ稼げる', '簡単に稼げる',
    '無料で稼げる', 'free money',
    '高収入', '副業', '副収入',
    'make money fast', 'get rich quick',
    'casino', 'カジノ',
    'gambling', 'ギャンブル',
    'betting', 'ベッティング',
    'lottery', '宝くじ',
    'crypto', 'bitcoin', 'ビットコイン',
    'nft', 'NFT',
    // 詐欺関連
    '当選', 'おめでとうございます',
    'winner', 'congratulations',
    'prize', 'reward',
    'claim', 'クレーム',
    'limited time', '期間限定',
    'act now', '今すぐ',
    // 出会い系
    '出会い', 'であい',
    'dating', 'hookup',
    '彼女募集', '彼氏募集',
    'dm me', 'dm送って',
    'line交換', 'LINE交換',
  ];

  // ============================================================
  // 許可リスト（誤検知防止）- 拡充版
  // ============================================================

  /// 許可リスト（NGワードに含まれるが許可する単語）
  static const List<String> allowlist = [
    // === 「死」を含むが問題ない表現 ===
    '必死', 'ひっし', '必死に',
    '死角', 'しかく',
    '死守', 'ししゅ',
    '死活問題', 'しかつもんだい',
    '決死', 'けっし', '決死の',
    '瀕死', 'ひんし',
    '生死', 'せいし',
    '死闘', 'しとう',
    '死力', 'しりょく',
    '致死', 'ちし',
    '仮死', 'かし',
    '脳死', 'のうし',
    '死者', 'ししゃ',
    '死亡', 'しぼう',
    '死去', 'しきょ',
    '死因', 'しいん',
    '死刑', 'しけい', // 議論的だが許容
    '死語', 'しご',
    '死体', 'したい',
    '死別', 'しべつ',
    '戦死', 'せんし',
    '病死', 'びょうし',
    '事故死', 'じこし',
    // === 「殺」を含むが問題ない表現 ===
    '殺菌', 'さっきん', '殺菌する',
    '殺虫', 'さっちゅう', '殺虫剤',
    '相殺', 'そうさい', '相殺する',
    '殺到', 'さっとう', '殺到する',
    '殺風景', 'さっぷうけい',
    '殺傷', 'さっしょう',
    // === 「sex」を含むが問題ない英単語 ===
    'essex',
    'unisex',
    'sextant',
    'sextet',
    'middlesex',
    'sussex',
    // === 「ass」を含むが問題ない英単語 ===
    'class', 'classic', 'classical', 'classify', 'classification',
    'glass', 'glasses', 'glassware',
    'mass', 'massive', 'massachusetts',
    'pass', 'passage', 'passed', 'passing', 'passenger', 'passport',
    'compass', 'encompass',
    'grass', 'grassland', 'grasshopper',
    'brass', 'brasserie',
    'bass', 'bassist',
    'embassy',
    'carcass',
    'cassette', 'cassava',
    'assassin', 'assassination', // ゲーム文脈では許容
    'assist', 'assistant', 'assistance',
    'assess', 'assessment',
    'asset', 'assets',
    'assign', 'assignment',
    'assure', 'assurance',
    'assume', 'assumption',
    'associate', 'association',
    'assemble', 'assembly',
    // === 「hell」を含むが問題ない英単語 ===
    'hello', 'shell', 'shellfish',
    'helium', 'helicopter', 'helipad',
    'michelle', 'rochelle',
    'othello',
    'seashell',
    'nutshell',
    'eggshell',
    'bombshell',
    // === 「cum」を含むが問題ない英単語 ===
    'document', 'documentation', 'documentary',
    'cucumber',
    'circumstance', 'circumstances',
    'accumulate', 'accumulation',
    'accurate', 'accuracy',
    'curriculum',
    'vacuum',
    'spectrum',
    'calcium',
    // === 「hit」を含むが問題ない英単語 ===
    'white', 'whiteboard',
    'exhibit', 'exhibition',
    'prohibit', 'prohibition',
    'architecture', 'architectural',
    'chitchat',
    // === 「die」を含むが問題ない英単語 ===
    'die', // as in dice
    'diesel',
    'diet', 'dietary',
    'audience',
    'ingredient',
    'medieval',
    'audience',
    'obedient', 'obedience',
    'expedient',
    'comedian',
    'guardian',
    // === 「kill」を含むが問題ない英単語 ===
    'skill', 'skills', 'skilled', 'skillful',
    'kilogram', 'kilometer',
    'kilobyte', 'kilohertz',
    // === 「cock」を含むが問題ない英単語 ===
    'cockatoo', 'cocktail', 'peacock',
    'cockpit', 'cocky',
    'hancock', 'hitchcock',
    // === 「tit」を含むが問題ない英単語 ===
    'title', 'titled', 'entitle', 'entitled',
    'constitution', 'constitutional',
    'institution', 'institutional',
    'competition', 'competitive',
    'petition', 'petitioner',
    'repetition', 'repetitive',
    'partition',
    'appetite',
    'quantity', 'quantities',
    'identity', 'identification',
    'entity',
    // === 「rape」を含むが問題ない英単語 ===
    'grape', 'grapes',
    'drape', 'drapes',
    'scrape', 'scraped',
    'escape', 'escaped',
    'therapeutic',
    'therapist', // not 'the rapist'
    // === 「anal」を含むが問題ない英単語 ===
    'analysis', 'analyst', 'analyze', 'analytical',
    'banal',
    'canal',
    'final', 'finally',
    'national', 'nationality',
    'original', 'originally',
    'journal', 'journalism',
    'signal',
    'tribunal',
    // === 「nip」を含むが問題ない英単語 ===
    'snip', 'snippet', 'snipping',
    'turnip',
    'juniper',
    'unipolar',
    'manipulate', 'manipulation',
    // === 「jap」を含むが問題ない英単語 ===
    'japan', 'japanese', // 正しい使用
    'jalapeno',
    'jasper',
    // === その他 ===
    'scunthorpe', // famous false positive
    'penistone', // UK place name
    'middlesex', // UK county
    'arsenal', // football team
    'dickens', // author
    'cocktail',
    // === 日本語その他 ===
    'クラス', 'くらす', // class
    'パス', 'ぱす', // pass
    'グラス', 'ぐらす', // glass
    'マス', 'ます', // mass
    'ヘリコプター', // helicopter
    'ダイエット', // diet
    'キログラム', // kilogram
    'スキル', // skill
    'タイトル', // title
    'アナリスト', // analyst
    'カクテル', // cocktail
    'エスケープ', // escape
    'セラピスト', // therapist
    'アライグマ', 'あらいぐま', // raccoon
    'アライブ', 'あらいぶ', // alive
    'アライアンス', // alliance
  ];

  // ============================================================
  // 類似文字マッピング（フィルタ回避対策）- 大幅拡充
  // ============================================================

  /// 類似文字変換マップ（Unicodeホモグリフ対策含む）
  static const Map<String, String> similarCharMap = {
    // === 数字 → アルファベット（リートスピーク対策）===
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
    // === 記号 → アルファベット ===
    '@': 'a',
    '\$': 's',
    '!': 'i',
    '+': 't',
    '&': 'and',
    '#': 'h',
    '|': 'l',
    '(': 'c',
    ')': 'o',
    '[': 'c',
    ']': 'o',
    '{': 'c',
    '}': 'o',
    '<': 'c',
    '>': 'o',
    '€': 'e',
    '£': 'l',
    '¥': 'y',
    // === キリル文字 → ラテン文字（Unicodeホモグリフ）===
    'а': 'a', // Cyrillic Small Letter A
    'Ａ': 'a', // Fullwidth Latin Capital Letter A
    'ɑ': 'a', // Latin Small Letter Alpha
    'α': 'a', // Greek Small Letter Alpha
    'в': 'b', // Cyrillic Small Letter Ve
    'ß': 'b', // Latin Small Letter Sharp S
    'с': 'c', // Cyrillic Small Letter Es
    'ϲ': 'c', // Greek Lunate Sigma Symbol
    'ⅽ': 'c', // Small Roman Numeral One Hundred
    'ԁ': 'd', // Cyrillic Small Letter Komi De
    'ɗ': 'd', // Latin Small Letter D with Hook
    'е': 'e', // Cyrillic Small Letter Ie
    'ё': 'e', // Cyrillic Small Letter Io
    'ε': 'e', // Greek Small Letter Epsilon
    'ɡ': 'g', // Latin Small Letter Script G
    'ɢ': 'g', // Latin Letter Small Capital G
    'һ': 'h', // Cyrillic Small Letter Shha
    'і': 'i', // Cyrillic Small Letter Byelorussian-Ukrainian I
    'ӏ': 'i', // Cyrillic Letter Palochka
    'ι': 'i', // Greek Small Letter Iota
    'ј': 'j', // Cyrillic Small Letter Je
    'к': 'k', // Cyrillic Small Letter Ka
    'κ': 'k', // Greek Small Letter Kappa
    'ⅼ': 'l', // Small Roman Numeral Fifty
    'ｌ': 'l', // Fullwidth Latin Small Letter L
    'м': 'm', // Cyrillic Small Letter Em
    'ⅿ': 'm', // Small Roman Numeral One Thousand
    'η': 'n', // Greek Small Letter Eta
    'ո': 'n', // Armenian Small Letter Now
    'о': 'o', // Cyrillic Small Letter O
    'ο': 'o', // Greek Small Letter Omicron
    'օ': 'o', // Armenian Small Letter Oh
    'р': 'p', // Cyrillic Small Letter Er
    'ρ': 'p', // Greek Small Letter Rho
    'ԛ': 'q', // Cyrillic Small Letter Qa
    'г': 'r', // Cyrillic Small Letter Ghe (looks like r)
    'ѕ': 's', // Cyrillic Small Letter Dze
    'ꜱ': 's', // Latin Letter Small Capital S
    'т': 't', // Cyrillic Small Letter Te
    'τ': 't', // Greek Small Letter Tau
    'υ': 'u', // Greek Small Letter Upsilon
    'ս': 'u', // Armenian Small Letter Seh
    'ν': 'v', // Greek Small Letter Nu
    'ⅴ': 'v', // Small Roman Numeral Five
    'ѡ': 'w', // Cyrillic Small Letter Omega
    'ω': 'w', // Greek Small Letter Omega
    'х': 'x', // Cyrillic Small Letter Ha
    'χ': 'x', // Greek Small Letter Chi
    'ⅹ': 'x', // Small Roman Numeral Ten
    'у': 'y', // Cyrillic Small Letter U
    'ү': 'y', // Cyrillic Small Letter Straight U
    'γ': 'y', // Greek Small Letter Gamma
    'ᴢ': 'z', // Latin Letter Small Capital Z
    // === 日本語特殊置換 ===
    '氏': '死',
    'タヒ': '死',
    'ﾀﾋ': '死',
    // '4': 'し', // 「4ね」対策 - 別途処理
    '工': 'エ', // 「工口」→「エロ」対策
    '口': 'ロ',
    '力': 'カ',
    '夕': 'タ',
    '卜': 'ト',
    '八': 'ハ',
    '二': 'ニ',
    '千': 'チ',
    '干': 'チ',
    // === 注音符号（Bopomofo）対策 ===
    'ㄅ': 'b',
    'ㄆ': 'p',
    'ㄇ': 'm',
    'ㄈ': 'f',
    'ㄉ': 'd',
    'ㄊ': 't',
    'ㄋ': 'n',
    'ㄌ': 'l',
    // === 数学記号・特殊記号 ===
    '∂': 'd',
    '∑': 'e',
    '∏': 'n',
    '√': 'v',
    '∞': '8',
    '≈': '=',
    // === ローマ数字 ===
    'Ⅰ': 'i',
    'Ⅱ': 'ii',
    'Ⅲ': 'iii',
    'Ⅳ': 'iv',
    'Ⅴ': 'v',
    'Ⅵ': 'vi',
    'ⅰ': 'i',
    'ⅱ': 'ii',
    'ⅲ': 'iii',
    'ⅳ': 'iv',
    'ⅵ': 'vi',
  };

  /// 全角 → 半角 変換対象
  static const Map<String, String> fullWidthToHalfWidth = {
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
    // 全角記号
    '！': '!', '？': '?', '＠': '@', '＃': '#', '＄': r'$',
    '％': '%', '＾': '^', '＆': '&', '＊': '*', '（': '(',
    '）': ')', '－': '-', '＝': '=', '＋': '+', '［': '[',
    '］': ']', '｛': '{', '｝': '}', '｜': '|', '＼': r'\',
    '：': ':', '；': ';', '"': '"', ''': "'", '＜': '<',
    '＞': '>', '，': ',', '．': '.', '／': '/', '～': '~',
  };

  /// カタカナ → ひらがな 変換対象
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
    'ヴ': 'ゔ',
    'ァ': 'ぁ', 'ィ': 'ぃ', 'ゥ': 'ぅ', 'ェ': 'ぇ', 'ォ': 'ぉ',
    'ッ': 'っ', 'ャ': 'ゃ', 'ュ': 'ゅ', 'ョ': 'ょ',
    'ー': '',
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
    'ﾞ': '゛', 'ﾟ': '゜',
    'ｧ': 'ぁ', 'ｨ': 'ぃ', 'ｩ': 'ぅ', 'ｪ': 'ぇ', 'ｫ': 'ぉ',
    'ｬ': 'ゃ', 'ｭ': 'ゅ', 'ｮ': 'ょ', 'ｯ': 'っ',
  };

  // ============================================================
  // 正規表現パターン（拡充版）
  // ============================================================

  /// NGパターン（正規表現）
  static final List<RegExp> ngPatterns = [
    // === 個人情報 ===
    // URL（スパム対策）- より厳格
    RegExp(r'https?://[^\s<>"{}|\\^\[\]`]+', caseSensitive: false),
    // メールアドレス（個人情報保護）
    RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+', caseSensitive: false),
    // 電話番号（日本）
    RegExp(r'0\d{1,4}[-\s]?\d{1,4}[-\s]?\d{3,4}'),
    RegExp(r'\d{3}[-\s]?\d{4}[-\s]?\d{4}'), // 携帯番号
    // 電話番号（国際）
    RegExp(r'\+\d{1,3}[-\s]?\d{1,4}[-\s]?\d{1,4}[-\s]?\d{1,4}'),
    // LINE ID等
    RegExp(r'line\s*[:：]\s*\S+', caseSensitive: false),
    RegExp(r'LINE\s*ID\s*[:：]?\s*\S+', caseSensitive: false),
    // SNSアカウント
    RegExp(r'@[a-zA-Z0-9_]{3,}'),
    RegExp(r'twitter\s*[:：]\s*\S+', caseSensitive: false),
    RegExp(r'instagram\s*[:：]\s*\S+', caseSensitive: false),
    RegExp(r'tiktok\s*[:：]\s*\S+', caseSensitive: false),
    // Discord
    RegExp(r'discord\s*[:：]\s*\S+#\d{4}', caseSensitive: false),

    // === 伏せ字パターン ===
    // 死○、殺○など
    RegExp(r'[死殺][○●〇◯＊\*]'),
    // ○ね、○す
    RegExp(r'[○●〇◯＊\*][ねすろ]'),
    // f○ck, s○it など
    RegExp(r'[fs][○●〇◯＊\*][a-z]{1,3}', caseSensitive: false),

    // === 文字間スペース回避パターン ===
    // f u c k
    RegExp(r'f\s+u\s+c\s+k', caseSensitive: false),
    RegExp(r'f[\s._-]*u[\s._-]*c[\s._-]*k', caseSensitive: false),
    // s h i t
    RegExp(r's\s+h\s+i\s+t', caseSensitive: false),
    RegExp(r's[\s._-]*h[\s._-]*i[\s._-]*t', caseSensitive: false),
    // d i e
    RegExp(r'd\s+i\s+e', caseSensitive: false),
    // k i l l
    RegExp(r'k\s+i\s+l\s+l', caseSensitive: false),
    // n i g g e r（分離対策）
    RegExp(r'n[\s._-]*i[\s._-]*g[\s._-]*g[\s._-]*[ae][\s._-]*r',
        caseSensitive: false),
    // し ね（日本語スペース挿入）
    RegExp(r'し\s+ね'),
    RegExp(r'死\s+ね'),
    RegExp(r'殺\s+す'),

    // === 繰り返し文字回避パターン ===
    // fuuuuck, shiiiit
    RegExp(r'f+u+c+k+', caseSensitive: false),
    RegExp(r's+h+i+t+', caseSensitive: false),
    RegExp(r'n+i+g+g+[ae]+r+', caseSensitive: false),
    RegExp(r'f+a+g+g?o?t?', caseSensitive: false),

    // === リートスピーク（数字置換）パターン ===
    // f4ck, sh1t, d13, k1ll
    RegExp(r'f[4a@]ck', caseSensitive: false),
    RegExp(r'sh[1i!]t', caseSensitive: false),
    RegExp(r'd[1i!][3e]', caseSensitive: false),
    RegExp(r'k[1i!]ll', caseSensitive: false),
    RegExp(r'n[1i!]gg[3e]r', caseSensitive: false),
    RegExp(r'f[4a@]g', caseSensitive: false),
    RegExp(r'r[3e]t[4a@]rd', caseSensitive: false),

    // === 日本語リートスピーク ===
    // 4ね（しね）
    RegExp(r'4\s*ね'),
    RegExp(r'し\s*4'),
    // 56（ころ）す
    RegExp(r'56\s*[すせ]'),
    // 工口（エロ）
    RegExp(r'工\s*口'),

    // === 危険なフレーズ ===
    // kill you, kill myself
    RegExp(r'kill\s+(you|your|myself|yourself|him|her|them)',
        caseSensitive: false),
    RegExp(r'gonna\s+kill', caseSensitive: false),
    RegExp(r'want\s+to\s+die', caseSensitive: false),
    // 殺してやる系
    RegExp(r'殺し?て?や[るろ]'),
    RegExp(r'ぶっ殺'),
    RegExp(r'ぶっころ'),

    // === IPアドレス（サーバー攻撃誘導防止）===
    RegExp(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b'),

    // === Base64エンコードされた可能性のある文字列 ===
    // 長いBase64文字列は怪しい
    RegExp(r'[A-Za-z0-9+/]{40,}={0,2}'),
  ];

  // ============================================================
  // 追加の正規表現パターン（カテゴリ別）
  // ============================================================

  /// 暴力関連パターン
  static final List<RegExp> violencePatterns = [
    // 脅迫フレーズ
    RegExp(r'(殺|ころ)し?て?(やる|あげる|おく)', caseSensitive: false),
    RegExp(r'(消|け)し?て?やる', caseSensitive: false),
    RegExp(r'(潰|つぶ)し?て?やる', caseSensitive: false),
    // 英語
    RegExp(r"(i('ll|'m going to)|gonna)\s*kill", caseSensitive: false),
    RegExp(r'die\s+in\s+a\s+fire', caseSensitive: false),
    RegExp(r'hope\s+you\s+die', caseSensitive: false),
  ];

  /// 性的関連パターン
  static final List<RegExp> sexualPatterns = [
    // 日本語
    RegExp(r'(エロ|えろ)(い|動画|画像|サイト)', caseSensitive: false),
    RegExp(r'(おっぱい|オッパイ)(見せて|触)', caseSensitive: false),
    RegExp(r'(やら|ヤラ)(せて|せろ)', caseSensitive: false),
    // 英語
    RegExp(r'(send|show)\s*(me\s+)?(nudes?|pics?)', caseSensitive: false),
    RegExp(r'wanna\s+f[u*]ck', caseSensitive: false),
    RegExp(r'(sex|fuck)\s+me', caseSensitive: false),
  ];

  /// 差別関連パターン
  static final List<RegExp> discriminationPatterns = [
    // 日本語
    RegExp(r'(朝鮮|韓国|中国)(人は|人って)', caseSensitive: false),
    RegExp(r'(帰れ|出ていけ)(よ|!|！)', caseSensitive: false),
    // 英語
    RegExp(r'(all|those)\s+\w+s\s+should\s+die', caseSensitive: false),
    RegExp(r'go\s+back\s+to\s+(your|their)\s+country', caseSensitive: false),
  ];

  // ============================================================
  // ユーティリティメソッド
  // ============================================================

  /// 全NGワードを取得（日本語）
  static List<String> get allJapaneseNgWords => [
    ...violenceJa,
    ...sexualJa,
    ...discriminationJa,
    ...hateJa,
    ...profanityJa,
  ];

  /// 全NGワードを取得（英語）
  static List<String> get allEnglishNgWords => [
    ...violenceEn,
    ...sexualEn,
    ...discriminationEn,
    ...hateEn,
    ...profanityEn,
  ];

  /// 全NGワードを取得
  static List<String> get allNgWords => [
    ...allJapaneseNgWords,
    ...allEnglishNgWords,
    ...copyrightTerms,
    ...spamTerms,
  ];

  /// カテゴリ別NGワードマップ
  static Map<NgWordCategory, List<String>> get categoryMap => {
        NgWordCategory.violence: [...violenceJa, ...violenceEn],
        NgWordCategory.sexual: [...sexualJa, ...sexualEn],
        NgWordCategory.discrimination: [
          ...discriminationJa,
          ...discriminationEn
        ],
        NgWordCategory.hate: [...hateJa, ...hateEn],
        NgWordCategory.profanity: [...profanityJa, ...profanityEn],
        NgWordCategory.copyright: copyrightTerms,
        NgWordCategory.spam: spamTerms,
      };

  /// カテゴリ別パターンマップ
  static Map<NgWordCategory, List<RegExp>> get patternMap => {
        NgWordCategory.violence: violencePatterns,
        NgWordCategory.sexual: sexualPatterns,
        NgWordCategory.discrimination: discriminationPatterns,
        NgWordCategory.pattern: ngPatterns,
      };

  /// 統計情報
  static Map<String, int> get stats => {
        'violenceJa': violenceJa.length,
        'violenceEn': violenceEn.length,
        'sexualJa': sexualJa.length,
        'sexualEn': sexualEn.length,
        'discriminationJa': discriminationJa.length,
        'discriminationEn': discriminationEn.length,
        'hateJa': hateJa.length,
        'hateEn': hateEn.length,
        'profanityJa': profanityJa.length,
        'profanityEn': profanityEn.length,
        'copyrightTerms': copyrightTerms.length,
        'spamTerms': spamTerms.length,
        'allowlist': allowlist.length,
        'totalNgWords': allNgWords.length,
        'patterns': ngPatterns.length,
      };
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
        return '暴力的表現';
      case NgWordCategory.sexual:
        return '性的表現';
      case NgWordCategory.discrimination:
        return '差別的表現';
      case NgWordCategory.hate:
        return 'ヘイトスピーチ';
      case NgWordCategory.profanity:
        return '罵倒・冒涜';
      case NgWordCategory.copyright:
        return '著作権関連';
      case NgWordCategory.personal:
        return '個人情報';
      case NgWordCategory.pattern:
        return 'パターン検出';
      case NgWordCategory.spam:
        return 'スパム・宣伝';
    }
  }

  /// カテゴリの重大度（高いほど重大）
  /// 5: 即時ブロック必須（暴力・差別・ヘイト）
  /// 4: 高リスク（性的・個人情報）
  /// 3: 中リスク（著作権・パターン）
  /// 2: 低リスク（罵倒）
  /// 1: 最低（スパム）
  int get severity {
    switch (this) {
      case NgWordCategory.violence:
        return 5;
      case NgWordCategory.sexual:
        return 4;
      case NgWordCategory.discrimination:
        return 5;
      case NgWordCategory.hate:
        return 5;
      case NgWordCategory.profanity:
        return 2;
      case NgWordCategory.copyright:
        return 3;
      case NgWordCategory.personal:
        return 4;
      case NgWordCategory.pattern:
        return 3;
      case NgWordCategory.spam:
        return 1;
    }
  }

  /// ブロック時のユーザーメッセージ
  String get blockMessage {
    switch (this) {
      case NgWordCategory.violence:
        return '暴力的な表現は禁止されています';
      case NgWordCategory.sexual:
        return '性的な表現は禁止されています';
      case NgWordCategory.discrimination:
        return '差別的な表現は禁止されています';
      case NgWordCategory.hate:
        return 'ヘイトスピーチは禁止されています';
      case NgWordCategory.profanity:
        return '不適切な言葉遣いは控えてください';
      case NgWordCategory.copyright:
        return '著作権に関わる表現は禁止されています';
      case NgWordCategory.personal:
        return '個人情報の投稿は禁止されています';
      case NgWordCategory.pattern:
        return '禁止されているパターンが検出されました';
      case NgWordCategory.spam:
        return 'スパムや宣伝は禁止されています';
    }
  }
}
