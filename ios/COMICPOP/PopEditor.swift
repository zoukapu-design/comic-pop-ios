import AVKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// First reference screen: functional video editor and 4x2 comic card studio.
/// No full-screen image and no fake video timeline.
struct PopEditorScreen: View {
    @ObservedObject var store: StudioStore
    var proceed: () -> Void
    var changeVideo: () -> Void
    @State private var fullScreen = false
    @State private var showDeck = false
    @State private var showRemoveAll = false
    @State private var askDiscardDraft = false
    @State private var pendingDraftAction:DraftAction?
    @State private var editingPin:MangaPin?

    private enum DraftAction {
        case insert(PinDefinition)
        case delete(MangaPin)
        case deleteAll
    }
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
        store.videoURL != nil && card(selectedID) != nil &&
            MangaSceneCapacity.canInsert(into:store.data.pins,at:store.currentTime) &&
            !store.isAddingPin && !store.isGenerating
    }

    var body: some View {
        ScrollView(showsIndicators:false) {
            VStack(alignment:.leading,spacing:11) {
                videoPreview
                playbackControls
                PopTimeline(store:store,onDelete:requestDelete)
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
        .sheet(item:$editingPin) { pin in
            PopPinStorySheet(store:store,pin:pin)
        }
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
        .confirmationDialog("すべての挿入カードを削除しますか？",isPresented:$showRemoveAll) {
            Button("すべて削除",role:.destructive) {store.clearPins()}
            Button("キャンセル",role:.cancel) {}
        }
        .confirmationDialog("現在の生成結果とAI脚本を破棄しますか？",
                            isPresented:$askDiscardDraft,titleVisibility:.visible) {
            Button("生成結果を破棄してカードを編集",role:.destructive) {
                guard !store.isGenerating,let action=pendingDraftAction else {return}
                pendingDraftAction=nil
                switch action {
                case .insert(let definition):
                    Task {await store.addPin(card:definition,allowDiscard:true)}
                case .delete(let pin):
                    store.removePin(pin,allowDiscard:true)
                case .deleteAll:
                    store.clearPins(allowDiscard:true)
                }
            }
            Button("キャンセル",role:.cancel) {pendingDraftAction=nil}
        } message: {
            Text("新しいカード構成で漫画を作り直します。作成途中の画像とAI脚本は破棄されます。保存済みの作品・元動画・マイデッキは残ります。")
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
            Button(action:changeVideo) {
                Label(store.videoURL == nil ? "動画を選ぶ" : "動画を変更",
                      systemImage:"play.rectangle.on.rectangle")
                    .font(.system(size:11,weight:.bold))
                    .foregroundStyle(PopColor.ink)
                    .padding(.horizontal,10).padding(.vertical,8)
                    .background(PopColor.yellow,in:Capsule())
            }
            .buttonStyle(.plain)
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
                                .disabled(store.isAddingPin || store.isGenerating)
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
                    PopYellowButton(title:store.isAddingPin ? "挿入中…" : "＋ 挿入",
                                    icon:"plus",enabled:canInsert) {
                        if let def=card(selectedID) {selectAndInsert(def)}
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
                    Text("挿入カード \(store.data.pins.count)枚 / \(store.scenePlan.renderedPanelCount)シーン")
                        .font(.system(size:14,weight:.black,design:.rounded))
                        .foregroundStyle(PopColor.ink)
                    Spacer()
                    Button("全削除",role:.destructive) {
                        if store.hasUncommittedGeneration {
                            pendingDraftAction = .deleteAll
                            askDiscardDraft = true
                        } else {showRemoveAll=true}
                    }
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
                        Button {editingPin=pin} label:{
                            Image(systemName:"pencil.line")
                        }
                        .accessibilityLabel("カードのストーリーとセリフを指定")
                        Button(role:.destructive) {requestDelete(pin)} label:{
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
        guard !store.isAddingPin && !store.isGenerating else {return}
        guard store.videoURL != nil else {
            store.message="先に動画を選んでください"
            return
        }
        guard MangaSceneCapacity.canInsert(into:store.data.pins,at:store.currentTime) else {
            store.message="この動画は最大12シーン、同じシーンは3カードまでです。カードの時刻か構成を調整してください。"
            return
        }
        if store.hasUncommittedGeneration {
            pendingDraftAction = .insert(definition)
            askDiscardDraft = true
        } else {
            Task {await store.addPin(card:definition)}
        }
    }
    private func requestDelete(_ pin:MangaPin) {
        guard !store.isGenerating else {return}
        if store.hasUncommittedGeneration {
            pendingDraftAction = .delete(pin)
            askDiscardDraft = true
        } else {
            store.removePin(pin)
        }
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
/// Displays actual saved pin positions, not decorative icons. The yellow
/// thumbnail ticks mark every stored pin; image-card markers group only pins
/// which would overlap on a narrow phone.
private struct PopTimeline: View {
    @ObservedObject var store: StudioStore
    let onDelete:(MangaPin)->Void
    @State private var frames: [UIImage?] = Array(repeating:nil,count:5)
    @State private var focusedPinID: UUID?
    @State private var pendingCluster: TimelinePinCluster?

    private var focusedPin: MangaPin? {
        guard let focusedPinID else { return nil }
        return store.data.pins.first(where: { $0.id == focusedPinID })
    }

    var body: some View {
        VStack(spacing:5) {
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

            if store.duration > 0 && !store.data.pins.isEmpty {
                markerTrack
            }

            GeometryReader { geo in
                ZStack(alignment:.leading) {
                    HStack(spacing:2) {
                        ForEach(0..<5,id:\.self) { i in
                            ZStack {
                                if let img=frames[i] {
                                    Image(uiImage:img).resizable().scaledToFill()
                                } else {
                                    PopColor.royal.overlay(
                                        Image(systemName:"film").foregroundStyle(.white.opacity(0.27))
                                    )
                                }
                            }
                            .frame(width:(geo.size.width-8)/5,height:42)
                            .clipped().clipShape(RoundedRectangle(cornerRadius:5))
                        }
                    }

                    // A thin tick marks EVERY individual card at its exact time,
                    // even when the larger cards above are grouped for legibility.
                    ForEach(store.scenePlan.orderedPins) { pin in
                        Rectangle().fill(PopColor.yellow)
                            .frame(width:2,height:42)
                            .offset(x:CGFloat(max(0,min(1,pin.seconds/max(0.01,store.duration)))) *
                                    max(0,geo.size.width-2))
                    }
                    Rectangle().fill(PopColor.yellow)
                        .frame(width:3,height:46)
                        .offset(x:CGFloat(max(0,min(1,store.currentTime/max(0.01,store.duration)))) *
                                max(0,geo.size.width-3))
                }
            }
            .frame(height:44)

            if let pin=focusedPin {
                HStack(spacing:6) {
                    Image(systemName:"bookmark.fill").foregroundStyle(PopColor.yellow)
                    Text("\(store.formatted(pin.seconds)) に「\(store.card(for:pin).title)」")
                        .font(.system(size:11,weight:.heavy,design:.rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength:4)
                    Button {
                        onDelete(pin)
                        focusedPinID = nil
                    } label: {
                        Label("削除",systemImage:"trash")
                            .font(.system(size:11,weight:.bold))
                    }
                    .accessibilityLabel("\(store.card(for:pin).title) の挿入カードを削除")
                }
                .foregroundStyle(.white)
                .padding(.horizontal,9).padding(.vertical,8)
                .background(PopColor.navy.opacity(0.86),
                            in:RoundedRectangle(cornerRadius:10))
                .overlay(RoundedRectangle(cornerRadius:10)
                    .stroke(PopColor.edge.opacity(0.8),lineWidth:1))
            }
        }
        .confirmationDialog(
            "この位置に挿入したカード",
            isPresented:Binding(
                get:{pendingCluster != nil},
                set:{if !$0 {pendingCluster = nil}}
            ),
            titleVisibility:.visible
        ) {
            if let group=pendingCluster {
                ForEach(group.points) { point in
                    if let pin=store.data.pins.first(where:{$0.id == point.id}) {
                        Button("\(store.formatted(pin.seconds)) · \(store.card(for:pin).title)") {
                            jump(to:pin)
                            pendingCluster = nil
                        }
                    }
                }
            }
            Button("キャンセル",role:.cancel) {pendingCluster=nil}
        } message: {
            Text("見たいカードを選ぶと、挿入した動画の位置に移動します。")
        }
        .onChange(of:store.videoURL?.absoluteString) { _,_ in
            focusedPinID = nil
            pendingCluster = nil
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

    private var markerTrack: some View {
        GeometryReader { geo in
            let points=store.scenePlan.orderedPins.map {
                TimelinePinPoint(id:$0.id,seconds:$0.seconds)
            }
            let clusters=TimelinePinLayout.clusters(
                points:points,duration:store.duration,width:Double(geo.size.width)
            )

            ZStack(alignment:.topLeading) {
                ForEach(clusters) { group in
                    if let first=group.points.first,
                       let pin=store.data.pins.first(where:{$0.id == first.id}) {
                        Button {
                            if group.count == 1 {
                                jump(to:pin)
                            } else {
                                pendingCluster = group
                            }
                        } label: {
                            VStack(spacing:1) {
                                ZStack(alignment:.topTrailing) {
                                    PopArtwork(kind:.cards,index:artIndex(for:pin))
                                        .frame(width:27,height:25)
                                        .clipShape(RoundedRectangle(cornerRadius:5))
                                    if group.count > 1 {
                                        Text("\(group.count)")
                                            .font(.system(size:9,weight:.black,design:.rounded))
                                            .foregroundStyle(PopColor.ink)
                                            .frame(minWidth:15,minHeight:15)
                                            .background(PopColor.yellow,in:Circle())
                                            .overlay(Circle().stroke(.white,lineWidth:1))
                                            .offset(x:8,y:-4)
                                    }
                                }
                                Text(group.count > 1
                                     ? "\(group.count)枚"
                                     : shortName(for:pin))
                                    .font(.system(size:9,weight:.black,design:.rounded))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.65)
                                    .foregroundStyle(PopColor.ink)
                                    .frame(width:44)
                                Image(systemName:"arrowtriangle.down.fill")
                                    .font(.system(size:7,weight:.heavy))
                                    .foregroundStyle(PopColor.yellow)
                            }
                            .padding(.top,3)
                            .frame(width:48,height:50)
                            .background(.white,in:RoundedRectangle(cornerRadius:9))
                            .overlay(RoundedRectangle(cornerRadius:9)
                                .stroke(focusedPinID == pin.id ? PopColor.yellow : PopColor.edge,
                                        lineWidth:focusedPinID == pin.id ? 3 : 1.6))
                            .shadow(color:PopColor.navy.opacity(0.3),radius:3,y:1)
                        }
                        .buttonStyle(.plain)
                        .position(x:CGFloat(group.centerX),y:26)
                        .accessibilityLabel(
                            group.count > 1
                                ? "\(store.formatted(pin.seconds)) 付近にカード\(group.count)枚。タップして選択"
                                : "\(store.formatted(pin.seconds)) に\(store.card(for:pin).title)。タップで動画へ移動"
                        )
                        .accessibilityIdentifier("timelinePinMarker")
                    }
                }
            }
            .frame(height:52)
        }
        .frame(height:52)
        .accessibilityIdentifier("timelineInsertedCardMarkers")
    }

    private func jump(to pin:MangaPin) {
        store.scrub(to:pin.seconds)
        focusedPinID=pin.id
    }

    /// The marker itself is intentionally short on iPhone; the full name is
    /// available by tapping the marker or in the inserted-card list.
    private func shortName(for pin:MangaPin) -> String {
        switch pin.cardID {
        case "dramatic":return "ドラマ"
        case "tsukkomi":return "ツッコミ"
        case "idea":return "ひらめき"
        case "sad":return "しんみり"
        default:return String(store.card(for:pin).title.prefix(4))
        }
    }

    private func artIndex(for pin:MangaPin)->Int {
        switch pin.cardID {
        case "intro":return 0
        case "slow":return 1
        case "dramatic":return 2
        case "tsukkomi":return 3
        case "idea":return 4
        case "sad":return 5
        case "large":return 6
        case "punch", "ending":return 7
        default:return max(0,store.card(for:pin).art) % 8
        }
    }
}
