import SwiftUI

/// The actual app root: all three approved screens share one live StudioStore.
struct MovikomaPopRootView: View {
    @StateObject private var store = StudioStore()
    @State private var stage:PopStage = .editor
    @State private var showMenu = false
    @State private var showHelp = false
    @State private var showWorks = false
    @State private var showSettings = false
    @State private var showDeck = false
    @State private var showExportWarning = false

    var body:some View {
        VStack(spacing:0) {
            PopBrandHeader(
                onMenu:{showMenu=true},
                onHelp:{showHelp=true},
                onExport:{
                    if store.hasCompleteComic {
                        if store.saveWork() {showWorks=true}
                    } else if !store.data.works.isEmpty {
                        showWorks=true
                    } else {
                        showExportWarning=true
                    }
                })
            Group {
                switch stage {
                case .editor: PopEditorScreen(store:store) {stage = .styles}
                case .styles: PopGenreScreen(store:store,review:{stage = .review},
                                             openSettings:{showSettings=true})
                case .review: PopReviewScreen(store:store,backToStyles:{stage = .styles},
                                              showWorks:{showWorks=true})
                }
            }
            .frame(maxWidth:.infinity,maxHeight:.infinity)
            PopStepNavigation(stage:$stage)
        }
        .background(PopBackground())
        .preferredColorScheme(.light)
        .confirmationDialog("メニュー",isPresented:$showMenu) {
            Button("作品一覧") {showWorks=true}
            Button("マイデッキ") {showDeck=true}
            Button("AI接続・設定") {showSettings=true}
            Button("閉じる",role:.cancel){}
        }
        .alert("ムビコマの使い方",isPresented:$showHelp) {
            Button("OK",role:.cancel){}
        } message:{
            Text("① 動画を選ぶ → ② タイムラインで場面を選び、カードをタップ → ③ 画風を選んで生成 → ④ 元動画と比較し、保存・書き出し。カードは最大12枚です。")
        }
        .alert("書き出す作品がありません",isPresented:$showExportWarning) {
            Button("OK",role:.cancel){}
        } message:{
            Text("先にカードを挿入して漫画を生成し、完成後に「作品に保存」してください。")
        }
        .sheet(isPresented:$showWorks) {PopWorksSheet(store:store)}
        .sheet(isPresented:$showSettings) {PopSettingsSheet(store:store)}
        .sheet(isPresented:$showDeck) {PopDeckSheet(store:store)}
    }
}

/// Persistent card deck editor reachable from the editor and the top menu.
struct PopDeckSheet:View {
    @ObservedObject var store:StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var name=""
    @State private var search=""
    private let columns=[GridItem(.adaptive(minimum:108),spacing:7)]
    private var filtered:[PinDefinition] {
        store.cards.filter{
            search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) ||
            $0.subtitle.localizedCaseInsensitiveContains(search)
        }
    }
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:12) {
                    Text("デッキは最大20個。各デッキに12枚まで登録できます。")
                        .font(.caption).foregroundStyle(PopColor.ink)
                    if let selected=store.selectedDeck {
                        HStack {
                            Text("現在：\(selected.name)")
                                .font(.headline)
                                .foregroundStyle(PopColor.ink)
                            Spacer()
                            Button("削除",role:.destructive) {store.deleteDeck(selected.id)}
                                .disabled(store.data.decks.count<=1)
                        }
                    }
                    Picker("デッキを選ぶ",selection:Binding(
                        get:{store.selectedDeck?.id ?? store.data.decks[0].id},
                        set:{store.selectDeck($0)}
                    )) {
                        ForEach(store.data.decks) { deck in
                            Text(deck.name).tag(deck.id)
                        }
                    }
                    .pickerStyle(.menu)
                    HStack {
                        TextField("新しいデッキ名",text:$name)
                            .textFieldStyle(.roundedBorder)
                        Button("作成") {
                            store.addDeck(name:name.isEmpty ? "新しいデッキ" : name)
                            name=""
                        }
                        .disabled(store.data.decks.count>=20)
                    }
                    TextField("カード名から検索",text:$search)
                        .textFieldStyle(.roundedBorder)
                    LazyVGrid(columns:columns,spacing:10) {
                        ForEach(filtered) { card in
                            let active=store.selectedDeck?.cardIDs.contains(card.id) == true
                            Button {store.toggleDeckCard(card.id)} label:{
                                VStack(spacing:2) {
                                    MVSprite(tile:card.art % 16)
                                        .frame(height:76).clipped()
                                    Text(card.title)
                                        .font(.system(size:11,weight:.bold))
                                        .lineLimit(1)
                                    Image(systemName:active ? "checkmark.circle.fill" : "plus.circle")
                                        .foregroundStyle(active ? .green : PopColor.blue)
                                }
                                .foregroundStyle(PopColor.ink)
                                .padding(5)
                                .frame(maxWidth:.infinity)
                                .background(.white,in:RoundedRectangle(cornerRadius:11))
                                .overlay(RoundedRectangle(cornerRadius:11)
                                    .stroke(active ? PopColor.yellow : PopColor.edge,lineWidth:2))
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding()
            }
            .background(PopBackground())
            .navigationTitle("マイデッキ")
            .toolbar {ToolbarItem(placement:.topBarTrailing) {
                Button("完了") {dismiss()}
            }}
        }
    }
}

