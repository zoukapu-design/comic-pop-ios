# COMIC POP! — TestFlight署名設定（2026-10-31 更新）

## 2026-10-31: COMIC POP! の署名準備完了（登録画面で確認）

- **Bundle ID**: `com.zoukapu.comicpop`
- **Apple Distribution証明書のCodemagic参照名**: `Cybernetic_Distribution`（既存のものを共用、削除しない）
- **App Storeプロファイル参照名**: `comicpop_appstore_profile`（Codemagic一覧に表示、Certificateは緑チェック）
- GitHubの `codemagic.yaml` の `ios-signed-ipa` にBundle IDを直接設定済み。**`ios_config` や `BUNDLE_ID` 環境変数を手動追加する必要はない**。
- 次は Codemagic → `comic-pop-ios` → Start new build → `main` → `ios-signed-ipa` → Start new build。
- このワークフローは署名付きIPA生成のみ。**TestFlight自動アップロード・App Store公開は行わない**。


## 2026-10-31: 既存証明書の再利用（確認済み）

Codemagic Personal AccountのiOS certificatesに **Cybernetic_Distribution**（production、有効期限2027-10-29）が登録済み。これをCOMIC POP!でも再利用するため、`codemagic.yaml`の`ios_signing.certificates`を`Cybernetic_Distribution`へ修正済み。**Generate certificateやFetch certificateを押さない。既存証明書を削除・失効させない。**

次はApple DeveloperでCOMIC POP!用App Store Connectプロビジョニングプロファイルを作る。証明書はApple Developer側で同じTeam・同じ有効期限のApple Distributionを選択。作った`.mobileprovision`をCodemagicの`iOS provisioning profiles`へアップロードし、Reference name=`comicpop_appstore_profile`とする。既存のCSE用プロファイルは使い回さない。


## 確認済み
- Codemagic `ios-unsigned-check` はSimulatorコンパイルに成功。
- Apple DeveloperでApp ID、App Store Connectでアプリ登録は利用者が完了。
- `ios-signed-ipa` は **Codemagic管理型の証明書/プロファイル**を参照する方式に変更済み。以前の4つの秘密変数方式は使用しない。
- TestFlightへの自動送信は意図的に無効。

## 手順1. App Store Connect APIキーを接続
1. https://appstoreconnect.apple.com/access/integrations → Users and Access > Integrations > App Store Connect API。
2. 専用APIキーを発行。名称例 `Codemagic COMIC POP`、ロール `App Manager`。
3. Issuer ID / Key ID / .p8を保存。**.p8は秘密。GitHub・チャットに送らない。**
4. https://codemagic.io/ で **Personal Account の設定** > Integrations > Developer Portal > Add key。
5. 参照名 `comicpop-apple`、Issuer ID、Key ID、.p8ファイルを入力して保存。

## 手順2. 署名用証明書
Codemagicの **Personal Account settings > codemagic.yaml settings > Code signing identities > iOS certificates** に進む。
- **Apple Distribution** 証明書がすでに登録され利用可能なら再利用を優先。他アプリの証明書を取り消さない。
- 必要ならAPIキーを使って `Generate certificate` → Type `Apple Distribution` を選ぶ。AppleはDistribution証明書を最大3枚に制限するため、不要に増やさない。
- 生成後の証明書を保存し、必要に応じてUIの `Upload certificate` に追加する。
- 今回のGitHub YAMLが参照する **Reference name** は必ず `Cybernetic_Distribution` にする。

## 手順3. App Storeプロビジョニングプロファイル
- Apple Developer > Profiles にCOMIC POP!専用の **App Store Connect用配布プロファイル**を作成。Step1で作った正確なBundle IDを選び、Step2と一致するDistribution証明書を指定する。
- CodemagicのCode signing identities > **iOS provisioning profiles** で `Fetch profiles`。一覧にないときは `.mobileprovision` を直接アップロード。
- 対象のプロファイルの **Reference name** を `comicpop_appstore_profile` とする。証明書が対応していることを確認。

## 手順4. Codemagic環境変数
- app `comic-pop-ios` > Environment variables でグループ `ios_config` を作成。
- 変数 `BUNDLE_ID` を作り、Apple Developerで登録した正確なBundle IDを設定（例は `com.zoukapu.comicpop` だが、実際の登録値を優先）。
- **`appstore_credentials` / `CERTIFICATE_PRIVATE_KEY` / `APP_STORE_CONNECT_PRIVATE_KEY` の環境変数は今のワークフローでは不要**。

## 手順5. 署名付きIPAを作る
Codemagic > `comic-pop-ios` > Start new build → main → `ios-signed-ipa`。
ArtifactsにIPAが出ることを確認。まだTestFlightには送信されない。
失敗ログは該当するエラー行を共有（証明書/秘密鍵/IDは伏せる）。

## 手順6. TestFlight配信
署名付きIPAが成功してから、CodemagicのApple Developer Portal連携名とApp Store Connect Publishing設定を有効にする。まず内部テスターとしてiPhoneにインストールする。App Storeへの一般公開はまだ行わない。

公式資料:
- https://docs.codemagic.io/yaml-code-signing/signing-ios/
- https://docs.codemagic.io/yaml-publishing/app-store-connect/
