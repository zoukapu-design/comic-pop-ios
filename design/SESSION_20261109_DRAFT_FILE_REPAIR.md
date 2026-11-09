# ムビコマ｜中断生成ファイルの修復・安全な整理（2026-11-09）

作業ブランチ：`feat/movikoma-rex-reference-ui`。前回引継ぎ：`design/SESSION_20261109_DRAFT_RECOVERY_IMPLEMENTATION.md`。

## 発見した実装上の問題

1. `StudioStore.saveDraftCheckpoint()` は、記録済みPNGファイル名が存在するだけで、そのファイルが実際の端末ストレージに残っているか検査していなかった。ファイル欠損時に「保存成功」を返し、次回再起動でコマを復元できない可能性があった。
2. アプリ終了や保存途中の停止で、JSONに参照されない一時画像 `draft-art-*.png` が残り得た。
3. 日本語セリフ・脚本・画質調整・元動画画像への切り替え後に保存失敗しても、編集途中のメモリ上のデータは更新されたままになり、再起動後の状態と食い違う経路があった。

## 実装した修正

- `ios/COMICPOP/MangaDraftFilePolicy.swift` を追加。画像の書込要否は、画像が変更されたか、保存済みファイル名がないか、**該当PNGが実際に存在するか**で決定する。
- 上記ポリシーを `StudioStore.saveDraftCheckpoint()` に組み込み、欠けたPNGはメモリ上の描画から**新しいファイル名へ再保存**してからJSONを原子的に更新する。
- JSON保存成功後のみ、参照中でない `draft-art-*.png` を整理する。通常の作品 `comic-*.png`、元動画、挿入ピン元画像 `pin-*.jpg` は対象外。
- 正しいチェックポイントから再起動復元したときにも、過去のクラッシュで残った未参照PNGを掃除する。
- セリフ・AI脚本編集・画質調整・元画像切替では、チェックポイント保存失敗時に編集前のメモリ状態へ戻す。成功したふりをしない。
- `tests/mangaDraftFilePolicyTests.swift` を追加し `tests/run.sh` に登録。PNGの存在判定、更新判定、不正なパスの拒否、参照中ファイルの保持、保存済み作品とピン画像の保護を検査する。

## 検証結果

- Swift 6.2.1（Linux）：`MangaDraftFilePolicy` の実装に相当するコードを `swiftc` でビルドし、実際の一時ディレクトリに画像ファイルを作成・整理するテストを**PASS**。
- GitHubから変更後のファイルを再取得し、JSON保存順序、画像欠損時の再書込み、ゴミファイル整理、編集失敗時のロールバック、回帰テスト登録を**19項目の静的チェックでPASS**。
- **未実施**：最新リポジトリ全体の `bash tests/run.sh`、Xcode iOSコンパイル、Codemagic `ios-unsigned-check`、iPhone実機での強制終了と再起動、Cloudflare実際の作画。PASSはこれらの成功を意味しない。

## 残る課題と優先順位

1. Codemagicで`feat/movikoma-rex-reference-ui`の`ios-unsigned-check`を1回実行し、`preflight.log`と`ios-diagnostics.txt`を確認する。署名・TestFlightアップロードは検証後。
2. iPhone12のストレージ残量不足に近い状態、アプリ強制終了、1枚だけPNGを欠損させた場合で復元できるか実機確認する。
3. 全ページの作画品質、人物・衣装・線画の一貫性、複合カードの割当、日本語セリフとコマ構成を実動画で評価する。
4. 保存済みコマを再利用する際、Cloudflare無料枠の使用数が二重になっていないか実際の利用履歴で照合する。
