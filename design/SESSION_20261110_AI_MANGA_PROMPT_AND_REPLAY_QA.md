# ムビコマ｜AI漫画の作画指示優先化・シーン全体の重複監査（2026-11-10）

## 正本
- GitHub: `zoukapu-design/comic-pop-ios`
- 作業ブランチ: `feat/movikoma-rex-reference-ui`（PR #1）
- 直前引継ぎ: `design/SESSION_20261110_EDITOR_DRAFT_CONSENT.md`

## 今回の品質課題

1. 従来の `CloudflareAIService.redraw` は、非常に長い作画プロンプトを最後に `String(prompt.prefix(2400))` で一律切断していた。ユーザーの手動構図・原文メモは一部優先化済みだったが、**同時刻に挿した複数カードの統合指示、コマ間の因果や画像参照が末尾で消える**可能性が残っていた。
2. `MangaStoryQualityAudit` は隣接コマの重複を判定していたが、1→4コマ目のような**遠い位置でのシーン再利用**を作画前には検出していなかった。
3. 意図的な `flashback`／`replay`／`beforeafter` カードがあっても、`MangaStoryPlanner.decodeAIStory` が直前と同じ構図を拒否しており、回想の脚本自体を不適切に破棄する可能性があった。画面・画像検査・脚本デコードで判断基準を共有していなかった。

## GitHubへ反映した内容

- **`MangaDrawingPrompt.swift` 新規**：2,400文字上限を遵守する優先順位つきプロンプト生成。物語の出来事、元カードメモ、ユーザー手動の構図、全同時カードID、カード統合演出、具体的な絵の指示、前コマとの因果、前後・開始コマの画像参照を先に入れる。章説明・長い補助指示は余白にのみ入れる。「画像AIは文字・漢字・吹き出しを描かない」ルールを末尾に常に確保し、後からUIKitで日本語を組版する。
- **`VideoAndAI.swift`**：`CloudflareAIService.redraw` を上記生成器に接続。一律 `prefix(2400)` の切り落としを廃止。動画からの現在コマ、直前の描画画像、最初の描画画像の参照意図は維持。
- **`tests/mangaDrawingPromptTests.swift` 新規**：カードIDの長いもの12枚が**同じ一場面**で統合された状態を構成し、長文の原文メモ・構図・脚本を与える厳しい条件で、ID・優先指示・因果・画像参照・文字禁止命令が残ることを確認。短文では補助指示も残ることを確認。
- **`MangaStoryQualityAudit.swift`**：以前の全シーンと比べ、*出来事と構図の両方*が同一・極似の場合のみ、過去シーン番号つきで注意を出す。単なる同じ舞台・服装だけでは警告しない。`isIntentionalReplay` を追加し、回想は隣接／遠方どちらの比較でも誤警告しない。
- **`MangaStory.swift`**：`MangaReplayIntent.isIntentional` を共通関数として追加。`decodeAIStory` も「ユーザーが回想カードを明示した」場合の合法的な重複構図を保持。
- **`PopStoryboardDraft.swift`／`StudioStore.swift`**：脚本プレビュー警告、生成画像重複警告、保存前重複検査を同一リプレイ判断に統一。
- **`tests/mangaStoryQualityAuditTests.swift`、`tests/mangaStoryTests.swift`**：遠いコマの無意識な重複、直前／遠い位置の意図的な回想、別の動作があるコマの誤警告防止、AI脚本での回想の許容を回帰検査。
- `tests/run.sh` と `tests/verify_ui_reference.py` を更新して事前検査を登録。

## 実行済みの検証（誤認防止）

- この環境の Linux Swift 6.2.1 で、**GitHubの `MangaDrawingPrompt.swift` と同内容のソース**をコンパイルし、`mangaDrawingPromptTests.swift` と同内容のテストを実行：**PASS**。
- 最長カードID群12枚を1シーンにまとめ、手動の重要指示や補助文も飽和させたケースの**実出力は2,352文字**。カードID12個と手動・原文指示・因果・画像参照・日本語のアプリ組版ルールが保持されることを確認。
- `MangaStoryQualityAudit.swift` と同内容のソースを Linux Swift 6.2.1 でコンパイルし、非隣接コマ重複と意図的回想のスモーク試験を実行：**PASS**。
- 変更したGitHubソースを11ファイル再取得して結線と保護条件を**25項目の静的照合でPASS**。
- **未実施**：GitHub全体の `bash tests/run.sh`、最新Xcode/iOS Simulator全体コンパイル、iPhone 12実機確認、Cloudflare FLUXの実生成品質検証、画風・人物一致の定量評価。構文テストとプロンプト試験は実画像の品質を保証しない。

## 次の受け入れ条件

1. Codemagicで `feat/movikoma-rex-reference-ui` / `ios-unsigned-check` のXcodeコンパイルとソース全検証を実施。失敗したら `preflight.log` / `xcodegen.log` / `ios-diagnostics.txt` を解析。
2. 2〜12枚のカードを挿した実動画で、カード統合・脚本の自然さ・全ページの絵柄と登場人物の一致・セリフの日本語を確認。
3. 無料AI生成の途中復元を確認し、ユーザーのCloudflare利用量と照合。画像の再作成を自動で追加課金しない。
4. `flashback` / `replay` / `beforeafter` の作画指示が意図どおり回想になるか、実生成でも人間がレビュー。
5. 参考画像どおりのレックス素材を使うネイティブUIの一貫性、iPhone 12での操作性・速度・保存を検証。

ユーザーの既存動画、デッキ、保存済み作品は本変更では削除しない。無料GPU/API限定という要求を守る。署名ビルド・TestFlight・Cloudflareの画像生成は今回実行していない。
