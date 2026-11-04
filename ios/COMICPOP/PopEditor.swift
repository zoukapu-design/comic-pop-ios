import AVKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// First reference screen: functional video editor and 4x2 comic card studio.
/// No full-screen image and no fake video timeline.
struct PopEditorScreen: View {
    @ObservedObject var store: StudioStore
    var proceed: () -> Void
    @State private var pickedVideo: PhotosPickerItem?
    @State private var importingFile = false
    @State private var fullScreen = false
    @State private var showDeck = false
    @State private var showRemoveAll = false
    @State private var cardGroup: CardGroup = .recommended
    @State private var selectedID = "intro"
    @AppStorage("pop.favorite.cardIDs") private var favouriteValue = ""

    private enum CardGroup: String, CaseIterable {
        case deck = "マイデッキ"
        case favourites = "お気に入り"
        case recommended = "おすすめ"
    }
    private let featuredIDs = ["intro","slow","dramatic","tsukkomi","idea","sad","large","punch"]
    private var favourites: Set<String> {
        Set(favouriteValue.split(separator:"|").map(String.init))
    }
    private var ids: [String] {
        switch cardGroup {
        case .deck: return store.selectedDeck?.cardIDs ?? []
        case .favourites: return store.cards.map(\.id).filter{favourites.contains($0)}
        case .recommended: return featuredIDs
        }
    }
    private func card(_ id: String) -> PinDefinition? {
        store.cards.first(where:{$0.id == id})
    }
    private var canInsert: Bool {
        store.videoURL != nil && card(selectedID) != nil && store.data.pins.count < 12
    }

