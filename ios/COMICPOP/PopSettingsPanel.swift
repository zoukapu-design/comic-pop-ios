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
    @State private var askDisconnect = false

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
                    PopSurface(accent:store.tokenExists) {
                        VStack(alignment:.leading,spacing:12) {
                            HStack(alignment:.center,spacing:8) {
                                Image(systemName:"sparkles")
                                    .font(.system(size:20,weight:.black))
                                    .foregroundStyle(PopColor.royal)
                                Text("AI漫画化")
                                    .font(.system(size:19,weight:.black,design:.rounded))
                                Spacer()
                                if store.hasCloudflareSetup && !editingCredentials {
                                    Label("設定済み",systemImage:"checkmark.shield.fill")
                                        .font(.system(size:11,weight:.heavy))
                                        .foregroundStyle(PopColor.royal)
                                }
                            }
                            if store.tokenExists && !editingCredentials {
                                Label("APIトークンはこのiPhoneに保存済み",
                                      systemImage:"lock.shield.fill")
                                    .font(.system(size:12,weight:.bold))
                                    .foregroundStyle(PopColor.royal)
                                if store.hasCloudflareSetup {
                                    Text("以前の設定を自動で使います。通常の漫画生成では、再接続もトークン入力も不要です。")
                                        .font(.system(size:12,weight:.medium))
                                    Text("接続先：\(store.cloudflareAccount.prefix(8))…")
                                        .font(.system(size:11,weight:.medium))
                                        .foregroundStyle(PopColor.royal)
                                    if store.confirmsFree {
                                        Label("Workers Free契約の確認を保存済み",
                                              systemImage:"checkmark.circle.fill")
                                            .font(.system(size:11,weight:.semibold))
                                    } else {
                                        Text("AI漫画化の利用前に、Workers Free契約かどうかを確認してください。")
                                            .font(.system(size:11,weight:.semibold))
                                        Toggle("Workers Free契約を確認済み",isOn:$store.confirmsFree)
                                            .font(.system(size:12,weight:.semibold))
                                            .tint(PopColor.blue)
                                    }
                                } else {
                                    Text("トークンは残っています。Account IDだけを入力すれば復旧できます。")
                                        .font(.system(size:11,weight:.medium))
                                    TextField("Cloudflare Account ID",text:$account)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .textFieldStyle(.roundedBorder)
                                    Toggle("Workers Free契約を確認済み",isOn:$store.confirmsFree)
                                        .font(.system(size:12,weight:.semibold))
                                        .tint(PopColor.blue)
                                }
                                HStack(spacing:10) {
                                    Button {
                                        isConnecting=true
                                        Task {
                                            _ = await store.reconnectSavedCloudflare(account:account)
                                            isConnecting=false
                                        }
                                    } label: {
                                        Label(isConnecting ? "確認中…" : "保存済みトークンで接続確認",
                                              systemImage:"arrow.clockwise.shield")
                                            .font(.system(size:11,weight:.bold))
                                            .frame(maxWidth:.infinity)
                                            .padding(.vertical,11)
                                    }
                                    .disabled(isConnecting ||
                                              account.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ||
                                              !store.confirmsFree)
                                    .background(.white,in:Capsule())
                                    .overlay(Capsule().stroke(PopColor.edge,lineWidth:1.6))
                                    Button("設定変更") {
                                        editingCredentials=true
                                    }
                                    .font(.system(size:11,weight:.bold))
                                    .padding(.horizontal,8)
                                }
                                .buttonStyle(.plain)
                                HStack {
                                    Button("新しいトークンに変更") {
                                        editingCredentials=true
                                    }
                                    Spacer()
                                    Button("接続解除",role:.destructive) {
                                        askDisconnect=true
                                    }
                                }
                                .font(.system(size:10,weight:.medium))
                                if store.isConnected {
                                    Text("接続情報を保存済み。必要なときだけ接続確認してください。")
                                        .font(.system(size:10,weight:.medium))
                                }
                            } else {
                                Text(store.tokenExists ?
                                     "新しいAPIトークンに変更します。変更に失敗しても以前のトークンは残ります。" :
                                     "最初の1回だけCloudflareアカウントを接続します。次回以降は自動で保存情報を利用します。")
                                    .font(.system(size:11,weight:.medium))
                                TextField("Cloudflare Account ID",text:$account)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .textFieldStyle(.roundedBorder)
                                SecureField("Workers AI API Token（初回・変更時のみ）",text:$token)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .textFieldStyle(.roundedBorder)
                                Toggle("Workers Free契約を確認済み",isOn:$store.confirmsFree)
                                    .font(.system(size:12,weight:.semibold))
                                    .tint(PopColor.blue)
                                PopYellowButton(title:isConnecting ? "接続を確認中…" : "AIアカウントを接続",
                                                icon:"link",
                                                enabled:!isConnecting &&
                                                !account.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty &&
                                                !token.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty &&
                                                store.confirmsFree) {
                                    isConnecting=true
                                    Task {
                                        let success=await store.connect(account:account,token:token)
                                        if success {
                                            token=""
                                            editingCredentials=false
                                        }
                                        isConnecting=false
                                    }
                                }
                                if store.tokenExists {
                                    Button("保存済みトークンに戻る") {
                                        token=""
                                        account=store.cloudflareAccount
                                        editingCredentials=false
                                    }
                                    .font(.system(size:11,weight:.bold))
                                } else {
                                    Link("CloudflareのAPIトークンを管理",
                                         destination:URL(string:"https://dash.cloudflare.com/profile/api-tokens")!)
                                        .font(.system(size:11,weight:.bold))
                                }
                            }
                            if store.message.hasPrefix("接続") ||
                               store.message.contains("トークン") {
                                Text(store.message)
                                    .font(.system(size:11,weight:.medium))
                            }
                            Text("トークンはiPhoneのKeychainに保存。利用プランはアプリから判別できないため、Workers Paid契約では課金にご注意ください。")
                                .font(.system(size:10,weight:.medium))
                                .foregroundStyle(PopColor.ink.opacity(0.82))
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
                }
                .padding(12)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PopBackground())
            .navigationTitle("AI接続・設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {ToolbarItem(placement:.topBarTrailing) {
                Button("完了") {dismiss()}
            }}
            .confirmationDialog("Cloudflare接続情報を解除しますか？",
                                isPresented:$askDisconnect,titleVisibility:.visible) {
                Button("トークンを削除して接続解除",role:.destructive) {
                    store.disconnect()
                    editingCredentials=false
                    token=""
                }
                Button("キャンセル",role:.cancel) {}
            } message: {
                Text("iPhoneのKeychainに保存されたAPIトークンを削除します。再接続にはトークンが必要になるため、通常のアップデート時には解除しないでください。")
            }
            .onAppear {account=store.cloudflareAccount}
        }
    }
}
