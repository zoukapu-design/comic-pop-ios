# ムビコマ 開発継続記録｜2026-11-09

正本：`zoukapu-design/comic-pop-ios` / `feat/movikoma-rex-reference-ui`（PR #1）

## 本日 GitHub に反映した改良

### A. ユーザー入力・端末データの原子性
- `StudioStore.persist(_ snapshot: StudioData?)` と `commit(_ candidate: StudioData)` を追加。端末の JSON への .atomic 書込みが成功してから `@Published data` を更新。
- カード追加時：JPEG を書き、候補の pins を保存し、成功時だけ編集状態へ反映。失敗した場合は新規 JPEG を削除し、古い pins と生成済み漫画を保持。
- カード削除・全削除：新しい pins 配列の保存成功後に旧 JPEG を消去。失敗時には旧 JSON と元画像を保持。
- カードの物語メモ／セリフ、画風、カラー、タイトル、デッキ（選択、追加、名前変更、削除、収録カード、並び順）も「保存成功→UI反映」に統一。
- 作品タイトルを変えた場合、生成済み PNG ページのヘッダーも再構築してメタデータと一致させる。

### B. AIの利用枠と明示的な再生成
- `prepareStoryboard()` は脚本完成後に通常操作で重複実行しない。
- 脚本画面の「脚本を作り直す（AI利用枠を消費）」→確認ダイアログのみ `recreateStoryboard()` で再生成する。失敗した場合、既存の脚本は維持。
- 完成したオンライン漫画の `generate()` を誤って再実行して全コマ画像生成枠を消費しない。コマ単位の `regeneratePanel` と明示的リセットは従来通り可能。

### C. 脚本と作画へのユーザー指定の伝達
- `MangaStoryBeat.userSceneNoteJP` を新設。ユーザーがカードに書いたメモを、AIが推定した可視行動 `plotDescriptionJP` と別に保持。
- 感情や意図だけのメモを「動いている事実」と誤判定しないため、脚本レビューに原メモとAI推定の出来事を両方表示。
- 手動シーン編集でもメモを維持し、作画時は `USER'S ORIGINAL CARD NOTE (HIGH PRIORITY)` として最初の方のプロンプトへ追加。
- ユーザーが編集した `userVisualDirection` も長いAI提案より前に置く。2400文字のプロンプト制限で手動修正が落ちるリスクを減らす。
- AIの解釈がメモと矛盾するかは自動的に完全判定できないため、脚本レビューで必ず確認する。

### D. テスト追加
- `tests/mangaStoryTests.swift` に「AIの日本語プロットが元メモと異なっても、元メモを別フィールドに保持する」ケースを追加。
- `tests/verify_ui_reference.py` に、原子保存の順序、不要な再課金の防止、明示的な再生成、デッキ更新の順序、手動編集・カード原メモの作画経路を検査するルールを追加。
- GitHub上のコード文字列と呼出し先の静的な接続監査：13/13 PASS（今回の変更箇所）。
- **未実施**：`bash tests/run.sh` のリポジトリ全体実行、Xcode/Codemagicによる最新版iOS実コンパイル、実動画でのCloudflare脚本→FLUX作画、TestFlight実機テスト。静的監査をビルド成功や機能実証と混同しない。

## 次の優先作業
1. GitHubの該当ブランチで、可能なら既存のSwift/Linuxテストを実行。失敗時はソース・テストの不整合を修正。
2. `ios-unsigned-check` を1回実行し、Simulator用全体Swiftコンパイル。失敗なら `ios-diagnostics.txt` のエラー箇所を修正。署名/アップロードはしない。
3. Simulatorコンパイル成功後にのみ、ユーザーが無料ビルド枠を確認して `ios-testflight-upload` を手動実行。
4. 実動画で、複合カード→脚本レビュー→元メモとAI行動の比較→ユーザー修正→FLUX画像→全ページ保存・閲覧の順に品質を評価する。
5. レックスUIは2026-10-31に承認された3画面/アセットを基準に、iPhone画面写真で差分を監査する。

## 完了宣言の制限
上記はソース変更と静的接続確認まで。実機で「高品質な漫画生成が安定した」とは言わない。ビルド枠と本人Cloudflare無料枠を使う前に最小限の検証手順で進める。