    var body: some View {
        ScrollView(showsIndicators:false) {
            VStack(alignment:.leading,spacing:11) {
                videoPreview
                playbackControls
                PopTimeline(store:store)
                cardStudio
                if !store.data.pins.isEmpty { insertedPins }
                if !store.message.isEmpty {
                    Text(store.message)
                        .font(.system(size:11,weight:.semibold))
                        .foregroundStyle(.white).padding(.horizontal,6)
                        .accessibilityIdentifier("popStatusMessage")
                }
            }
            .padding(.horizontal,10).padding(.bottom,12)
        }
        .sheet(isPresented:$showDeck) { PopDeckSheet(store:store) }
        .fullScreenCover(isPresented:$fullScreen) {
            ZStack(alignment:.topTrailing) {
                Color.black.ignoresSafeArea()
                VideoPlayer(player:store.player).ignoresSafeArea(edges:.horizontal)
                Button {fullScreen=false} label:{
                    Label("戻る",systemImage:"xmark.circle.fill")
                        .padding(9).background(.black.opacity(0.6),in:Capsule())
                }
                .foregroundStyle(.white).padding()
            }
        }
        .fileImporter(isPresented:$importingFile,allowedContentTypes:[.movie],allowsMultipleSelection:false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { Task {await store.replaceVideo(url)} }
            case .failure(let error):
                store.message = "ファイルを読み込めません：\(error.localizedDescription)"
            }
        }
        .onChange(of:pickedVideo) { _,video in
            guard let video else {return}
            Task {
                do {
                    guard let movie = try await video.loadTransferable(type:MovieImport.self) else {
                        store.message="動画を読み込めませんでした"
                        return
                    }
                    await store.replaceVideo(movie.url)
                } catch { store.message="動画選択エラー：\(error.localizedDescription)" }
            }
        }
        .confirmationDialog("すべての挿入カードを削除しますか？",isPresented:$showRemoveAll) {
            Button("すべて削除",role:.destructive) {store.clearPins()}
        }
        .onChange(of:store.data.activeDeckID) { _,_ in
            if let next = store.selectedDeck?.cardIDs.first {selectedID=next}
        }
    }

    private var videoPreview: some View {
        ZStack(alignment:.topTrailing) {
            Group {
                if store.videoURL != nil {
                    PopAVPlayerSurface(player:store.player)
                } else {
                    ZStack {
                        LinearGradient(colors:[PopColor.blue,PopColor.navy],startPoint:.top,endPoint:.bottom)
                        PopArtwork(kind:.hero)
                        VStack {
                            Spacer()
                            Text("動画を選んで、マンガを作ろう！")
                                .font(.system(size:14,weight:.black,design:.rounded))
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(PopColor.navy.opacity(0.88),in:Capsule())
                                .padding(.bottom,10)
                        }
                    }
                }
            }
            .frame(maxWidth:.infinity)
            .aspectRatio(16.0/9.0,contentMode:.fit)
            .clipShape(RoundedRectangle(cornerRadius:17))
            .overlay(RoundedRectangle(cornerRadius:17).stroke(PopColor.edge,lineWidth:2.5))
            .shadow(color:PopColor.cyan.opacity(0.28),radius:6)
            HStack {
                if store.videoURL != nil {
                    Text("\(store.formatted(store.currentTime)) / \(store.formatted(store.duration))")
                        .font(.system(size:11,weight:.bold,design:.monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal,8).padding(.vertical,5)
                        .background(PopColor.navy.opacity(0.75),in:Capsule())
                }
                Spacer()
                Button {fullScreen=true} label:{
                    Image(systemName:"arrow.up.left.and.arrow.down.right")
                        .font(.system(size:13,weight:.bold))
                        .foregroundStyle(.white)
                        .padding(7)
                        .background(PopColor.navy.opacity(0.8),in:RoundedRectangle(cornerRadius:8))
                }
                .disabled(store.videoURL == nil)
            }.padding(9)
        }
        .overlay(alignment:.bottomTrailing) {
            HStack(spacing:6) {
                PhotosPicker(selection:$pickedVideo,matching:.videos) {
                    Label(store.videoURL == nil ? "動画を選ぶ" : "動画を変更",systemImage:"play.rectangle.on.rectangle")
                }
                Button {importingFile=true} label:{Image(systemName:"folder")}
            }
            .font(.system(size:11,weight:.bold))
            .padding(.horizontal,9).padding(.vertical,7)
            .foregroundStyle(PopColor.ink)
            .background(PopColor.yellow,in:Capsule())
            .padding(10)
        }
    }

    private var playbackControls: some View {
        HStack(spacing:6) {
            seekButton("5秒",icon:"backward.end.fill",by:-5)
            seekButton("1秒",icon:"backward.fill",by:-1)
            Button {store.playPause()} label:{
                Image(systemName:store.player.rate>0 ? "pause.fill" : "play.fill")
                    .font(.system(size:21,weight:.bold))
                    .foregroundStyle(.white)
                    .frame(width:46,height:42)
                    .background(LinearGradient(colors:[PopColor.blue,PopColor.navy],startPoint:.top,endPoint:.bottom),in:Circle())
                    .overlay(Circle().stroke(PopColor.edge,lineWidth:2))
            }
            .disabled(store.videoURL == nil)
            seekButton("1秒",icon:"forward.fill",by:1)
            seekButton("5秒",icon:"forward.end.fill",by:5)
        }
        .frame(maxWidth:.infinity)
        .buttonStyle(.plain)
    }
    private func seekButton(_ seconds:String,icon:String,by delta:Double)->some View {
        Button {store.seek(by:delta)} label:{
            HStack(spacing:3) {
                Image(systemName:icon).font(.system(size:12,weight:.bold))
                Text(seconds).font(.system(size:11,weight:.heavy,design:.rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth:.infinity)
            .padding(.vertical,9)
            .background(PopColor.navy.opacity(0.72),in:Capsule())
            .overlay(Capsule().stroke(PopColor.edge,lineWidth:1.5))
        }.disabled(store.videoURL == nil)
    }

    private var cardStudio: some View {
        PopSurface {
            VStack(alignment:.leading,spacing:8) {
                HStack(spacing:5) {
                    PopBlueTitle(icon:"movieclapper.fill",title:"カード挿入スタジオ")
                    Text("カードをタップして\n今の場面に挿入")
                        .font(.system(size:10,weight:.bold,design:.rounded))
                        .foregroundStyle(PopColor.ink)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth:.infinity)
                }
                HStack(spacing:5) {
                    PopPill(text:"マイデッキ",icon:"square.stack.3d.up",selected:cardGroup == .deck) {
                        cardGroup = .deck
                    }
                    PopPill(text:"お気に入り",icon:"star",selected:cardGroup == .favourites) {
                        cardGroup = .favourites
                    }
                    PopPill(text:"おすすめ",icon:"flame.fill",selected:cardGroup == .recommended) {
                        cardGroup = .recommended
                    }
                }
                if cardGroup == .deck {
                    Button {showDeck=true} label:{
                        Label("デッキを編集：\(store.selectedDeck?.name ?? "いつもの")",systemImage:"square.on.square")
                            .font(.system(size:11,weight:.bold))
                            .foregroundStyle(PopColor.royal)
                    }.buttonStyle(.plain)
                }
                if ids.isEmpty {
                    Text("カードがありません。おすすめから選び、長押しでお気に入りに登録できます。")
                        .font(.caption).foregroundStyle(PopColor.ink).padding(12)
                } else {
                    LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:5),count:4),spacing:7) {
                        ForEach(Array(ids.prefix(12)).indices,id:\.self) { i in
                            let id=ids[i]
                            if let def=card(id) {
                                Button {selectAndInsert(def)} label: {
                                    PopIllustratedCard(title:displayTitle(id,defaultTitle:def.title),
                                                       artIndex:tileIndex(id),selected:selectedID==id)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(favourites.contains(id) ? "お気に入りを解除" : "お気に入り登録",
                                           systemImage:favourites.contains(id) ? "star.slash" : "star.fill") {
                                        toggleFavourite(id)
                                    }
                                    Button("選択のみ",systemImage:"checkmark.circle") {selectedID=id}
                                }
                            }
                        }
                    }
                }
                HStack(spacing:8) {
                    PopYellowButton(title:"＋ 挿入",icon:"plus",enabled:canInsert) {
                        if let def=card(selectedID) {Task {await store.addPin(card:def)}}
                    }
                    VStack(alignment:.leading,spacing:3) {
                        Image(systemName:"bolt.fill").foregroundStyle(.yellow)
                        Text("今のシーンに\nカードを挿入")
                            .font(.system(size:11,weight:.black,design:.rounded))
                            .foregroundStyle(PopColor.ink)
                    }.frame(width:87,alignment:.leading)
                }
                if store.data.pins.count > 0 {
                    PopYellowButton(title:"画風を選んで漫画に変換",icon:"book.closed.fill") {
                        proceed()
                    }
                }
            }
        }
    }

    private var insertedPins: some View {
        PopSurface {
            VStack(alignment:.leading,spacing:7) {
                HStack {
                    Text("挿入したカード \(store.data.pins.count)枚")
                        .font(.system(size:14,weight:.black,design:.rounded))
                        .foregroundStyle(PopColor.ink)
                    Spacer()
                    Button("全削除",role:.destructive) {showRemoveAll=true}
                        .font(.system(size:12,weight:.bold))
                }
                ForEach(store.scenePlan.orderedPins) { pin in
                    HStack(spacing:7) {
                        if let snap=store.snapshot(for:pin) {
                            Image(uiImage:snap).resizable().scaledToFill()
                                .frame(width:50,height:38).clipped()
                                .clipShape(RoundedRectangle(cornerRadius:6))
                        }
                        Text(store.formatted(pin.seconds))
                            .font(.system(size:11,weight:.bold,design:.monospaced))
                        Text(store.card(for:pin).title).font(.system(size:12,weight:.bold))
                        Spacer()
                        Button {store.scrub(to:pin.seconds)} label:{
                            Image(systemName:"play.circle.fill")
                        }
                        Button(role:.destructive) {store.removePin(pin)} label:{
                            Image(systemName:"trash")
                        }
                    }
                    .foregroundStyle(PopColor.ink)
                    .padding(.vertical,4)
                }
            }
        }
    }

    private func selectAndInsert(_ definition:PinDefinition) {
        selectedID=definition.id
        guard store.videoURL != nil else {
            store.message="先に動画を選んでください"
            return
        }
        guard store.data.pins.count < 12 else {
            store.message="無料枠保護のため一度に最大12コマです"
            return
        }
        Task {await store.addPin(card:definition)}
    }
    private func toggleFavourite(_ id:String) {
        var values=favourites
        if values.contains(id) {values.remove(id)} else {values.insert(id)}
        favouriteValue=values.sorted().joined(separator:"|")
    }
    private func tileIndex(_ id:String)->Int {
        let mapped:[String:Int]=["intro":0,"slow":1,"dramatic":2,"tsukkomi":3,
                                  "idea":4,"sad":5,"large":6,"punch":7]
        return mapped[id] ?? abs(id.utf8.reduce(0){($0 &* 31) &+ Int($1)})%8
    }
    private func displayTitle(_ id:String,defaultTitle:String)->String {
        defaultTitle
    }
}

