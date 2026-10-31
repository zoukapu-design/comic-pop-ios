import AVKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

private enum UIColors {
    static let ink=Color(red:0.085,green:0.115,blue:0.21)
    static let pink=Color(red:0.99,green:0.24,blue:0.52)
    static let yellow=Color(red:1,green:0.89,blue:0.36)
    static let paper=Color(red:1,green:0.985,blue:0.932)
}

struct MovieImport: Transferable {
    let url:URL
    static var transferRepresentation:some TransferRepresentation {
        FileRepresentation(contentType:.movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let url=FileManager.default.temporaryDirectory.appendingPathComponent("comicpop-\(UUID().uuidString).mov")
            try FileManager.default.copyItem(at:received.file,to:url)
            return MovieImport(url:url)
        }
    }
}

struct StudioRootView:View {
    @StateObject private var store=StudioStore()
    var body:some View {
        TabView {
            EditorScreen(store:store)
                .tabItem{Label("編集",systemImage:"film.stack")}
            MangaScreen(store:store)
                .tabItem{Label("漫画",systemImage:"book.pages")}
            WorksScreen(store:store)
                .tabItem{Label("作品",systemImage:"books.vertical")}
            SettingsScreen(store:store)
                .tabItem{Label("設定",systemImage:"paintpalette")}
        }
        .tint(UIColors.pink)
    }
}

