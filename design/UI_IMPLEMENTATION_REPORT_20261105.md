# ムビコマ｜実装報告とiPhone検証チェック（2026-11-05）

## 正本と実装の考え方
- 最新承認の「レックス／青×黄／漫画ポップ」UIイメージを、**実際のiOS SwiftUI/AVKitアプリ**として実装。全画面画像でスクリーンショットを表示しているわけではない。
- キャラクター・ジャンル・カードの絵だけ画像素材（`Pop*.imageset`）。背景の網点、白いカード、影、選択状態、ボタン、ページ表示、スライダー、タイムライン、リスト、フローはネイティブUI。
- アプリ入口：`ios/COMICPOP/COMICPOPApp.swift` → `MovikomaPopRootView`。
- 作業ブランチ：`feat/movikoma-rex-reference-ui`、PR: https://github.com/zoukapu-design/comic-pop-ios/pull/1。

## ユーザーフローとコード対応
| 画面 | 実装 | ソース |
|---|---|---|
| 0 初回開始＋3ステップ案内 | 初回のみ表示、はじめる／使い方を見る | `PopWelcome.swift`, `PopApp.swift` |
| 1 ホーム | 新規作成、前回の続き、作品一覧、デッキ、設定 | `PopJourney.swift` |
| 2 動画選択 | 実PhotosPicker/Files、動画サムネイル、長さ、変更時のカード消去確認 | `PopJourney.swift`, `StudioStore.swift` |
| 3 カード挿入 | 実AVPlayerLayer、動画からの5サムネイル、時間スクラブ、±1/5秒、8レックスカード、カードをタップして挿入、挿入済み一覧 | `PopEditor.swift` |
| 4 画風選択 | レックス絵6種、画風の単一選択、白黒/カラー、4つのAIプロンプトヒント、任意タイトル | `PopGenre.swift`, `VideoAndAI.swift` |
| 5 生成中 | 本物の成功コマ数を表示、端末内無料／個人Cloudflare AI分離、途中失敗時の再開 | `PopGenre.swift`, `StudioStore.swift` |
| 6 漫画レビュー | 動画/生成コマ比較、全コマ選択、ページ切替、単一コマ再生成、Core Imageのコントラスト/明るさ/彩度/シャープネス処理、完成時のみ保存 | `PopReview.swift`, `StudioStore.swift`, `PopPageFinisher.swift` |
| 7 保存成功/共有 | 作品名・ページプレビュー、各ページPNG共有、実複数ページPDF共有 | `PopJourney.swift`, `PopFileShareSheet.swift`, `StudioStore.swift` |
| 8 作品一覧 | タイトル・日時・コマ数・ページプレビュー、PNG/PDF共有、削除確認 | `PopApp.swift`, `StudioStore.swift` |
| 9 マイデッキ | デッキ新規/変更/削除、カード検索・登録・除外、並び替え、上限保護 | `PopApp.swift` |
| 10 設定 | レックス基調UI、基本画風/色、個人Cloudflareアカウント、Keychain、契約注意、保存件数 | `PopSettingsPanel.swift` |

## 主要な動作ガード
- ピン保存中は重複挿入を防止、最大12カード、動画変更／ピン削除中の非同期結果は無効化。
- 画風変更でもピンは保持。動画変更時の旧ピンと旧画像は破棄、マイデッキと保存済み作品は維持。
- 明示的に選んだ白黒/カラーは画風選択を切り替えても保持。
- 漫画の生成コマIDと挿入ピンIDの**完全一致・順序一致・ページ枚数一致**がなければ完成として保存不可。
- 生成失敗時は元動画/ピン順/画風/カラー/生成方式が一致する場合のみ成功済みコマを利用して残りを再試行。
- 画質調整は元画像を保持してCore Imageで再計算し、累積劣化を避ける。
- フルスクリーンのサンプル写真や架空のAI一致率はアプリに埋め込まない。

## 現在の検証の限界
**GitHub Ubuntu**：全iOS SwiftファイルのSwift構文パース、Foundationモデルテスト、生成整合性14ケース、UI接続静的監査。成功を確認。

**iOS実コンパイル／実機**：macOSランナーは待機・キャンセルとなったため未検証。Codemagicの `ios-unsigned-check` が必要（無料枠節約のため1回に集約）。`ios-testflight-upload` は署名・実機レビューができる段階まで実行しない。

**注意**：画像と一致するピクセル寸法・画面の滑らかさ・ホームのスクロール・SwiftUIの制約解決等はXcode/iPhone実行での比較が必要。現時点で「完全に動作確認済み」や「デザイン完全一致」とは宣言しない。

**漫画生成品質**：端末内無料モードは実フレームの漫画調フィルターであり、本格AI再作画ではない。Cloudflare AIは本人のWorkers Free枠を使うが、無料契約状態・残量をアプリから自動保証できない。動画音声の台詞理解、物語としての自動構成、同じ人物の絵柄維持の高品質保証は今後の研究/実装対象。

## Codemagicで行う一括検証（ビルド回数節約）
1. 対象ブランチを `feat/movikoma-rex-reference-ui` に指定して `ios-unsigned-check` を1回実行。
2. Swiftコンパイラのエラー箇所（あれば）を修正し、プロジェクト生成・iOS Simulatorビルド成功を確認。
3. ブランチ上で署名設定を確認し、`ios-testflight-upload` を手動起動する。
4. iPhone12で初回ガイド→動画選択→動画再生→±1/5秒→8種カード→4/5/12ピン→端末内無料生成→コマ比較→画質調整→PNG/PDF共有→作品削除を実操作。
5. 承認済み参考画像と、iPhone上の各画面スクリーンショットを並べて照合し、タップ領域・文字欠け・SafeArea・レックス絵の欠損を修正。