struct PopWorksSheet:View {
    @ObservedObject var store:StudioStore
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:12) {
                    if store.data.works.isEmpty {
                        VStack(spacing:8) {
                            Image(systemName:"books.vertical")
                                .font(.system(size:38))
                            Text("作品はまだありません")
                                .font(.headline)
                            Text("動画を選んでカードを刺し、生成した漫画を保存してください。")
                                .font(.caption)
                        }
                        .foregroundStyle(PopColor.ink)
                        .frame(maxWidth:.infinity).padding(30)
                    }
                    ForEach(store.data.works) { work in
                        PopSurface {
                            VStack(alignment:.leading,spacing:8) {
                                Text(work.title).font(.headline)
                                Text("\(work.sceneCount)コマ / \(work.files.count)ページ")
                                    .font(.caption)
                                if let first=store.workImages(work).first {
                                    Image(uiImage:first).resizable().scaledToFit()
                                        .frame(maxWidth:.infinity)
                                        .background(.white)
                                }
                                ScrollView(.horizontal,showsIndicators:false) {
                                    HStack(spacing:9) {
                                        ForEach(Array(work.files.enumerated()),id:\.offset) { index,file in
                                            if let url=store.existingWorkURL(file) {
                                                ShareLink(item:url) {
                                                    Label("\(index+1)ページを共有",systemImage:"square.and.arrow.up")
                                                        .font(.system(size:11,weight:.bold))
                                                        .foregroundStyle(PopColor.ink)
                                                        .padding(8)
                                                        .background(PopColor.yellow,in:Capsule())
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .foregroundStyle(PopColor.ink)
                        }
                    }
                }.padding()
            }
            .background(PopBackground())
            .navigationTitle("ムビコマ作品一覧")
            .toolbar {ToolbarItem(placement:.topBarTrailing) {
                Button("閉じる") {dismiss()}
            }}
        }
    }
}

/// AI connection is optional: trial mode runs locally with no account.
struct PopSettingsSheet:View {
    @ObservedObject var store:StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var account=""
    @State private var token=""
    var body:some View {
        NavigationStack {
            Form {
                Section("無料おためし生成") {
                    Label("端末内で漫画調に加工。ネット接続・APIキー不要",systemImage:"iphone")
                    Text("本格的なAI再描画とは異なります。").font(.caption)
                }
                Section("Cloudflare Workers AI（任意）") {
                    TextField("Account ID",text:$account)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Workers AI API Token",text:$token)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Toggle("Workers Free契約を確認しました",isOn:$store.confirmsFree)
                    Button("接続する") {
                        store.cloudflareAccount=account
                        Task {await store.connect(token:token);token=""}
                    }
                    .disabled(account.isEmpty || token.isEmpty || !store.confirmsFree)
                    if store.tokenExists {
                        Label("APIトークンはiPhone Keychainに保存中",systemImage:"lock.shield")
                        Button("接続解除",role:.destructive) {store.disconnect()}
                    }
                    Text("Cloudflareのプラン種別はアプリから検証できません。Paid契約の課金を防止できないため、利用者自身で必ず確認してください。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("アプリ") {
                    LabeledContent("名前",value:"ムビコマ")
                    LabeledContent("デザイン",value:"レックス・コミックスタジオ")
                    Text(store.message).font(.footnote)
                }
            }
            .navigationTitle("AI接続・設定")
            .onAppear {account=store.cloudflareAccount}
            .toolbar {ToolbarItem(placement:.topBarTrailing) {
                Button("完了") {dismiss()}
            }}
        }
    }
}