struct ScreenHeading:View {
    let subtitle:String
    let title:String
    var body:some View {
        VStack(alignment:.leading,spacing:4){
            Text(subtitle).font(.caption.bold()).foregroundStyle(UIColors.pink)
            Text(title).font(.title2.bold()).foregroundStyle(UIColors.ink)
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
}

struct CardTile:View {
    let card:PinDefinition
    var body:some View {
        VStack(spacing:3){
            Text(symbol(for:card.category)).font(.largeTitle).frame(maxWidth:.infinity,minHeight:63)
                .background(Color(hex:card.color).opacity(0.55))
            Text(card.title).font(.subheadline.bold()).foregroundStyle(UIColors.ink).lineLimit(1)
            Text(card.subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(5).frame(width:110,height:132)
        .background(.white,in:RoundedRectangle(cornerRadius:12))
        .overlay(RoundedRectangle(cornerRadius:12).stroke(UIColors.ink,lineWidth:2.5))
    }
    private func symbol(for cat:String)->String {
        switch cat {case "story":return "📚";case "feeling":return "😆";case "scene":return "💥";case "character":return "🎭";default:return "✒️"}
    }
}

private extension Color {
    init(hex:String) {
        let v=Int(hex.replacingOccurrences(of:"#",with:""),radix:16) ?? 0xffffff
        self.init(red:Double((v>>16)&255)/255,green:Double((v>>8)&255)/255,blue:Double(v&255)/255)
    }
}

struct EditorScreen:View {
    @ObservedObject var store:StudioStore
    @State private var selectedPhoto:PhotosPickerItem?
    @State private var filePicker=false
    @State private var catalogOpen=false
    @State private var confirmClear=false
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:13){
                    ScreenHeading(subtitle:"01 / PINCARD STUDIO",title:"動画を見ながらカードを刺そう！")
                    Group {
                        if store.videoURL != nil {VideoPlayer(player:store.player).frame(maxWidth:.infinity).aspectRatio(16/9,contentMode:.fit).background(.black)}
                        else {
                            ZStack {RoundedRectangle(cornerRadius:16).fill(UIColors.ink)
                                VStack(spacing:8){Image(systemName:"play.rectangle.fill").font(.system(size:40));Text("動画を選択してください")}.foregroundStyle(.white)}
                                .frame(height:210)
                        }
                    }.clipShape(RoundedRectangle(cornerRadius:15))
                    HStack(spacing:8){
                        PhotosPicker(selection:$selectedPhoto,matching:.videos){Label("写真から",systemImage:"photo.on.rectangle").font(.subheadline.bold())}
                            .buttonStyle(.borderedProminent).tint(UIColors.pink)
                        Button {filePicker=true} label:{Label("ファイル",systemImage:"folder")}.buttonStyle(.bordered)
                        Spacer(minLength:3)
                        Text("\(store.data.pins.count)枚").font(.caption.bold()).foregroundStyle(.secondary)
                    }
                    HStack(spacing:9){
                        seekButton("−5",step:-5);seekButton("−1",step:-1)
                        Button{store.playPause()}label:{Image(systemName:store.player.rate>0 ? "pause.fill" : "play.fill").font(.headline).padding(.horizontal,7)}.buttonStyle(.borderedProminent).tint(UIColors.yellow).foregroundStyle(UIColors.ink)
                        seekButton("+1",step:1);seekButton("+5",step:5)
                    }.frame(maxWidth:.infinity)
                    Slider(value:Binding(get:{min(store.currentTime,max(store.duration,0.01))},set:{store.scrub(to:$0)}),in:0...max(0.01,store.duration))
                        .tint(UIColors.pink).disabled(store.duration<=0)
                    HStack{Text(store.formatted(store.currentTime));Spacer();Text(store.formatted(store.duration))}.font(.caption.monospacedDigit())
                    Divider()
                    HStack {
                        Text("🃏 マイデッキ").font(.headline)
                        Spacer()
                        if let selected=store.selectedDeck {Text(selected.name).font(.caption).foregroundStyle(.secondary)}
                        Button("編集"){store.deckEditing=true}.font(.subheadline.bold())
                    }
                    ScrollView(.horizontal,showsIndicators:false){
                        HStack(spacing:13){
                            ForEach(store.selectedDeck?.cardIDs ?? [],id:\.self){id in
                                if let def=store.cards.first(where:{$0.id==id}) {
                                    Button {Task {await store.addPin(card:def)}}label:{CardTile(card:def)}
                                        .buttonStyle(.plain)
                                }
                            }
                            Button{catalogOpen=true} label:{VStack{Image(systemName:"plus.circle.fill").font(.title);Text("全84種").font(.caption.bold())}.frame(width:92,height:126)}
                                .buttonStyle(.bordered)
                        }
                    }
                    Text("再生中もカードをタップすると、その時刻のフレームを保存します。")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack{
                        Text("📍 挿入済みのカード").font(.headline)
                        Spacer()
                        Button("ピンカード全削除",role:.destructive){confirmClear=true}.font(.caption.bold())
                            .disabled(store.data.pins.isEmpty)
                    }
                    ForEach(store.scenePlan.orderedPins){pin in
                        HStack(spacing:10){
                            if let shot=store.snapshot(for:pin) {Image(uiImage:shot).resizable().scaledToFill().frame(width:73,height:73).clipped().cornerRadius(8)}
                            VStack(alignment:.leading,spacing:3){Text(store.card(for:pin).title).font(.subheadline.bold());Text(store.formatted(pin.seconds)).font(.caption.monospacedDigit())}
                            Spacer()
                            Button{store.scrub(to:pin.seconds)}label:{Image(systemName:"arrowtriangle.right.fill")}
                            Button(role:.destructive){store.removePin(pin)}label:{Image(systemName:"trash")}
                        }.padding(8).background(.white,in:RoundedRectangle(cornerRadius:11))
                    }
                    if store.data.pins.isEmpty {Text("まだカードがありません。上のデッキから追加してください。").font(.caption).foregroundStyle(.secondary)}
                }.padding(15)
            }.background(UIColors.paper)
            .navigationTitle("COMIC POP!")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented:$catalogOpen){CatalogScreen(store:store)}
            .sheet(isPresented:$store.deckEditing){DeckScreen(store:store)}
            .confirmationDialog("動画のピンカードを全削除しますか？",isPresented:$confirmClear){Button("すべて削除",role:.destructive){store.clearPins()}}
            .fileImporter(isPresented:$filePicker,allowedContentTypes:[.movie],allowsMultipleSelection:false){result in
                if case .success(let urls)=result,let url=urls.first {Task {await store.replaceVideo(url)}}
            }
            .onChange(of:selectedPhoto){_,newValue in
                guard let newValue else{return}
                Task {do {if let movie=try await newValue.loadTransferable(type:MovieImport.self){await store.replaceVideo(movie.url)}}catch{store.message="動画選択エラー：\(error.localizedDescription)"}}
            }
            .safeAreaInset(edge:.bottom){Text(store.message).font(.caption).foregroundStyle(.primary).lineLimit(2).frame(maxWidth:.infinity).padding(8).background(UIColors.yellow.opacity(0.9))}
        }
    }
    func seekButton(_ label:String,step:Double)->some View {
        Button(label){store.seek(by:step)}.font(.subheadline.bold()).buttonStyle(.bordered).disabled(store.videoURL==nil)
    }
}

