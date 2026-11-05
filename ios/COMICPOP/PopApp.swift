import SwiftUI

/// The actual app root: all three approved screens share one live StudioStore.
struct MovikomaPopRootView: View {
    @StateObject private var store = StudioStore()
    @AppStorage("pop.didSeeWelcome") private var didSeeWelcome = false
    private enum Journey: Equatable {case home, selectVideo, workspace}
    @State private var journey:Journey = .home
    @State private var stage:PopStage = .editor
    @State private var showSavedConfirmation = false
    @State private var showWorksAfterSaving = false
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
                        if store.saveWork() {showSavedConfirmation=true}
                    } else if !store.data.works.isEmpty {
                        showWorks=true
                    } else {
                        showExportWarning=true
                    }
                })
            Group {
                switch journey {
                case .home:
                    PopHomeScreen(store:store,
                        chooseVideo:{journey = .selectVideo},
                        continueEditing:{journey = .workspace;stage = .editor},
                        openWorks:{showWorks = true},
                        openDeck:{showDeck = true},
                        openSettings:{showSettings = true})
                case .selectVideo:
                    PopVideoChooseScreen(store:store,
                        startEditing:{journey = .workspace;stage = .editor},
                        goBack:{journey = .home})
                case .workspace:
                    switch stage {
                    case .editor:
                        PopEditorScreen(store:store,proceed:{stage = .styles},
                                        changeVideo:{journey = .selectVideo})
                    case .styles:
                        PopGenreScreen(store:store,review:{stage = .review},
                                       openSettings:{showSettings=true})
                    case .review:
                        PopReviewScreen(store:store,backToStyles:{stage = .styles},
                                        showWorks:{showSavedConfirmation=true})
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if journey == .workspace {
                PopStepNavigation(stage:$stage)
            }
        }
        .background(PopBackground())
        .preferredColorScheme(.light)
        .confirmationDialog("メニュー",isPresented:$showMenu) {
            Button("ホーム") {journey = .home}
            Button("新しい動画を選ぶ") {journey = .selectVideo}
            Button("カード挿入スタジオ") {journey = .workspace;stage = .editor}
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
        .sheet(isPresented:$showSavedConfirmation,onDismiss:{
            if showWorksAfterSaving {
                showWorksAfterSaving = false
                showWorks = true
            }
        }) {
            PopSavedConfirmation(store:store,
                goHome:{journey = .home},
                goToWorks:{showWorksAfterSaving = true})
        }
        .sheet(isPresented:$showSettings) {PopSettingsPanel(store:store)}
        .sheet(isPresented:$showDeck) {PopDeckSheet(store:store)}
        .fullScreenCover(isPresented:Binding(
            get:{!didSeeWelcome},
            set:{if !$0 {didSeeWelcome=true}}
        )) {
            PopWelcomeScreen {didSeeWelcome=true}
        }
        .onChange(of:stage) { _,next in
            if next != .editor {store.player.pause()}
        }
        .onChange(of:journey) { _,next in
            if next != .workspace {store.player.pause()}
        }
    }
}

/// Persistent card deck editor reachable from the editor and the top menu.
struct PopDeckSheet: View {
    @ObservedObject var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var search = ""
    @State private var renameDraft = ""
    @State private var showRename = false
    @State private var showDeleteDeck = false
    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 8)]
    private var filtered: [PinDefinition] {
        store.cards.filter {
            search.isEmpty ||
            $0.title.localizedCaseInsensitiveContains(search) ||
            $0.subtitle.localizedCaseInsensitiveContains(search)
        }
    }
    private var selectedIDs: [String] {store.selectedDeck?.cardIDs ?? []}

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators:false) {
                VStack(alignment: .leading, spacing: 12) {
                    PopBlueTitle(icon: "square.stack.fill", title: "マイデッキ")
                    PopSurface {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("よく使うレックスのカードを、最大12枚まで自由に並べられます。")
                                .font(.system(size: 11, weight: .semibold))
                            Picker("使うデッキ", selection: Binding(
                                get: {store.selectedDeck?.id ?? store.data.decks[0].id},
                                set: {store.selectDeck($0)}
                            )) {
                                ForEach(store.data.decks) { deck in
                                    Text(deck.name).tag(deck.id)
                                }
                            }
                            .pickerStyle(.menu)
                            HStack {
                                Button("名前を変える") {
                                    renameDraft=store.selectedDeck?.name ?? ""
                                    showRename=true
                                }
                                .buttonStyle(.bordered)
                                Button("デッキを削除", role: .destructive) {
                                    showDeleteDeck=true
                                }
                                .disabled(store.data.decks.count <= 1)
                                .buttonStyle(.bordered)
                            }
                            HStack {
                                TextField("新しいデッキ名", text: $name)
                                    .textFieldStyle(.roundedBorder)
                                Button {
                                    store.addDeck(name:name.isEmpty ? "新しいデッキ" : name)
                                    name=""
                                } label: {
                                    Label("作成",systemImage:"plus")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(PopColor.blue)
                                .disabled(store.data.decks.count >= 20)
                            }
                            Text("デッキ：\(store.data.decks.count) / 20")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(PopColor.ink)
                    }

                    PopSurface {
                        VStack(alignment:.leading,spacing:8) {
                            HStack {
                                Text("デッキの並び順")
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                Spacer()
                                Text("\(selectedIDs.count) / 12枚")
                                    .font(.system(size: 12, weight: .heavy))
                            }
                            if selectedIDs.isEmpty {
                                Text("下のカード一覧から＋を押すと、このデッキに追加されます。")
                                    .font(.system(size: 11))
                            }
                            ForEach(Array(selectedIDs.enumerated()), id: \.element) { entry in
                                let id=entry.element
                                let index=entry.offset
                                if let card=store.cards.first(where:{$0.id==id}) {
                                    HStack(spacing:8) {
                                        PopArtwork(kind:.cards,index:cardArtworkIndex(id))
                                            .frame(width:53,height:53)
                                            .clipShape(RoundedRectangle(cornerRadius:9))
                                        VStack(alignment:.leading,spacing:2) {
                                            Text(card.title).font(.system(size:13,weight:.heavy))
                                            Text("順番：\(index+1)")
                                                .font(.system(size:10,weight:.medium))
                                        }
                                        Spacer()
                                        Button {store.moveDeckCard(id,by:-1)} label:{
                                            Image(systemName:"arrow.up.circle.fill")
                                        }.disabled(index==0)
                                        Button {store.moveDeckCard(id,by:1)} label:{
                                            Image(systemName:"arrow.down.circle.fill")
                                        }.disabled(index == selectedIDs.count-1)
                                        Button(role:.destructive) {store.toggleDeckCard(id)} label:{
                                            Image(systemName:"xmark.circle.fill")
                                        }
                                    }
                                    .font(.system(size:22))
                                    .foregroundStyle(PopColor.ink)
                                    .padding(.vertical,3)
                                }
                            }
                        }.foregroundStyle(PopColor.ink)
                    }

                    PopSurface {
                        VStack(alignment:.leading,spacing:9) {
                            TextField("カード名で検索",text:$search)
                                .textFieldStyle(.roundedBorder)
                            Text("タップで追加・解除。下の一覧をスクロールできます。")
                                .font(.system(size:11,weight:.medium))
                                .foregroundStyle(PopColor.ink)
                            LazyVGrid(columns:columns,spacing:10) {
                                ForEach(filtered) { card in
                                    let active=selectedIDs.contains(card.id)
                                    Button {store.toggleDeckCard(card.id)} label:{
                                        VStack(spacing:3) {
                                            PopArtwork(kind:.cards,index:cardArtworkIndex(card.id))
                                                .frame(height:76)
                                                .clipShape(RoundedRectangle(cornerRadius:9))
                                            Text(card.title)
                                                .font(.system(size:11,weight:.heavy))
                                                .lineLimit(1)
                                            Label(active ? "登録済み" : "追加",
                                                  systemImage:active ? "checkmark.circle.fill" : "plus.circle.fill")
                                                .font(.system(size:10,weight:.semibold))
                                                .foregroundStyle(active ? PopColor.blue : PopColor.ink)
                                        }
                                        .foregroundStyle(PopColor.ink)
                                        .padding(5)
                                        .frame(maxWidth:.infinity)
                                        .background(.white,in:RoundedRectangle(cornerRadius:12))
                                        .overlay(RoundedRectangle(cornerRadius:12)
                                            .stroke(active ? PopColor.yellow : PopColor.edge,lineWidth:active ? 3 : 1.6))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }.padding(12)
            }
            .background(PopBackground())
            .navigationTitle("マイデッキ")
            .toolbar {ToolbarItem(placement:.topBarTrailing) {
                Button("完了") {dismiss()}
            }}
            .alert("デッキ名を変更",isPresented:$showRename) {
                TextField("新しい名前",text:$renameDraft)
                Button("保存") {
                    if let deck=store.selectedDeck {store.renameDeck(deck.id,to:renameDraft)}
                }
                Button("キャンセル",role:.cancel){}
            }
            .confirmationDialog("このデッキを削除しますか？",
                                isPresented:$showDeleteDeck,titleVisibility:.visible) {
                Button("削除",role:.destructive) {
                    if let id=store.selectedDeck?.id {store.deleteDeck(id)}
                }
                Button("キャンセル",role:.cancel){}
            } message: {
                Text("デッキだけを削除します。元のカード・作品は消えません。")
            }
        }
    }
    private func cardArtworkIndex(_ id:String)->Int {
        let map:[String:Int]=[
            "intro":0,"slow":1,"dramatic":2,"tsukkomi":3,
            "idea":4,"sad":5,"large":6,"punch":7
        ]
        return map[id] ?? id.utf8.reduce(0){($0 &* 31) &+ Int($1)} & 7
    }
}

struct PopWorksSheet: View {
    @ObservedObject var store:StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var pdfURL:URL?
    @State private var showPDFShare=false
    @State private var deleteID:UUID?

    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:12) {
                    if store.data.works.isEmpty {
                        PopSurface {
                            VStack(spacing:12) {
                                PopArtwork(kind:.hero).frame(height:145)
                                    .clipShape(RoundedRectangle(cornerRadius:12))
                                Text("作品はまだありません")
                                    .font(.system(size:19,weight:.black))
                                Text("動画からマンガを作り、保存するとここに並びます。")
                                    .font(.system(size:12))
                            }
                            .foregroundStyle(PopColor.ink)
                            .frame(maxWidth:.infinity).padding(14)
                        }
                    }
                    ForEach(store.data.works) { work in
                        PopSurface {
                            VStack(alignment:.leading,spacing:9) {
                                HStack(alignment:.firstTextBaseline) {
                                    Text(work.title)
                                        .font(.system(size:17,weight:.black,design:.rounded))
                                    Spacer()
                                    Text("\(work.files.count)ページ")
                                        .font(.system(size:11,weight:.heavy))
                                }
                                HStack {
                                    Text(work.createdAt.formatted(date:.abbreviated,time:.shortened))
                                    Spacer()
                                    Text("\(work.sceneCount)コマ")
                                }
                                .font(.system(size:11,weight:.medium))
                                if let first=store.workImages(work).first {
                                    Image(uiImage:first)
                                        .resizable().scaledToFit()
                                        .frame(maxWidth:.infinity)
                                        .background(.white)
                                        .overlay(Rectangle().stroke(PopColor.edge,lineWidth:1))
                                }
                                ScrollView(.horizontal,showsIndicators:false) {
                                    HStack(spacing:8) {
                                        ForEach(Array(work.files.enumerated()),id:\.offset) { entry in
                                            if let url=store.existingWorkURL(entry.element) {
                                                ShareLink(item:url) {
                                                    Label("\(entry.offset+1)ページのPNG",
                                                          systemImage:"square.and.arrow.up")
                                                        .font(.system(size:11,weight:.bold))
                                                        .foregroundStyle(PopColor.ink)
                                                        .padding(.horizontal,11).padding(.vertical,10)
                                                        .background(PopColor.yellow,in:Capsule())
                                                }
                                            }
                                        }
                                    }
                                }
                                HStack(spacing:9) {
                                    Button {
                                        pdfURL=store.exportPDF(work)
                                        showPDFShare=pdfURL != nil
                                    } label: {
                                        Label("全ページをPDFで共有",
                                              systemImage:"doc.richtext.fill")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(PopColor.blue)
                                    Spacer()
                                    Button("削除",role:.destructive) {deleteID=work.id}
                                        .buttonStyle(.bordered)
                                }
                                .font(.system(size:11,weight:.bold))
                            }
                            .foregroundStyle(PopColor.ink)
                        }
                    }
                    Text(store.message).font(.caption).foregroundStyle(.white)
                }.padding(12)
            }
            .background(PopBackground())
            .navigationTitle("ムビコマ作品一覧")
            .toolbar {ToolbarItem(placement:.topBarTrailing) {
                Button("閉じる") {dismiss()}
            }}
            .sheet(isPresented:$showPDFShare) {
                if let pdfURL {PopFileShareSheet(files:[pdfURL])}
            }
            .confirmationDialog("この作品を削除しますか？",
                                isPresented:Binding(get:{deleteID != nil},
                                                    set:{if !$0 {deleteID=nil}}),
                                titleVisibility:.visible) {
                Button("作品を削除",role:.destructive) {
                    if let id=deleteID {store.deleteWork(id)}
                    deleteID=nil
                }
                Button("キャンセル",role:.cancel) {deleteID=nil}
            } message: {
                Text("保存済み漫画の画像も削除されます。元動画とデッキは残ります。")
            }
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
