# 次の作業：アプリ本体の登録とCodemagic

このリポジトリはPrivateです。README、Codemagic設定、.gitignoreは登録済みですが、**SwiftUIアプリ本体はまだアップロードされていません**。

1. ChatGPTから `COMIC_POP_iOS_v211_GitHub_Ready.zip` をダウンロードして、Windows上の任意のフォルダーにすべて展開してください。
2. 展開したフォルダーの `upload_to_github.ps1` をPowerShellで実行してください。Git for Windowsが必要です。ブラウザでGitHubの認証が要求されたら、`zoukapu-design` のアカウントを選択してください。
3. 実行が終わると、`ios/COMICPOP`、`ios/project.yml`、`tests` 等がmainブランチへ登録されます。
4. Codemagic（https://codemagic.io/apps ）でこのリポジトリを追加し、**ios-unsigned-check** を選択して開始してください。最初は署名なしiOS Simulatorビルドです。
5. もしコンパイルエラーが出たら、Codemagicの`ios-build.log`をこのチャットに添付してください。ソースを修正します。

セキュリティ注意：Cloudflare APIトークン、Apple署名鍵、.envはGitHubに登録しないでください。CodemagicやGitHubの認証はWeb上の公式画面で行ってください。アプリのApple Bundle IDは`com.example.comicpop.dev`という仮値なので、TestFlight署名までに確定が必要です。

このリポジトリでのCloudflare接続はユーザー本人のWorkersアカウントを想定し、**運営者の無料枠への自動切替は行いません**。
