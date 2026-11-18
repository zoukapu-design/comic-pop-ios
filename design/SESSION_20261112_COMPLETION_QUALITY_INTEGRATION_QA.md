# ムビコマ｜完成品質集中改修・統合QAゲート（2026-11-12）

## 結論
起動中のSwiftUIホーム、カード合成制限、複合カードメモのAI作画伝達、実機QAの撮影導線に**実コードの大幅な修正**を反映した。

ただし、以下は事実として区別する。
- **コード更新：GitHub作業ブランチに反映済み**
- **静的整合性確認：主要21条件すべて一致、`tests/verify_ui_reference.py` の単純な文字列検査に相当する297件の参照照合で不一致0**
- **独立ローカルSwift検証：Swift 6.2.1でシーン数／同時カード数および長い作画メモの2ハーネスPASS**
- **全ソースの`bash tests/run.sh`・Xcode/SwiftUI型検査・Codemagic実機ビルド：未実行**
- **承認済みUIとの実機スクリーンショット比較・FLUX作画品質評価：未完了**

## 原因分析：改善が見えなかったUI
`ios/COMICPOP/COMICPOPApp.swift` の起動ルートは `MovikomaPopRootView`（`PopApp.swift`）であり、`MovikomaUI.swift` の `MovikomaRootView` や`StudioUI.swift`の `StudioRootView` ではない。実際に表示されない画面の修正では改善を確認できない。

今回は唯一の起動ルート `MovikomaPopRootView -> PopHomeScreen/PopVideoChooseScreen/PopEditorScreen/PopGenreScreen/PopReviewScreen` を変更対象とした。未使用UIはこの段階では削除していない（`MVSprite`など共有アセット依存があるため）。

## 実装済みの大幅改修
### 1. 起動ホーム再構成
- `PopJourney.swift` の本番 `PopHomeScreen` を大幅に再構築。
- 承認済みレックスのイラスト／コミックカード画像を利用したヒーロー領域、明確な「新しい動画で漫画を作る」ボタン、前回動画の編集再開、未完成/完成漫画への復帰を実装。
- 保存済みマンガの実際のページを表紙として横スクロール表示。マイデッキ・作品一覧・AI設定・3工程を独立した押せる領域に配置。画面全体を静的イメージにはしていない。
- `ImageIO` の`CGImageSourceCreateThumbnailAtIndex`で実際の作品PNGを360pxに縮小・`NSCache`キャッシュ。iPhone 12でホームを開くだけで複数の高解像度ページを大量にデコードする状態を避ける。

### 2. 画面の操作／表示
- `PopTheme.swift` `PopStepNavigation` でページ未生成時に空のレビュー画面への遷移を無効化。
- `PopApp.swift` から完了画像の有無に基づいてレビュー移動可否を渡す。リセット後にレビューへ残らない保護も追加。
- ヘッダーの紛らわしい「書き出し」は、実処理に合わせ「作品に保存」と表記変更。
- 12枚上限という古いヘルプ記述を、実際の12シーン/カード合成仕様に修正。

### 3. カード枚数と漫画シーン数を統一
- 新規 `MangaSceneCapacity.swift`：描画するのは最大12シーン。同じ動画場面は感情・指示カードを最大3枚まで合成。理論上の最大36カード。
- `StudioStore.addPin` はフレームを抽出する前と完了直後に制限を再判定し、上限超過なら端末へのピン画像書込みをしない。
- `PopEditor.swift` の挿入可否／エラー文言も共通ルールへ更新。カード数と実シーン数を別表示。
- `tests/modelTests.swift` に12独立場面・13場面拒否・既存場面への追加・同一場面4枚目拒否・36カード総数・NaN時刻の回帰テストを追加。
- `tests/run.sh` のSwift Foundationモデルコンパイル対象に新ファイルを追加。

### 4. 複合カードの長いメモを作画に反映
- 1つの場面に3枚のカードを加えると、各260文字のメモが従来の160文字切詰めで失われる問題を解消。
- `MangaStory.swift` で元メモを最大800文字まで保持し、AIへ渡す構造化シーン証拠にも反映。
- `VideoAndAI.swift` でも元メモ最大800文字を作画プロンプトへ転送。
- `MangaDrawingPrompt.swift` は複数メモが長い場合に補助指示と構図指定の割当を圧縮し、元メモ・カードID・手動作画指示を優先。2400文字上限とAI文字入れ禁止命令を維持。
- `tests/mangaDrawingPromptTests.swift` に3枚の長文メモが丸ごと残る回帰テスト追加。
- `tests/verify_ui_reference.py` の旧画面ラベル・旧160文字判定・古い脚本検査条件を同期。

### 5. 一発ビルドで見るべき画面を撮る
- `codemagic.yaml` `ios-simulator-screenshot` の撮影を、初回案内`movikoma-welcome.png`と実ホーム`movikoma-home.png`の2枚に変更。後者は起動引数`-pop.didSeeWelcome YES`で初回案内だけをスキップ。
- シミュレーター画像・署名不要のビルドは従来どおり手動。無料枠とユーザーの利用判断を勝手に変更しない。
- `tests/verify_ui_reference.py` に両画像の取得設定・本番ルートの結線を検査する項目を追加。

## QA結果・再現手順
- GitHubから改修対象15ファイルを再取得し、実画面ルート・動画選択・カード挿入・12/3制限・脚本/作画プロンプト・Codemagic設定を比較して21/21条件PASS。
- さらにGitHubの`tests/verify_ui_reference.py`で参照される多数のソースを実際に再取得し、単純な`assert "..." in source`形式の静的条件297件を照合、0件不一致（**Pythonテスト自体を実行したという意味ではない**）。
- ローカルSwift 6.2.1の独立実装ハーネス：
  - 12場面への既存場面カード追加=可、13場面追加=拒否、同じ場面の4枚目=拒否、36カード超=拒否、非有限時刻=拒否：PASS。
  - 3枚の260文字メモ、全3カードID、画像参照指定、日本語文字の画像AI禁止を2400文字に収める構成：PASS（実測2275文字）。
- **現状の外部障害**：GitHub Actions run `43093699543` は`runner_id:0`・`steps:[]`でfailure。Swiftテスト開始前に終了している。Actionsアカウント、ランナー、支払/利用枠設定の確認が必要だが、根本原因は未確定。
- ユーザー指定のCodemagic/Cloudflare無料枠は今回一切消費していない。

## 正式な完成判定までの残項目
1. GitHub Actions環境を正常化し`bash tests/run.sh`の全文PASSを採取。
2. Codemagic `ios-unsigned-check`でSwiftUIとUIKitを含めたコンパイルを1回実施。エラー行は`ios-diagnostics.txt`から修正。
3. `ios-simulator-screenshot`で`movikoma-welcome.png`と`movikoma-home.png`を取得し、ユーザー承認のレックス画面と実スクリーンショットを並べて評価。カード、字幕、端末幅、タップ範囲を検証。
4. 同じ時間の3カードから1コマが生成されるか、分離5シーンが2ページになるか、全部のメモが残り、古いカードが混ざらないかを実動画で検証。
5. Cloudflareの実アカウント・無料枠を確認後に、画像理解AI→脚本確認→FLUX再描画の品質を実際に比較。モデルの画質は未測定で、人物・服・背景の一貫性は未保証。
6. 端末で中断／復元／画像再生成／作品保存／PDF書出しを試し、最後に署名/TestFlightへ進む。

未確認事項が残るため、本改修を**完成版リリースや実機QA完了と呼ばない**。実装済みの改善だけが実証済み。
