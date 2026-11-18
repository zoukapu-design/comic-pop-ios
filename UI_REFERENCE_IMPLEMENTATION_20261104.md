# ムビコマ 3画面・iOSネイティブ実装（2026-11-04）

## 正式なデザイン基準
ユーザーが提示した3枚のスクリーンショットに合わせて実装。
1. **カード挿入スタジオ**：青×黄、レックスのビデオプレビュー、±1/5秒、映像サムネイル、マイデッキ／お気に入り／おすすめ、4列×2段のレックスカード、「＋ 挿入」。
2. **画風／ジャンル選択**：アメコミ系、熱血少年漫画、少女漫画、ギャグ漫画、劇画・シネマ、ホラーの6枚、レックス画風の絵を見て選択、統一感設定、「この画風で漫画を作る」。
3. **漫画生成レビュー／クオリティ改善**：元動画と生成コマを実画像で比較、ページプレビュー、ページ送り、単一コマ再生成、画質調整、保存とPNG共有。

## アプリ起動ルート
`ios/COMICPOP/COMICPOPApp.swift` → `MovikomaPopRootView` に変更。以前の試作用 `MovikomaUI.swift` は互換性確認のため残るが、起動時には使用しない。

## 主要コード
- `PopTheme.swift`: SwiftUI漫画風パネル・網点・ヘッダー・ボタン・ステップナビ・独立アート素材レンダラ。
- `PopEditor.swift`: AVPlayerLayer、動画ピッカー、動画実フレームの5枚タイムライン、カード画面、ピン挿入、デッキ/お気に入り。
- `PopGenre.swift`: 6ジャンル画像カード、白黒／カラー、作品タイトル、4つの生成プロンプトヒント、端末内/Cloudflareの生成方式。
- `PopReview.swift`: 動画/漫画の実画像比較、ページ切替、コマ再生成、画質調整、完成時の保存導線。
- `PopPageFinisher.swift`: Core Image のコントラスト・明るさ・彩度・シャープネスを漫画に適用。
- `PopApp.swift`: 単一StudioStoreを共有する3画面ルート、メニュー、ヘルプ、デッキ管理、作品一覧とPNG共有、Cloudflare認証設定。
- `StudioStore.swift`: 再生成結果の整合性保護、品質フィルターを累積させない基準画像、単一コマ再生成機能。

## レックス絵・漫画絵の扱い
**3枚の参照画像全体をUI背景として貼り付けていない。**
ユーザー承認の参照画像から4種類の個別画像素材を切り出し、Xcode asset catalogへ同梱。
- `PopCardAtlas.imageset`: 8種類のレックスカード用の**イラスト部分のみ**（日本語ラベルはSwiftUI Text）。
- `PopGenreAtlas.imageset`: 6ジャンルの**イラスト部分のみ**。
- `PopHero.imageset`: ヒーロー／ガイド用レックスのアート。
- `PopLogo.imageset`: 小さなヘッダー用レックス絵。
ボタンやカード背景、画風選択チェックマーク、動画再生・スクロール・共有などはすべてタップ可能なSwiftUI/AVKitのUI。

## 正直な制約
- レビューの「98%人物一致」等の自動評価は未実装。架空スコアは表示しない。表示する画質値は**操作可能な実際の画像処理強度**。
- 音声認識による台詞抽出・高品質な一貫キャラ生成の自動保証は未完成。統一感の4設定はCloudflare AIプロンプトへの**実験的ヒント**であり、保証値ではない。
- 端末内無料モードは実動画フレームへの漫画調フィルタ（生成AIではない）。Cloudflare利用者自身の無料枠はアプリがプラン種別を自動検証できない。
- 動画未選択時に表示するレックスのアートは実際の動画フレームではなく、**初期プレースホルダー**。動画選択後は実画像を表示。
- Xcodeのネイティブビルド／実機スクリーンショットについてはGitHub CIまたはCodemagicの結果で別途判断する。動作済みと決めつけない。

## テストとビルド
- GitHub Ubuntu source preflight: `Movikoma Swift source preflight`。
- GitHub macOS: `Movikoma native iOS Simulator compile`。
- Codemagic: `ios-unsigned-check`、成功したら手動で `ios-testflight-upload`。
- iPhone12で実動画→±1秒→カード挿入→ジャンル6種→端末内生成→ページレビュー→全ページ画像調整→PNG共有を確認。
- 4カード=1ページ、5カード=2ページ、12カード=3ページ。途中失敗の再開と、動画変更時に旧カード消去を確認。

作業ブランチ: `feat/movikoma-rex-reference-ui`、PR: https://github.com/zoukapu-design/comic-pop-ios/pull/1。
