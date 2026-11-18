import SwiftUI

/// Presented once, immediately after the Rex welcome, for users who do not
/// already have a saved Cloudflare credential pair. Offline mode is optional
/// and never requires a Cloudflare account.
struct PopCloudflareOnboarding: View {
    @ObservedObject var store: StudioStore
    let finish: () -> Void

    @State private var account = ""
    @State private var token = ""
    @State private var isConnecting = false
    @State private var didAttempt = false

    private var selectedAccountID:String {
        CloudflareSetupPolicy.resolvedAccountID(entered:account,saved:store.cloudflareAccount)
    }
    private var canConnect: Bool {
        !isConnecting && CloudflareSetupPolicy.isValidAccountID(selectedAccountID) &&
        store.confirmsFree &&
        (store.tokenExists || !token.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators:false) {
                VStack(spacing:16) {
                    ZStack(alignment:.bottomLeading) {
                        PopArtwork(kind:.hero)
                            .frame(height:145)
                            .clipShape(RoundedRectangle(cornerRadius:22))
                        LinearGradient(colors:[.clear,PopColor.navy.opacity(0.82)],
                                       startPoint:.center,endPoint:.bottom)
                            .clipShape(RoundedRectangle(cornerRadius:22))
                        Text("最初の1回だけ\nAIをつなごう！")
                            .font(.system(size:23,weight:.black,design:.rounded))
                            .foregroundStyle(.white)
                            .padding(15)
                    }
                    .overlay(RoundedRectangle(cornerRadius:22).stroke(PopColor.edge,lineWidth:2))

                    PopSurface(accent:true) {
                        VStack(alignment:.leading,spacing:13) {
                            Label("AI漫画化の初期設定",systemImage:"sparkles")
                                .font(.system(size:19,weight:.black,design:.rounded))
                            Text("Cloudflareのアカウントを一度だけ接続します。次回からはこのiPhoneの保存情報を自動で使い、トークンを再入力しません。")
                                .font(.system(size:12,weight:.medium))
                            if store.tokenExists {
                                Label("APIトークンは保存済みです。Account IDだけ確認してください。",
                                      systemImage:"lock.shield.fill")
                                    .font(.system(size:12,weight:.bold))
                                    .foregroundStyle(PopColor.royal)
                            }
                            VStack(alignment:.leading,spacing:6) {
                                Text("Cloudflare Account ID")
                                    .font(.system(size:12,weight:.heavy))
                                TextField("CloudflareのAccount ID",text:$account)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .textFieldStyle(.roundedBorder)
                                    .accessibilityIdentifier("cloudflare.setup.account")
                            }
                            if !store.tokenExists {
                                VStack(alignment:.leading,spacing:6) {
                                    Text("Workers AI API Token")
                                        .font(.system(size:12,weight:.heavy))
                                    SecureField("初回のみ入力",text:$token)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .textFieldStyle(.roundedBorder)
                                        .accessibilityIdentifier("cloudflare.setup.token")
                                    Link("CloudflareでAPIトークンを管理",
                                         destination:URL(string:"https://dash.cloudflare.com/profile/api-tokens")!)
                                        .font(.system(size:12,weight:.bold))
                                }
                            }
                            Toggle("Workers Free契約を確認しました",isOn:$store.confirmsFree)
                                .font(.system(size:12,weight:.semibold))
                                .tint(PopColor.blue)
                            if let hint=CloudflareSetupPolicy.connectionHint(
                                accountID:selectedAccountID,confirmedFree:store.confirmsFree
                            ) {
                                Text(hint)
                                    .font(.system(size:11,weight:.semibold))
                                    .foregroundStyle(PopColor.royal)
                            }
                            Text("契約の種類はアプリから確認できません。Workers Paid契約ではCloudflare側の課金が発生する場合があります。")
                                .font(.system(size:10,weight:.medium))
                            PopYellowButton(
                                title:isConnecting ? "安全に接続中…" :
                                      (store.tokenExists ? "保存済み情報で始める" : "接続してAI漫画を始める"),
                                icon:"checkmark.shield.fill",
                                enabled:canConnect
                            ) {
                                isConnecting=true
                                didAttempt=false
                                Task {
                                    let success:Bool
                                    if store.tokenExists {
                                        success=await store.reconnectSavedCloudflare(account:selectedAccountID)
                                    } else {
                                        success=await store.connect(account:selectedAccountID,token:token)
                                    }
                                    if success {
                                        token=""
                                        finish()
                                    } else {
                                        didAttempt=true
                                    }
                                    isConnecting=false
                                }
                            }
                            if didAttempt {
                                Label(store.message,systemImage:"exclamationmark.circle.fill")
                                    .font(.system(size:11,weight:.semibold))
                                    .foregroundStyle(.red)
                            }
                        }
                        .foregroundStyle(PopColor.ink)
                        .frame(maxWidth:.infinity,alignment:.leading)
                    }
                    PopSurface {
                        VStack(alignment:.leading,spacing:10) {
                            Label("AIなしでも漫画づくりを試せます",
                                  systemImage:"iphone.gen3")
                                .font(.system(size:14,weight:.black,design:.rounded))
                            Text("後からAIを設定できます。まずは動画やカードを試すだけなら、Cloudflareアカウントは不要です。")
                                .font(.system(size:11,weight:.medium))
                            Button("今は端末内のおためしで始める") {
                                finish()
                            }
                            .font(.system(size:13,weight:.black,design:.rounded))
                            .foregroundStyle(PopColor.royal)
                            .frame(maxWidth:.infinity)
                            .padding(.vertical,10)
                            .background(.white,in:Capsule())
                            .overlay(Capsule().stroke(PopColor.edge,lineWidth:2))
                            .buttonStyle(.plain)
                        }
                        .foregroundStyle(PopColor.ink)
                        .frame(maxWidth:.infinity,alignment:.leading)
                    }
                    Text("登録したトークンはiPhoneのKeychainに保存され、アプリ内で表示・再入力する必要はありません。")
                        .font(.system(size:10,weight:.medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(15)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PopBackground())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.principal) {
                    Text("ムビコマ 初回設定")
                        .font(.system(size:15,weight:.black,design:.rounded))
                }
            }
        }
        .onAppear {account=store.cloudflareAccount}
    }
}
