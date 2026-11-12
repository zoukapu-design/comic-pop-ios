# ムビコマ｜現行ソースのSwift実行検証・文字品質修正（2026-11-12）

## このターンで実際に進めたこと

前回の「本番UI全面改修・12シーン×最大3カード合成・長文メモ保持」を踏まえ、**非公開GitHubのSwiftソースを取得してGit blob SHAの一致まで確認したうえで、実ローカルSwiftコンパイル／実行**を行った。GitHub Actionsのランナーが割り当てられない問題は依然として残るため、少なくとも純Swiftの中核部品を具体的に検証した。

### 実行検証（コンテナ Swift 6.2.1 / Linux x86_64）

| 対象 | GitHub原本との一致 | 検証 | 結果 |
|---|---|---|---|
| `MangaDrawingPrompt.swift` | blob `b279127ece719757e96962e5ce87d139f9580405` | 3カードの786文字メモ、全カードID・手動指示、2400文字上限、飽和条件2382文字 | PASS |
| `Models.swift` + `CardSceneGrouping.swift` + `MangaSceneCapacity.swift` | blob SHA `64dc38fc…`, `5ed24755…`, `d6b9802f…` | 12シーン/3枚、13シーン拒否、36カード、非有限時刻拒否、**2500組×35回の挿入シナリオ**でシーン数・順序・ページ数検査 | PASS |
| `MangaDraftCheckpoint.swift` | blob `e146eb856b9adc4f9e777c84fd0630e9c7f1de5a` | 旧JSON互換、再生成回数JSON round-trip、不正ID・負値・過大値の拒否（`MangaStoryPlan`は検証用Codableスタブ） | PASS |
| `MangaCaptionNotePolicy.swift` + 専用テスト | blob `a9a1dbc0…` / `5c6aa9fe…` | GitHub本体の**正確なソースとテスト**をコンパイル／実行。感情演出メモ除外、カメラを落とす等の実行動作を保持、音声優先 | PASS |
| `MangaVisualStoryRetryPolicy.swift` + 専用テスト | blob `2f0cd250…` / `971c3247…` | GitHub本体の**正確なソースとテスト**をコンパイル／実行。5xx・429・401・不正応答では追加AI呼出し不可、明確なモデル非対応時だけ fallback | PASS |

検証用のSwiftファイルはGitHubからの内容を手動で再現したが、原本blob SHAと一致したものだけを「原本と同一」と判定。これらは**端末ネイティブUIKit/SwiftUI全体のビルドPASSではない**。

## 見つけて修正した本物の漫画テキスト不具合

従来は自由記述のピンカードのメモを`MangaStoryPlanner.fallback`がそのまま自動ナレーションとして採用した。ユーザーが「怖く演出して」「面白いオチにしたい」と入力すると、その制作指示が漫画のコマ内の本文として表示されかねない。

- 新規 `ios/COMICPOP/MangaCaptionNotePolicy.swift`：
  - 描画・演出・カメラアングル・構図・効果音・色調などの制作指示を**自動ナレーションから除外**。
  - 「主人公が鍋を持ち上げる」「主人公がカメラを落とした」「友達の肩にタッチした」は**物語内の観測動作として保持**。
  - 認識済み音声があれば演出指示の代わりに利用。元メモは`userSceneNoteJP`に別途保持し**作画指示として引き続き利用**。
- `MangaStory.swift`：オフライン仮脚本だけでなく、**AIが日本語の制作指示をそのままcaptionへ返しても**読み上げ字幕として採用しないよう保護。
- `tests/mangaCaptionNotePolicyTests.swift` + `tests/mangaStoryTests.swift`：上記の合格・不合格例を追加。
- `tests/run.sh`：新ポリシーファイルを全脚本テストのSwiftコンパイルへ接続。
- `tests/verify_ui_reference.py`：ポリシーの参照と新しい脚本処理を要求。**実行前に未定義の `preflight` を参照していた既存の静的テスト不具合**も修正した。

## 外部APIの仕様確認

Cloudflare公開資料により、使用中の `@cf/black-forest-labs/flux-2-klein-4b` がmultipartで`input_image_0..3`を受け取り、参照画像が512px未満であるという契約を確認。現行`VideoFrameService.compactJPEG`の最大辺480px制限と整合。実アカウントAPI認証・推論実行・出力画質は未検証。

参考：
- https://developers.cloudflare.com/changelog/post/2026-01-15-flux-2-klein-4b-workers-ai/
- https://developers.cloudflare.com/ai/models/%40cf/black-forest-labs/flux-2-klein-4b/

## リリース判定

純Swiftの局所検証は進展したが、未解決ゲート：
1. GitHub Actions `source-preflight`のランナー未割り当て（`runner_id:0`、実行ステップなし）。理由はこの環境から確認できるGitHub RESTの範囲では不明。
2. `bash tests/run.sh`全体・XcodeGen・iOSコンパイルが未完了。
3. TestFlightのiPhone 12操作、参考レックス画面とのスクリーンショット比較、実動画の1〜12シーンのFLUX画像評価が未完了。
4. Cloudflare無料枠の残量／真のユーザーごとの利用量は現アプリではサーバー検証できず、利用回数の厳密保証は未完成。

Mainブランチ・ユーザーの保存済み動画・カード・デッキ・作品・CloudflareのAPI利用／有料ビルドは変更していない。今回のコード変更は作業ブランチ`feat/movikoma-rex-reference-ui`にのみコミット。
