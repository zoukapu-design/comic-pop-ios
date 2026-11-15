import SwiftUI

/// Fully functional settings screen using the same glossy Rex/blue/yellow
/// design as the editor and genre picker, instead of a default grey Form.
struct PopSettingsPanel: View {
    @ObservedObject var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var account = ""
    @State private var token = ""
    @State private var isConnecting = false
    @State private var editingCredentials = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators:false) {
                VStack(alignment:.leading,spacing:13) {
                    PopBlueTitle(icon:"gearshape.fill",title:"設定")
                    PopSurface {
                        VStack(alignment:.leading,spacing:10) {
                            Label("漫画の基本設定",systemImage:"paintbrush.fill")
                                .font(.system(size:16,weight:.black,design:.rounded))
                            Text("次に作る漫画の画風と色を変更できます。生成済みの漫画は、保存してから変更してください。")
                                .font(.system(size:11,weight:.medium))
                            Picker("画風",selection:Binding(
                                get:{store.data.style},
                                set:{store.updateStyle($0)}
                            )) {
                                ForEach(MangaStyles.all,id:\.id) { style in
                                    Text(style.title).tag(style.id)
                                }
                            }
                            .pickerStyle(.menu)
                            HStack(spacing:7) {
                                PopPill(text:"白黒",icon:"circle.lefthalf.filled",
                                        selected:store.data.colorMode == "mono") {
                                    store.updateColor("mono")
                                }
                                PopPill(text:"カラー",icon:"paintpalette.fill",
                                        selected:store.data.colorMode == "color") {
                                    store.updateColor("color")
                                }
                            }
                        }
                        .foregroundStyle(PopColor.ink)
                        .frame(maxWidth:.infinity,alignment:.leading)
                    }
                    PopSurface {
                        VStack(alignment:.leading,spacing:9) {
                            Label("無料おためし漫画化",systemImage:"iphone.gen3")
                                .font(.system(size:16,weight:.black,design:.rounded))
                            Text("端末内で動画の実フレームを漫画調に加工します。API接続や画像のアップロードは不要です。")
                                .font(.system(size:12,weight:.medium))
                            Label("無料で試せます（生成AIではありません）",
                                  systemImage:"checkmark.circle.fill")
                                .font(.system(size:11,weight:.heavy))
                                .foregroundStyle(PopColor.royal)
                        }
                        .foregroundStyle(PopColor.ink)
                    }
                    PopSurface {
                        VStack(alignment:.leading,spacing:11) {
                            Label("AI漫画化（Cloudflare）",systemImage:"sparkles")
                                .font(.system(size:16,weight:.black,design:.rounded))
                            Text("AIで描き直す場合だけ、あなた自身のCloudflareアカウントを接続します。トークンはiPhoneのKeychainに保存されます。")
                                .font(.system(size:12,weight:.medium))
                            if store.tokenExists && !store.cloudflareAccount.isEmpty && !editingCredentials {
                                Label("APIトークンはこのiPhoneに保存済み",systemImage:"lock.shield.fill")
                                    .font(.system(size:12,weight:.bold))
                                    .foregroundStyle(PopColor.royal)
                                Text("以前のAPIトークンを入力し直す必要はありません。AI漫画化を利用する際は、下のWorkers Free契約を確認してください。")
                                    .font(.system(size:11,weight:.medium))
                                Text("接続アカウント：\(store.cloudflareAccount)")
                                    .font(.system(size:10,weight:.medium))
                                    .textSelection(.enabled)
                                Toggle("Workers Free契約を確認済み",isOn:$store.confirmsFree)
                                    .font(.system(size:12,weight:.semibold))
                                    .tint(PopColor.blue)
                                HStack(spacing:14) {
                                    Button("接続情報を変更") {
                                        editingCredentials=true
                                    }
                                    Button("接続解除",role:.destructive) {
                                        store.disconnect()
                                        editingCredentials=true
                                    }
                                }
                                .font(.system(size:11,weight:.bold))
                            } else {
                                TextField("Cloudflare Account ID",text:$account)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .textFieldStyle(.roundedBorder)
                                SecureField("Workers AI API Token",text:$token)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .textFieldStyle(.roundedBorder)
                                Toggle("Workers Free契約を確認済み",isOn:$store.confirmsFree)
                                    .font(.system(size:12,weight:.semibold))
                                    .tint(PopColor.blue)
                                PopYellowButton(title:isConnecting ? "接続を確認中…" : "AIアカウントを接続",
                                                icon:"link",enabled:!isConnecting && !account.isEmpty &&
                                                !token.isEmpty && store.confirmsFree) {
                                    isConnecting=true
                                    store.cloudflareAccount=account
                                    Task {
                                        await store.connect(token:token)
                                        if store.tokenExists && !store.message.hasPrefix("接続失敗") {
                                            token=""
                                            editingCredentials=false
                                        }
                                        isConnecting=false
                                    }
                                }
                                if store.tokenExists {
                                    Label("元のトークンは保存されています。変更する場合だけ新しいトークンを入力してください。",
                                          systemImage:"info.circle")
                                        .font(.system(size:10,weight:.medium))
                                } else {
                                    Text("保存済みトークンが見つかりません。Cloudflareで新しいAPIトークンを作成して接続してください。")
                                        .font(.system(size:10,weight:.medium))
                                }
                            }
                            Text("注意：アプリは契約が有料か無料かを自動判定できません。接続前にCloudflareの契約・利用枠を必ず確認してください。")
                                .font(.system(size:10))
                                .foregroundStyle(PopColor.ink.opacity(0.8))
                        }
                        .foregroundStyle(PopColor.ink)
                        .frame(maxWidth:.infinity,alignment:.leading)
                    }
                    PopSurface {
                        VStack(alignment:.leading,spacing:7) {
                            Label("データとアプリ",systemImage:"internaldrive")
                                .font(.system(size:15,weight:.black,design:.rounded))
                            HStack {Text("アプリ名"); Spacer(); Text("ムビコマ")}
                            HStack {Text("保存作品"); Spacer();Text("\(store.data.works.count)作品")}
                            HStack {Text("マイデッキ"); Spacer();Text("\(store.data.decks.count)個")}
                            Text("保存した漫画ページと動画はこの端末のアプリ領域に保存されます。")
                                .font(.system(size:10))
                        }
                        .foregroundStyle(PopColor.ink)
                        .font(.system(size:12,weight:.medium))
                    }
                    Text(store.message)
                        .font(.caption)
                        .foregroundStyle(.white)
                }
                .padding(12)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PopBackground())
            .navigationTitle("AI接続・設定")
            .toolbar {ToolbarItem(placement:.topBarTrailing) {
                Button("完了") {dismiss()}
            }}
            .onAppear {account=store.cloudflareAccount}
        }
    }
}