struct CatalogScreen:View {
    @ObservedObject var store:StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var search=""
    @State private var category="all"
    private let categories=[("all","すべて"),("story","ストーリー"),("feeling","感情"),("scene","演出"),("character","キャラ"),("editing","編集")]
    private var filtered:[PinDefinition]{store.cards.filter{(category=="all"||$0.category==category)&&(search.isEmpty||$0.title.localizedCaseInsensitiveContains(search)||$0.subtitle.localizedCaseInsensitiveContains(search))}}
    var body:some View {
        NavigationStack {
            VStack(alignment:.leading){
                Picker("カテゴリ",selection:$category){ForEach(categories.indices,id:\.self){i in Text(categories[i].1).tag(categories[i].0)}}.pickerStyle(.menu)
                ScrollView {LazyVGrid(columns:[GridItem(.adaptive(minimum:110))],spacing:15){ForEach(filtered){card in
                    Button {Task {await store.addPin(card:card)};dismiss()}label:{CardTile(card:card)}.buttonStyle(.plain)
                }}}.searchable(text:$search,prompt:"カード名で検索")
            }.padding()
            .navigationTitle("全84種類のピンカード")
            .toolbar{ToolbarItem(placement:.topBarTrailing){Button("閉じる"){dismiss()}}}
        }
    }
}

