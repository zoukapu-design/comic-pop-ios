# ムビコマ｜iOSビルド直前ゲート（2026-11-09）

## ソースと引き継ぎ
- リポジトリ：`zoukapu-design/comic-pop-ios`
- 作業ブランチ：`feat/movikoma-rex-reference-ui`（PR #1、mainとは分離）
- 今回の修正：未保存の漫画または脚本があるとき、画風／カラー変更による自動破棄を禁止。`MangaAppearanceChangePolicy` が変更なし・即適用・確認待ち・生成中禁止を区別。SwiftUIの確認後にのみ `discardGenerated()` と新設定の適用を実施。

## 実行済みの検証
- Linux Swift 6.2.1：`MangaAppearanceChangePolicy.swift` + `tests/mangaAppearanceChangePolicyTests.swift` を `swiftc` コンパイル、6ケースPASS。
- GitHubから最新の該当ソースを再取得し、ガード・確認・テスト登録・ログ設定の接続を12項目静的確認し、すべてPASS。
- `tests/run.sh` に今回のSwiftテストを追加。
- **未実行**：最新ブランチの`bash tests/run.sh`全体、iOS/macOS Xcodeコンパイル、Codemagicビルド、TestFlight、実AI生成。これらについて成功を主張しない。

## ビルド失敗時にログを失わないための改良
`codemagic.yaml` の `ios-unsigned-check` に以下の成果物を設定：
- `preflight.log`：Linux互換Swiftテスト／事前検査。失敗時もArtifactsに残す。
- `xcodegen.log`：XcodeGenの実行ログ。ここまで到達した場合に残す。
- `ios-build.log`：Xcode Simulatorコンパイルログ。
- `ios-diagnostics.txt`：Swiftエラー・警告の抽出（コンパイル段階まで進んだ場合）。

## 次に必要な操作：Codemagicで**一度だけ**署名なし検証
1. Codemagicでムビコマのアプリを選択し、新規ビルドを開始。
2. ブランチ：`feat/movikoma-rex-reference-ui`（`main`ではない）。
3. Workflow：`ios-unsigned-check` を選択。署名済みの `ios-testflight-upload` を選ばない。
4. 完了後、成功/失敗とArtifactsの `preflight.log`／`xcodegen.log`／`ios-diagnostics.txt` を確認。
5. 失敗した場合、最後に実行されたステップとログを材料にSwift/iOSの実エラーを修正。成功した場合、次工程としてTestFlightの署名ビルドを検討する。

## 品質ゲート
成功したSimulatorコンパイルだけで「完成」としない。iPhone 12で参照レックスUI／挿入カード／コマ編集／漫画保存を確認し、実動画からの脚本因果・複合演出・日本語・人物一貫性・全ページを評価する。

※GitHub Actionsの以前のfailureはstepsなし、ログなしでありSwiftのコンパイル失敗とは断定できない。
