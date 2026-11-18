# ムビコマ｜カード編集時の生成結果保護・ホーム復帰導線（2026-11-10）

## 作業対象
- リポジトリ: `zoukapu-design/comic-pop-ios`
- ブランチ: `feat/movikoma-rex-reference-ui`（PR #1）
- 前回引継ぎ: `design/SESSION_20261109_DRAFT_FILE_REPAIR.md`

## 実際に発見した欠陥
前回まで画風・カラー変更は確認式だったが、動画編集画面からのカード追加、カードの物語メモ変更、1枚削除、全削除では、`clearGenerated()` が生成画像・AI脚本を消すにもかかわらず確認がなかった。保存済み作品は残るものの、途中までCloudflare無料枠で生成した絵は失われる恐れがあった。

## GitHubへ反映した実装修正
1. `StudioStore.swift` の `replaceVideo`, `addPin`, `updatePinStory`, `removePin`, `clearPins` に `allowDiscard:Bool = false` を導入。確認されていない既存ドラフトへの破壊的変更は、Storeレイヤーでも拒否。
2. `MangaDraftEditGuard.swift` はFoundationのみの純粋な認可ルール。直接のStore呼び出しもユーザー確認を要求する。保存後の `clearGenerated()` 順序は維持し、JSON保存失敗時は既存漫画を残す。
3. `PopEditor.swift` は、カードをタップして挿入／＋挿入／1枚削除／タイムラインから削除／全削除を、確認式ルートへ統合。今の漫画・AI脚本を破棄する場合、確認後の操作でだけ `allowDiscard:true` を渡す。
4. `PopStoryEditing.swift` は、メモ・セリフが実際に変更されたときだけ確認式。メモの変更なしは既存生成結果を維持。端末のJSON保存が失敗したらシートを閉じず、再試行できる。
5. `PopJourney.swift` は、写真／ファイルからの動画変更確認後のみ、`replaceVideo(...,allowDiscard:true)` を渡す。通常のインポートは安全側のfalse。
6. `StudioStore.addPin` は、画像を非同期抽出している間にピン、動画、脚本、画像が更新された場合を識別するため、`draftRevision` も撮影開始時に記録し、ズレがあれば古い結果を挿さない。
7. `PopHomeScreen` に「作りかけの漫画が残っています」バナーと「マンガ作成の続きを開く」を追加。完成済みならレビュー画面、途中なら画風・生成の画面へ戻る。復元JSONが欠けているときに「保存済み」と誤表示しない。
8. すでに作品一覧へ保存済みの漫画を消すと誤解されないように、「未保存の漫画」ではなく「現在の生成結果」という文言へ統一。

## 検証
- `tests/mangaDraftEditGuardTests.swift` を追加、`tests/run.sh` に組込。
- 作業環境の **Swift 6.2.1（Linux）** で、GitHub反映内容と同じ純粋な編集認可ルールと8ケースのSwiftテストを手元でコンパイル・実行。結果: `PASS: 8 manga draft editing authorization scenarios`。
- GitHubから最新変更を再取得し、Store・SwiftUI・動画選択・ホーム復帰・回帰テストの**31項目を静的に照合し、31/31 PASS**。
- `tests/verify_ui_reference.py` と `tests/verify_sources.py` の旧関数シグネチャ依存を更新し、新しい認可・動画更新・遅延フレーム破棄を監査。
- **未実施**: `tests/run.sh`全体、iOSアプリ全ソースのXcodeコンパイル、Codemagic `ios-unsigned-check`、iPhoneでの操作確認、Cloudflare実際の作画品質評価。上記PASSをこれらの成功として扱わない。

## CI状況
GitHub Actions最新の `Movikoma Swift source preflight` は失敗（run `42682095248`）。ジョブは **steps=[]** と報告され、Swiftが実行された証拠がない。失敗理由は現時点で未確定。

## 署名なしiOSビルド前の受け入れ操作
- Cloudflare脚本確認後、カードを追加・削除・全削除・メモ変更しようとすると、明示的な破棄確認が出る。
- キャンセルするとカード・脚本・絵は維持される。
- 承諾しても、動画フレーム取得やJSON保存に失敗すれば旧画像を維持する。
- 元動画の変更では、確認を出し、作成済みの作品とマイデッキは保持。
- アプリ再起動後、ホームのバナーから「続きの作画」へ直接進める。
- フレーム取得中に別のAI脚本が完成しても、古いカード追加によってその脚本を消さない。
- Codemagicの `feat/movikoma-rex-reference-ui` / `ios-unsigned-check` で実iOSコンパイルを成功させてからTestFlightを行う。無料ビルド枠とCloudflare無料枠を節約する。

## 次の重点
iOSコンパイル診断の確保、動画フレーム／カード／脚本／漫画の実機E2Eテスト、レックスの参照UI忠実性、AI漫画の構図・物語の因果・人物一貫性・日本語セリフ品質評価。