/// A real AVPlayerLayer without duplicate Apple playback chrome.
private final class PopPlayerHost: UIView {
    override class var layerClass: AnyClass {AVPlayerLayer.self}
    var playerLayer: AVPlayerLayer {layer as! AVPlayerLayer}
}
private struct PopAVPlayerSurface: UIViewRepresentable {
    let player:AVPlayer
    func makeUIView(context:Context)->PopPlayerHost {
        let v=PopPlayerHost()
        v.playerLayer.player=player
        v.playerLayer.videoGravity = .resizeAspect
        v.backgroundColor = .black
        return v
    }
    func updateUIView(_ v:PopPlayerHost,context:Context) {v.playerLayer.player=player}
}

/// The frame strip is extracted from the actual selected video, not stock Rex art.
private struct PopTimeline: View {
    @ObservedObject var store:StudioStore
    @State private var frames:[UIImage?]=Array(repeating:nil,count:5)
    var body:some View {
        VStack(spacing:2) {
            HStack {
                Text(store.formatted(store.currentTime))
                Spacer()
                Text(store.formatted(store.duration))
            }
            .font(.system(size:10,weight:.bold,design:.monospaced))
            .foregroundStyle(.white)
            Slider(value:Binding(
                get:{min(store.currentTime,max(0.01,store.duration))},
                set:{store.scrub(to:$0)}
            ),in:0...max(0.01,store.duration))
                .tint(PopColor.cyan)
                .disabled(store.duration<=0)
            GeometryReader { geo in
                ZStack(alignment:.leading) {
                    HStack(spacing:2) {
                        ForEach(0..<5,id:\.self) { i in
                            ZStack {
                                if let img=frames[i] {
                                    Image(uiImage:img).resizable().scaledToFill()
                                } else {
                                    PopColor.royal.overlay(Image(systemName:"film").foregroundStyle(.white.opacity(0.27)))
                                }
                            }
                            .frame(width:(geo.size.width-8)/5,height:42)
                            .clipped().clipShape(RoundedRectangle(cornerRadius:5))
                        }
                    }
                    ForEach(store.scenePlan.orderedPins) { pin in
                        Rectangle().fill(PopColor.yellow).frame(width:2,height:42)
                            .offset(x:CGFloat(pin.seconds/max(0.01,store.duration))*geo.size.width)
                    }
                    Rectangle().fill(PopColor.yellow).frame(width:3,height:46)
                        .offset(x:CGFloat(store.currentTime/max(0.01,store.duration))*max(0,geo.size.width-3))
                }
            }
            .frame(height:44)
        }
        .task(id:store.videoURL?.absoluteString ?? "-") {
            frames=Array(repeating:nil,count:5)
            guard let url=store.videoURL else {return}
            let seconds=store.duration
            guard seconds>0 else {return}
            var result:[UIImage?]=Array(repeating:nil,count:5)
            for i in 0..<5 {
                if Task.isCancelled {return}
                let at=seconds*(Double(i)+0.5)/5
                result[i]=try? await VideoFrameService.frame(at:at,from:url)
            }
            if store.videoURL==url {frames=result}
        }
    }
}