struct DeckScreen:View {
    @ObservedObject var store:StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var name=""
    @State private var search=""
    var body:some View {
        NavigationStack {
            ScrollView{
                VStack(alignment:.leading,spacing:15){
                    HStack{
                        Picker("デッキ",selection:Binding(get:{store.data.activeDeckID ?? store.data.decks[0].id},set:{store.selectDeck($0)})){
                            ForEach(store.data.decks){deck in Text(deck.name).tag(deck.id)}
                        }
                        Spacer()
                    }
                    HStack{TextField("新しいデッキの名前",text:$name).textFieldStyle(.roundedBorder)
                        Button("作成"){store.addDeck(name:name.isEmpty ? "新しいデッキ" : name);name=""}.disabled(store.data.decks.count>=20)}
                    if let deck=store.selectedDeck {
                        Text("「\(deck.name)」：\(deck.cardIDs.count)/12枚").font(.headline)
                        ForEach(deck.cardIDs,id:\.self){id in
                            if let card=store.cards.first(where:{$0.id==id}){
                                HStack {Text(card.title);Spacer()
                                    Button{store.moveDeckCard(id,by:-1)}label:{Image(systemName:"arrow.up")}
                                    Button{store.moveDeckCard(id,by:1)}label:{Image(systemName:"arrow.down")}
                                    Button(role:.destructive){store.toggleDeckCard(id)}label:{Image(systemName:"minus.circle")}
                                }.padding(8)
                            }
                        }
                        Button("このデッキを削除",role:.destructive){store.deleteDeck(deck.id)}.disabled(store.data.decks.count<=1)
                    }
                    Divider()
                    Text("カードをデッキに追加").font(.headline)
                    TextField("カードを検索",text:$search).textFieldStyle(.roundedBorder)
                    LazyVGrid(columns:[GridItem(.adaptive(minimum:110))],spacing:15){
                        ForEach(store.cards.filter{search.isEmpty||$0.title.localizedCaseInsensitiveContains(search)}){card in
                            Button {store.toggleDeckCard(card.id)}label:{
                                VStack(spacing:1){CardTile(card:card);Image(systemName:store.selectedDeck?.cardIDs.contains(card.id)==true ? "checkmark.circle.fill":"plus.circle")}
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding()
            }
            .navigationTitle("マイデッキを編集")
            .toolbar{ToolbarItem(placement:.topBarTrailing){Button("完了"){dismiss()}}}
        }
    }
}

struct MangaScreen:View {
    @ObservedObject var store:StudioStore
    @State private var confirmRun=false
    var body:some View {
        NavigationStack{
            ScrollView{
                VStack(alignment:.leading,spacing:15){
                    ScreenHeading(subtitle:"02 / AI MANGA GENERATOR",title:"✨ AIで漫画を作る")
                    VStack(alignment:.leading,spacing:8){
                        Text("📍 \(store.data.pins.count)枚のカード → \(store.scenePlan.pages)ページ予定（1ページ4コマ）").font(.headline)
                        Text("すべてのピンを個別にAIへ渡します。同じ時刻でも勝手に省略しません。")
                            .font(.caption).foregroundStyle(.secondary)
                        TextField("漫画のタイトル",text:Binding(get:{store.titleDraft},set:{store.updateTitle($0)})).textFieldStyle(.roundedBorder)
                        Picker("漫画の画風",selection:Binding(get:{store.data.style},set:{store.updateStyle($0)})) {
                            ForEach(MangaStyles.all.indices,id:\.self){i in Text(MangaStyles.all[i].title).tag(MangaStyles.all[i].id)}
                        }.pickerStyle(.menu)
                        Picker("色調",selection:Binding(get:{store.data.colorMode},set:{store.updateColor($0)})) {
                            Text("白黒漫画").tag("mono");Text("カラー漫画").tag("color")
                        }.pickerStyle(.segmented)
                    }.padding(13).background(.white,in:RoundedRectangle(cornerRadius:15))
                    Button{confirmRun=true}label:{
                        HStack{if store.isGenerating {ProgressView().tint(.white)}
                            Text(store.isGenerating ? "AIが生成中…" : "✨ 自分の無料GPUで漫画を生成").font(.headline.bold())}
                                .frame(maxWidth:.infinity).padding(11)
                    }.buttonStyle(.borderedProminent).tint(UIColors.pink)
                        .disabled(store.isGenerating||store.data.pins.isEmpty)
                    Text(store.message).font(.callout).padding(12).frame(maxWidth:.infinity,alignment:.leading)
                        .background(UIColors.yellow.opacity(0.42),in:RoundedRectangle(cornerRadius:12))
                    if !store.generated.isEmpty {
                        Text("🔍 元場面とAI作画を比較").font(.title3.bold())
                        Text("生成済み \(store.generated.count) / \(store.data.pins.count)コマ。問題があるコマは元動画へ戻せます。")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(store.generated){panel in
                            VStack(alignment:.leading,spacing:8){
                                Text(panel.cardTitle).font(.headline)
                                HStack(alignment:.top,spacing:7){
                                    VStack{Image(uiImage:panel.original).resizable().scaledToFit().frame(height:155);Text("元動画").font(.caption)}
                                    VStack{Image(uiImage:panel.drawing).resizable().scaledToFit().frame(height:155);Text("AI再描画").font(.caption)}
                                }
                                if let warning=panel.warning {Label(warning,systemImage:"exclamationmark.triangle.fill").font(.caption).foregroundStyle(.red)}
                                Button("このコマは元動画を優先"){store.chooseOriginal(panel.id)}.buttonStyle(.bordered)
                            }.padding(10).background(.white,in:RoundedRectangle(cornerRadius:12))
                        }
                        Text("📖 漫画プレビュー").font(.title3.bold())
                        ForEach(store.pageImages.indices,id:\.self){i in
                            Image(uiImage:store.pageImages[i]).resizable().scaledToFit()
                                .background(.white,in:RoundedRectangle(cornerRadius:12))
                        }
                        Button("📚 完成した漫画を作品一覧に保存"){store.saveWork()}
                            .buttonStyle(.borderedProminent).tint(UIColors.yellow).foregroundStyle(UIColors.ink)
                    }
                    Text("無料AIは各ユーザーのCloudflare Workers Free契約を使用します。広告を見てもGPU枠は増えません。生成画像の品質・場面一致は要確認です。")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(14)
            }.background(UIColors.paper).navigationTitle("COMIC POP! 漫画")
                .navigationBarTitleDisplayMode(.inline)
                .confirmationDialog("自分の無料GPU枠を使って生成しますか？",isPresented:$confirmRun){
                    Button("AI生成を実行") {Task {await store.generate()}}
                }message:{Text("選択した元フレームだけをCloudflareに送信します。Workers Free契約でご利用ください。Workers Paid契約ではCloudflare側の課金が発生する場合があります。アプリから有料APIへの自動切替は行いません。")}
        }
    }
}

struct WorksScreen:View {
    @ObservedObject var store:StudioStore
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:12){
                    ScreenHeading(subtitle:"03 / MY COMICS",title:"📚 作品一覧")
                    if store.data.works.isEmpty {ContentUnavailableView("まだ作品がありません",systemImage:"book.closed",description:Text("漫画画面で生成して保存してください"))}
                    ForEach(store.data.works){work in
                        VStack(alignment:.leading,spacing:8){
                            Text(work.title).font(.headline)
                            Text("\(work.sceneCount)コマ ・ \(work.files.count)ページ ・ \(work.createdAt.formatted(date:.abbreviated,time:.shortened))")
                                .font(.caption).foregroundStyle(.secondary)
                            ForEach(store.workImages(work).indices,id:\.self){i in
                                Image(uiImage:store.workImages(work)[i]).resizable().scaledToFit().cornerRadius(9)
                            }
                            // Export with iOS standard share sheet, no server upload.
                            ForEach(work.files,id:\.self){file in
                                if let shareURL=store.existingWorkURL(file){
                                    ShareLink(item:shareURL){Label("ページPNGを共有・保存",systemImage:"square.and.arrow.up").font(.caption.bold())}
                                }
                            }
                        }.padding(12).background(.white,in:RoundedRectangle(cornerRadius:13))
                    }
                }.padding(14)
            }.background(UIColors.paper).navigationTitle("COMIC POP! 作品")
        }
    }
}

struct SettingsScreen:View {
    @ObservedObject var store:StudioStore
    @State private var account=""
    @State private var token=""
    var body:some View {
        NavigationStack {
            Form {
                Section("あなたの無料GPU枠") {
                    Text("各ユーザーが自分のCloudflare Workers Freeアカウントを接続します。運営者のGPU枠は使用しません。").font(.caption)
                    TextField("Cloudflare Account ID",text:$account)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Workers AI API Token",text:$token)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Toggle("Workers Free契約を確認しました",isOn:$store.confirmsFree)
                    Button("自分の無料枠を接続"){
                        store.cloudflareAccount=account
                        Task {await store.connect(token:token);token=""}
                    }.disabled(account.isEmpty || token.isEmpty || !store.confirmsFree)
                    if store.isConnected || store.tokenExists {
                        Label("接続情報がiPhoneのKeychainに保存されています",systemImage:"lock.shield")
                        Button("切断してトークンを削除",role:.destructive){store.disconnect()}
                    }
                    Text("現段階は開発者向けの試験接続です。トークンはiPhoneのKeychainに保存し、画像生成時はiPhoneからCloudflareへ直接送信します。運営者サーバーは経由しません。契約種別をAPIで確認できないため、Workers Paid契約での利用は控えてください。公開版ではOAuth認証を検証します。").font(.caption).foregroundStyle(.secondary)
                }
                Section("広告について") {
                    Label("開発版では広告は配信しません",systemImage:"rectangle.badge.xmark")
                    Text("App Store公開時にAdMobを検討します。編集・AI生成中には広告を挟みません。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("バージョン") {Text("COMIC POP! iOS v2.1 / ネイティブ試作")}
            }.navigationTitle("設定")
                .onAppear{account=store.cloudflareAccount}
        }
    }
}

extension StudioStore {
    func existingWorkURL(_ file:String)->URL? {
        let base=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("COMICPOP",isDirectory:true)
        let url=base.appendingPathComponent(file)
        return FileManager.default.fileExists(atPath:url.path) ? url : nil
    }
}
