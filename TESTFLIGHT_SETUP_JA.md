# COMIC POP! — WindowsからTestFlightへ進める手順（2026-10-31）

## 現在の確定事項

- `ios-unsigned-check` はCodemagicで成功済み（2026-10-31、Mac mini M2）。SwiftUIアプリ本体はiOS Simulator向けにコンパイル済み。
- Codemagic **Personal Account** の `Quick launch` / App Preview はスクリーンショットの案内どおり使用不可。**Teamを作る必要はありません**。
- `ios-simulator-screenshot` は追加した代替テスト。MacのiPhone Simulatorを起動して静止画 `screenshots/comicpop-launch.png` をArtifactsに保存する。SimulatorがMacに入っていない場合は失敗する可能性がある。**実ビルド未検証**。
- `ios-signed-ipa` はAppleの署名付きIPAを生成するワークフロー。**まだ署名設定を入れていない／実ビルドしていない**。TestFlightへの自動配信はなし。

## A. 無料のままアプリ画面を確認したい場合（任意）

1. Codemagic > Applications > `comic-pop-ios` > Start new build。
2. Branch `main` > Workflow `ios-simulator-screenshot` を選択して実行。
3. 成功したら Artifacts の `comicpop-launch.png` をダウンロード。画像をChatGPTへ送るとレイアウトの検討ができる。
4. 「No iPhone simulator runtime」と表示される場合はスクリーンショット方式を諦め、下記のTestFlightに進む。Teamプランに切り替える必要はない。

※スクリーンショットは画面確認のみ。動画ファイル・個人のCloudflare認証は使用しない。

## B. TestFlightで手持ちのiPhone 12に入れるための設定（本筋）

### 1. Apple Developer でCOMIC POP!のApp IDを作る

https://developer.apple.com/account/resources/identifiers/list

「＋」→ App IDs → App → Continue。Bundle ID を **Explicit** とし、COMIC POP!専用のユニークな識別子（例：`com.yourname.comicpop`）を自分で決める。実際に登録した**文字列を正確に控える**。既存のGRAFFOOTやCSEのBundle IDと重複させない。

### 2. App Store Connectにアプリレコードを作る

https://appstoreconnect.apple.com/apps

「＋」→ New App。Platform=iOS、Name=COMIC POP!（利用不可なら固有の名前に調整）、Primary Language=Japanese、Bundle ID=手順1で作ったもの、SKU=任意のユニークな内部用文字列。Apple Developer Programの登録済みTeamを選ぶ。**App Storeへ公開する操作ではない**。

### 3. Codemagicに署名情報を非公開で設定する

https://codemagic.io/apps

`comic-pop-ios` の Environment variables で次の変数グループを作る。

- `ios_config`: `BUNDLE_ID` に手順1で登録した正確な値（普通の環境変数）
- `appstore_credentials`: 下記を**Secret**にする
  - `APP_STORE_CONNECT_ISSUER_ID`
  - `APP_STORE_CONNECT_KEY_IDENTIFIER`
  - `APP_STORE_CONNECT_PRIVATE_KEY` （Appleの .p8 APIキーの内容）
  - `CERTIFICATE_PRIVATE_KEY` （Apple Distribution証明書に対応するPEM形式の秘密鍵）

Apple APIキーは https://appstoreconnect.apple.com/access/integrations の Users and Access → Integrations → App Store Connect API から発行する。App Managerなどの適切な権限を選ぶ。

**大事な注意：**
- .p8 APIキーとApple Distributionの証明書秘密鍵は**別物**。前者を`CERTIFICATE_PRIVATE_KEY`にコピーしてはいけない。
- 署名済みの既存iOSアプリ（CSE/OHAKO等）の証明書をCodemagicで管理しているなら、**既存のApple Distribution署名を再利用**できる場合がある。その場合はCodemagicのUI「Code signing identities」と `environment.ios_signing` 方式の方が簡単なことがあるが、現行`ios-signed-ipa`は上記の4秘密変数を使う方式なので、同時に混ぜない。
- 秘密鍵・トークン・QRコードをこのチャット、GitHub、画像、ビルドログに貼らない。CodemagicのSecret欄へ直接登録する。
- 新しい秘密鍵発行で既存アプリ用の証明書を**不用意に取り消さない**こと。

Codemagic公式：https://docs.codemagic.io/yaml-code-signing/signing-ios/ と https://docs.codemagic.io/yaml-code-signing/alternative-code-signing-methods/

### 4. Signed IPAビルド

Codemagic > Start new build > Branch=`main`、Workflow=`ios-signed-ipa`。入力変数の事前チェックが通ったら、Codemagicがプロジェクトを生成し、Apple証明書・プロビジョニングプロファイルを取得して署名付きIPAを書き出す。

現在の`codemagic.yaml`に**TestFlightへの自動送信ブロックはない**。まずArtifactsにIPAが生成できたかを確認する。エラー時は失敗したBuild stepとログの該当部分を共有する（秘密値は伏せる）。

### 5. TestFlightへの配信

署名付きIPAが成功したら、App Store ConnectのCodemagic連携**リファレンス名**を確認してから、`publishing.app_store_connect` を設定する。TestFlight内部テストのみであれば `submit_to_testflight: true` を使い、**App Store公開用の `submit_to_app_store: true` は設定しない**。ただしこれはアプリレコードと認証接続が成立してから実装・実行する。

公式：https://docs.codemagic.io/yaml-publishing/app-store-connect/ , https://docs.codemagic.io/yaml-quick-start/first-signed-build/

## 確認の順番

最短ルートは **App ID登録 → App Store Connectのレコード作成 → Codemagic署名設定 → `ios-signed-ipa` → TestFlight配信**。Simulatorスクリーンショットは任意。実機でのみ検証可能な動画読み込み、カード挿入、漫画生成の精度はTestFlight後に確認する。
