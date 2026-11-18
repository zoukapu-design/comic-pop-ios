# ムビコマ｜再生成無料枠保護・AI脚本失敗制御・CI二重起動解消（2026-11-12）

## 現状
- 作業ブランチ：`feat/movikoma-rex-reference-ui` / draft PR #1
- 前回：`design/SESSION_20261112_STORY_TRUTH_AND_RETAKE_ROLLBACK.md`。
- 今回は**実装コード・回帰テスト・UI注意文・Actions workflow**をGitHubに反映。既存作品の保存形式を壊すスキーマ変更は行わない。

## 1. 再生成回数を途中復元データに永続化
問題：`StudioStore.panelRetryCount` がアプリ終了時に消えていたため、同じ画像の再生成を再起動後に行うと、同じ乱数 seed を選び直し、ユーザーのCloudflare無料枠を消費する危険。

変更：
- `MangaDraftCheckpoint.swift` に任意の `retryCounts:[UUID:Int]?` を追加。**既存version=1のフィールドなしJSONを読める**よう、optionalを使用。
- チェックポイントの互換性検証で再試行回数の対象を生成済み画像のIDに限定。負の値と過大値（100,000超）を拒否。
- `StudioStore.saveDraftCheckpoint` が再試行回数を一緒に原子的に保存し、`restoreDraftCheckpoint` が現存する画像のIDだけを復元。
- 前回の「画像の再生成が保存失敗したら旧画像・シード・フィルターへロールバック」を維持。
- `tests/mangaDraftCheckpointTests.swift` に永続性、旧形式読込、異常な再試行回数などの回帰テストを追加。

## 2. 画像理解AIの失敗後に無条件で別AIを呼ばない
問題：`MangaStoryAIService.createPlan` では、画像モデルが malformed JSON を返しても、HTTP 500等の一時失敗でも`catch {}`でGLMへ自動フォールバックしていた。最初のAI呼出しがすでに無料枠を消費していた場合、ユーザーが明示的にやり直さなくても2件目が発生。

変更：
- `MangaVisualStoryRetryPolicy.swift` を追加。HTTP 401/403=認証、402/429=利用枠、404/405/415/422=非対応、ほかのHTTP非成功=サーバー/リクエストエラー。
- **モデル/エンドポイントが明確に非対応の場合だけ**文字情報GLMへのフォールバックを許容。これは別のモデル呼出しになるためUIに明記。
- 画像AIが不完全/不正な脚本JSONを返した、5xx、通信タイムアウトの場合は自動の別AI呼出しを停止。画風選択画面で画像理解をOFFにすれば、本人が選んで文字情報ベースで再試行可能。
- 認証/無料枠エラーの特別処理は維持。モデルの利用枠/課金プラン自体の検知は未実装。
- `MangaStoryServices.swift`、`PopGenre.swift`、`tests/mangaVisualStoryRetryPolicyTests.swift`、`tests/run.sh`、`tests/verify_ui_reference.py` を更新。

## 3. GitHub Actionsの重複実行を抑制
- `.github/workflows/movikoma-source-check.yml` は従来、PR更新と同ブランチpushの**両方で同じテストを起動**。PR #1がある間は二重実行されていた。
- `pull_request` と手動 `workflow_dispatch` のみへ変更。並行実行制御で古い検査をキャンセル。
- **CI失敗の根本原因は未解消。** 最新の確認ジョブ（run `43089400239`）は `steps: []`, `runner_id:0`、課金対象実行時間 `0 ms`、約3秒で failure。Swiftコードを一行も実行した証跡がない。
- 再実行を繰り返さず、[GitHub Actions run](https://github.com/zoukapu-design/comic-pop-ios/actions/runs/43089400239) のジョブ上部エラーバナーと、リポジトリ Actions 設定、アカウントのActions請求・利用枠・予算を確認する。**原因は未確定なので、請求エラーと断言しない。**

## 検証の範囲を区別
- 最新GitHubの関連10ファイルを再読込して参照関係・保護条件の**静的照合17/17 PASS**。
- Linux Swift 6.2.1で、GitHub実装と同じスキーマ・判定式の小規模独立検証を実行：再生成回数のJSON保存/旧形式/異常値、Visual AI HTTP/フォールバック分類ともに**PASS**。
- これらは**リポジトリ全体をcloneして `bash tests/run.sh` を実行した結果ではない**。
- **未検証**：`tests/run.sh` 全体、SwiftUI + UIKitの実コンパイル、Codemagic署名ビルド、TestFlight、実際の動画・Cloudflare生成画像の出来栄え。

## 今後の順序
1. GitHub Actionsのランナー起動前エラーバナーと請求・制限状態を確認し、CI環境正常化。
2. `bash tests/run.sh` で全体回帰検証（ローカルLinuxまたは正常化したrunner）。
3. `ios-unsigned-check` でiOS全コンパイル。無料ビルド枠を確認してから実施。
4. 2〜12カードと実動画で脚本の整合性、人物・服・画風、回想・重複、アプリ再起動後の再生成シード差、保存エラー時のデータ保持をiPhone 12で確認。
5. 承認済みレックス素材のUIをスクリーンショットで比較、未達の箇所を修正。

## 変更しない範囲
- 他アプリ・他リポジトリ、Cloudflareのトークン・課金プラン、Codemagicの有料ビルド、TestFlight配信、ユーザー保存済み作品／動画／ピンカード。
