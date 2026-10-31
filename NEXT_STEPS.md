# COMIC POP! iOS v2.1 — Windows → GitHub → Codemagic

2026-10-31。開発者のCloudflare無料枠へフォールバックしない独立したiOSソースです。

## 1. GitHubの新しい非公開リポジトリ（まだ作成されていません）

- GitHubの「New repository」で `comic-pop-ios` のような名前を付け、Visibility = **Private** に設定します。
- README / gitignore は初期化時に追加しないでください（このZIPに含まれています）。
- ZIPを解凍し、`codemagic.yaml`, `ios/`, `tests/`, `README.md` など **全ファイルをリポジトリのルート**にアップロードします（ZIPファイルそのものを1つだけアップロードしない）。
- 複数の別アプリのリポジトリやソースは変更しません。

WindowsでGitが使用できる場合（リポジトリ名は自分で作成したものに置換）：

```powershell
git init
git add .
git commit -m "COMIC POP iOS native v2.1 preflight"
git branch -M main
git remote add origin https://github.com/<OWNER>/comic-pop-ios.git
git push -u origin main
```

## 2. Codemagicの最初のコンパイル検査

- CodemagicでGitHubを接続し、上記の**専用リポジトリ**をImport。
- `codemagic.yaml` から `ios-unsigned-check` を選択。
- このワークフローはSwiftモデルテストを実行し、XcodeGenでXcodeプロジェクトを生成し、**署名なしのiOS Simulatorビルド**を行います。
- Buildを押すとCodemagicの利用枠を消費します。無料枠を確認してから実行してください。
- 成功：`COMICPOP.app` がアーティファクトに追加されます。これは**iPhone実機に直接インストールできる署名付きIPAではありません**。
- 失敗：`ios-build.log` をダウンロードし、最初に出ている `error:` 行から原因を調べてください。

## 3. TestFlight配信は署名なしコンパイル成功後

- `ios/project.yml` の仮Bundle ID `com.example.comicpop.dev` を実際の固有IDに変更。
- Apple Developer Program / App Store Connectで対象アプリを登録し、Codemagicへ署名設定・配信権限を安全に接続。
- 署名済みIPAをビルドし、TestFlightでiPhone実機検証。**このZIPに自動配信処理は入れていません**。

## 動作確認ポイント

1. 動画を読み込んで3枚のカードを刺す。
2. 動画を切り替え、旧動画のカードが0になりマイデッキは保持されることを確認。
3. 古い動画のフレーム抽出の完了と動画切替が競合しても、旧カードが復活しないことを確認。
4. 5枚のカード → 5コマ → 2ページとなることを確認。
5. 個人のWorkers FreeのCloudflareトークンを使い、1コマだけ作画テスト。
6. 元の場面と出力画像を比較し、別場面が繰り返されていないか確認。

## 費用・保護

- APIトークンをGitHubやチャットに貼り付けないでください。iOSではKeychainに保存します。
- Cloudflare Workers Free契約での利用を想定。契約種別のAPI検証は未実装です。**Workers Paid契約ではCloudflare側の課金が発生する可能性があります**。
- Codemagicのビルドも無料利用枠を超えると別途費用が発生する場合があります。実行前にアカウントの使用量と契約状況を確認してください。
- アプリは現在広告SDKを組み込んでいません。App Store配信・有料サービスへの自動切替は行いません。
