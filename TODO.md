# 4×4 Pixel Diary 実装TODOリスト

## 概要

- **総タスク数**: 40項目
- **セキュリティ関連**: 19項目
- **アーキテクチャ**: Flutter + Riverpod + MVVM
- **バックエンド**: AWS (API Gateway + Lambda + DynamoDB)

---

## 🚨 プライバシー方針

> **個人情報は一切収集・保存しない**

- メールアドレス、電話番号、SNSアカウント等は取得しない
- 認証は**匿名ID（デバイスID/UUID）ベース**で実装
- ユーザー識別は端末固有のランダムUUIDのみ
- ニックネームは任意設定（5文字以内）
- 位置情報、広告IDは取得しない

---

## 🏗️ 基盤構築（4項目）

- [ ] プロジェクト基盤構築（Flutter + Riverpod + MVVM設定）
- [ ] データモデル定義（PixelArt, AnonymousUser, Album, Post, Comment）
- [ ] ローカルストレージ設定（Hive/Isar + AES暗号化）
- [ ] ネットワーク層構築（Dio + Interceptor + 証明書ピンニング）

---

## 🎨 ドット絵作成機能（4項目）

- [ ] 4×4ドット絵キャンバス実装（CustomPaint）
- [ ] カラーパレット・HSVカラーピッカー実装
- [ ] タイトル入力（5文字制限バリデーション）
- [ ] 戻る/やり直し機能実装（Undo/Redo）

---

## 🔄 交換・アルバム機能（4項目）

- [ ] ドット絵交換API連携（POST /pixelart/exchange）
- [ ] アルバム画面（2列グリッドレイアウト・ページング・ソート）
- [ ] アルバム詳細画面（拡大表示・シェア・削除・スワイプ移動）
- [ ] 通報・削除機能実装

---

## 📱 タイムライン機能（2項目）

- [ ] 投稿タイムライン画面（おすすめ/新着タブ・無限スクロール）
- [ ] いいね・コメント機能実装（50文字制限）

---

## 📡 Bluetooth すれ違い通信（5項目）

- [ ] Bluetooth通信実装（flutter_blue_plus）
- [ ] すれ違い通信画面（手動/自動モード・履歴表示）
- [ ] 🔒 BLE暗号化実装（LE Secure Connections + AES-CCM）
- [ ] 🔒 BLEペアリング認証（Passkey/Numeric Comparison）
- [ ] 🔒 MACアドレスランダム化設定

---

## ⚙️ 設定・UI（4項目）

- [ ] 設定画面（ニックネーム/テーマ/通知/Bluetooth設定）
- [ ] 日記カレンダー機能実装（CalendarDatePicker）
- [ ] 5×5グリッド課金機能（in_app_purchase）
- [ ] ダークモード対応（ライト/ダーク/システム連動）

---

## 🔐 認証（2項目）

- [ ] 🔒 匿名認証実装（デバイスUUID + Cognito匿名ID）
- [ ] 🔒 flutter_secure_storage導入（UUID・トークンの安全保存）

---

## 🛡️ APIセキュリティ（5項目）

- [ ] 🔒 TLS 1.3 + 証明書ピンニング設定
- [ ] 🔒 API入力検証・サニタイズ実装（型・長さ・内容検証）
- [ ] 🔒 リクエスト署名・タイムスタンプ・nonce検証（リプレイ攻撃防止）
- [ ] 🔒 AWS WAFルール設定（SQLi/XSS/Bot検出）
- [ ] 🔒 APIレート制限設定（API Gateway使用プラン）

---

## 🔑 秘密情報管理（1項目）

- [ ] 🔒 AWS Secrets Manager設定（APIキー・DB認証情報の安全管理）

---

## 📝 コンテンツモデレーション（2項目）

- [ ] 🔒 NGワードフィルタ実装（フロント/バック両方）
- [ ] 🔒 コンテンツモデレーション（Amazon Comprehend + Rekognition）

---

## 🛠️ コード保護（2項目）

- [ ] 🔒 コード難読化設定（dart-obfuscation + ProGuard/R8）
- [ ] 🔒 ルート/ジェイルブレイク検知実装

---

## 📊 監視・ログ（2項目）

- [ ] 🔒 CloudWatch/CloudTrail/GuardDutyログ監視設定
- [ ] 🔒 セキュリティアラート設定（EventBridge + 通知）

---

## 📜 利用規約（1項目）

- [ ] 利用規約・プライバシーポリシー画面実装（個人情報非収集を明記）

---

## 🔧 DevOps（4項目）

- [ ] オフライン同期機能実装
- [ ] プッシュ通知実装（トピックベース・匿名）
- [ ] 🔒 CI/CD静的解析・脆弱性チェック統合
- [ ] AWSバックエンド構築（API Gateway + Lambda + DynamoDB + S3）

---

## 📁 推奨ディレクトリ構造

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── constants/
│   ├── theme/
│   ├── utils/
│   └── extensions/
├── data/
│   ├── models/
│   │   ├── pixel_art.dart
│   │   ├── anonymous_user.dart  # 匿名ユーザー（UUIDのみ）
│   │   ├── album.dart
│   │   ├── post.dart
│   │   └── comment.dart
│   ├── repositories/
│   └── datasources/
│       ├── local/
│       └── remote/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
├── presentation/
│   ├── pages/
│   │   ├── home/           # ドット絵作成
│   │   ├── album/          # アルバム
│   │   ├── timeline/       # 投稿タイムライン
│   │   ├── bluetooth/      # すれ違い通信
│   │   ├── calendar/       # カレンダー
│   │   └── settings/       # 設定
│   ├── widgets/
│   └── viewmodels/
├── providers/
└── services/
    ├── api/
    ├── auth/               # 匿名認証
    ├── bluetooth/
    ├── storage/
    └── notification/
```

---

## 📊 カテゴリ別サマリー

| カテゴリ | 項目数 | セキュリティ項目 |
|---------|--------|-----------------|
| 基盤構築 | 4 | 2 |
| ドット絵作成 | 4 | 0 |
| 交換・アルバム | 4 | 0 |
| タイムライン | 2 | 0 |
| Bluetooth | 5 | 3 |
| 設定・UI | 4 | 0 |
| 認証 | 2 | 2 |
| APIセキュリティ | 5 | 5 |
| 秘密情報管理 | 1 | 1 |
| コンテンツモデレーション | 2 | 2 |
| コード保護 | 2 | 2 |
| 監視・ログ | 2 | 2 |
| 利用規約 | 1 | 0 |
| DevOps | 4 | 1 |
| **合計** | **42** | **20** |

---

## 🗑️ 削除した項目（個人情報非収集のため）

以下は個人情報を扱わない方針により不要となった項目：

- ~~AWS Cognito OAuth認証（メール/SNS連携）~~
- ~~MFA実装（メール/SMS/生体認証）~~
- ~~RBAC実装（管理者/一般ユーザー権限分離）~~ → 匿名のためシンプル化
- ~~個人情報保護法/GDPR対応（データ閲覧・削除機能）~~ → 個人情報なし

---

## 凡例

- [ ] 未着手
- [x] 完了
- 🔒 セキュリティ関連タスク

---

## 参考リンク

- [Flutter公式ドキュメント](https://docs.flutter.dev/)
- [Riverpod公式ドキュメント](https://riverpod.dev/)
- [AWS Amplify Flutter](https://docs.amplify.aws/lib/q/platform/flutter/)
- [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus)
- [in_app_purchase](https://pub.dev/packages/in_app_purchase)
- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)
