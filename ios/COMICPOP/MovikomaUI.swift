import AVKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

// MOVIKOMA native UI.  The illustrations are cropped from the approved reference
// art sheet; all controls, video playback and generation remain native views.
private enum MVTheme {
    static let navy = Color(red: 0.075, green: 0.091, blue: 0.17)
    static let dark = Color(red: 0.12, green: 0.15, blue: 0.25)
    static let panel = Color(red: 0.17, green: 0.20, blue: 0.31)
    static let yellow = Color(red: 1, green: 0.85, blue: 0.19)
    static let paper = Color(red: 1, green: 0.98, blue: 0.94)
}

private enum MVTab: Int, CaseIterable {
    case editor, manga, works, settings
    var title: String {
        switch self { case .editor: return "編集"; case .manga: return "マンガ生成"; case .works: return "作品"; case .settings: return "設定" }
    }
    var icon: String {
        switch self { case .editor: return "film.stack.fill"; case .manga: return "sparkles"; case .works: return "books.vertical.fill"; case .settings: return "gearshape.fill" }
    }
}

struct MovikomaRootView: View {
    @StateObject private var store = StudioStore()
    @State private var tab: MVTab = .editor
    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case .editor: MVEditorView(store: store, goToManga: { tab = .manga })
                case .manga: MVMangaView(store: store, goToEditor: { tab = .editor }, goToWorks: { tab = .works })
                case .works: MVWorksView(store: store)
                case .settings: MVSettingsView(store: store)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 0) {
                ForEach(MVTab.allCases, id: \.rawValue) { item in
                    Button { tab = item } label: {
                        VStack(spacing: 4) {
                            Image(systemName: item.icon).font(.system(size: 20, weight: .semibold))
                            Text(item.title).font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(tab == item ? MVTheme.yellow : .white.opacity(0.75))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(tab == item ? MVTheme.yellow.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 13))
                    }.buttonStyle(.plain).accessibilityAddTraits(tab == item ? .isSelected : [])
                }
            }
            .padding(.horizontal, 8).padding(.top, 6).padding(.bottom, 4)
            .background(MVTheme.navy)
        }
        .background(MVTheme.navy.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

private struct MVBrand: View {
    var body: some View {
        HStack(alignment: .center, spacing: 7) {
            Image(systemName: "film.stack.fill").font(.system(size: 29, weight: .bold)).foregroundStyle(MVTheme.yellow)
            VStack(alignment: .leading, spacing: -2) {
                Text("ムビコマ").font(.system(size: 30, weight: .black, design: .rounded)).italic()
                Text("M O V I K O M A").font(.system(size: 9, weight: .black)).tracking(1.4).foregroundStyle(MVTheme.yellow)
            }
            Spacer()
        }
        .foregroundStyle(.white)
    }
}

private struct MVHero: View {
    var text: String
    var rexTile: Int
    var body: some View {
        HStack(spacing: 4) {
            Text(text).font(.system(size: 16, weight: .black)).multilineTextAlignment(.center)
                .foregroundStyle(MVTheme.navy).padding(13)
                .background(.white, in: RoundedRectangle(cornerRadius: 33))
                .overlay(RoundedRectangle(cornerRadius: 33).stroke(MVTheme.navy, lineWidth: 2))
                .frame(maxWidth: .infinity)
            MVSprite(tile: rexTile).frame(width: 138, height: 135)
                .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .padding(.top, 4)
        .background(LinearGradient(colors: [MVTheme.navy, MVTheme.panel], startPoint: .top, endPoint: .bottom))
    }
}

private struct MVPrimaryButton: View {
    var title: String
    var icon: String
    var enabled: Bool = true
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(MVTheme.navy)
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(enabled ? MVTheme.yellow : Color.gray, in: Capsule())
                .overlay(Capsule().stroke(MVTheme.paper.opacity(0.65), lineWidth: 1))
        }.buttonStyle(.plain).disabled(!enabled)
    }
}

private struct MVEditorView: View {
    @ObservedObject var store: StudioStore
    var goToManga: () -> Void
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var filePicker = false
    @State private var showCatalog = false
    @State private var showDeck = false
    @State private var showClear = false
    @State private var selectedCardID: String?
    private var selectedCard: PinDefinition? {
        let firstID = selectedCardID ?? store.selectedDeck?.cardIDs.first
        return store.cards.first(where: { $0.id == firstID })
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 13) {
                MVBrand()
                MVHero(text: "動画を見ながら\nカードを刺して\nマンガの流れを\n作ろう！", rexTile: 7)
                Group {
                    if store.videoURL != nil {
                        VideoPlayer(player: store.player)
                            .frame(maxWidth: .infinity).aspectRatio(16 / 9, contentMode: .fit)
                            .background(.black)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "play.rectangle.fill").font(.system(size: 46)).foregroundStyle(MVTheme.yellow)
                            Text("まず動画を選ぼう").font(.headline)
                            Text("好きな場面にカードを刺してマンガに変換").font(.caption).foregroundStyle(.white.opacity(0.72))
                        }
                        .frame(maxWidth: .infinity).frame(height: 200)
                        .background(MVTheme.panel)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 17))
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.42), lineWidth: 2))
                HStack(spacing: 10) {
                    PhotosPicker(selection: $selectedPhoto, matching: .videos) {
                        Label("動画を選ぶ", systemImage: "photo.on.rectangle.angled")
                    }
                    Button { filePicker = true } label: { Label("ファイル", systemImage: "folder") }
                    Spacer(minLength: 2)
                    Text("\(store.formatted(store.currentTime)) / \(store.formatted(store.duration))")
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(.white.opacity(0.84))
                }
                .buttonStyle(.bordered)
                MVTimelineView(store: store)
                HStack {
                    Label("挿入済みカード：\(store.data.pins.count)枚", systemImage: "pin.fill").font(.subheadline.bold())
                    Spacer()
                    Button("全削除", role: .destructive) { showClear = true }
                        .font(.caption.bold()).disabled(store.data.pins.isEmpty)
                }
                if !store.data.pins.isEmpty {
                    ForEach(store.scenePlan.orderedPins) { pin in
                        HStack(spacing: 9) {
                            if let snap = store.snapshot(for: pin) {
                                Image(uiImage: snap).resizable().scaledToFill().frame(width: 63, height: 53).clipped().cornerRadius(7)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(store.card(for: pin).title).font(.subheadline.bold())
                                Text(store.formatted(pin.seconds)).font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.7))
                            }
                            Spacer()
                            Button { store.scrub(to: pin.seconds) } label: { Image(systemName: "play.circle") }
                            Button(role: .destructive) { store.removePin(pin) } label: { Image(systemName: "trash") }
                        }
                        .padding(8).background(MVTheme.panel, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                if store.data.pins.count > 0 {
                    Button { goToManga() } label: {
                        Label("画風を選んでマンガ生成へ", systemImage: "arrow.right.circle.fill")
                            .font(.headline).frame(maxWidth: .infinity).padding(12)
                    }.tint(MVTheme.yellow).foregroundStyle(MVTheme.navy).buttonStyle(.borderedProminent)
                }
                Text(store.message).font(.caption).foregroundStyle(.white.opacity(0.7))
            }
            .padding(14)
        }
        .background(MVTheme.navy)
        .safeAreaInset(edge: .bottom) { cardDock }
        .sheet(isPresented: $showCatalog) { MVCatalogView(store: store, onSelect: { selectedCardID = $0; showCatalog = false }) }
        .sheet(isPresented: $showDeck) { MVDeckView(store: store) }
        .confirmationDialog("ピンカードをすべて削除しますか？", isPresented: $showClear) {
            Button("すべて削除", role: .destructive) { store.clearPins() }
        }
        .fileImporter(isPresented: $filePicker, allowedContentTypes: [.movie], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first { Task { await store.replaceVideo(url) } }
        }
        .onChange(of: store.data.activeDeckID) { _, _ in selectedCardID = nil }
        .onChange(of: selectedPhoto) { _, next in
            guard let next else { return }
            Task {
                do {
                    if let movie = try await next.loadTransferable(type: MovieImport.self) {
                        await store.replaceVideo(movie.url)
                    }
                } catch { store.message = "動画選択エラー：\(error.localizedDescription)" }
            }
        }
    }
    // Fixed card dock: editing video, timeline and pin history may scroll, but
    // the selected card and insertion action remain reachable during playback.
    private var cardDock: some View {
        VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("カードを追加").font(.headline).foregroundStyle(.white)
                    Spacer()
                    Button { showDeck = true } label: { Label(store.selectedDeck?.name ?? "マイデッキ", systemImage: "square.stack.3d.up") }
                        .font(.caption.bold())
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(store.selectedDeck?.cardIDs ?? [], id: \.self) { id in
                            if let def = store.cards.first(where: { $0.id == id }) {
                                Button { selectedCardID = def.id } label: {
                                    MVCardView(card: def, selected: selectedCard?.id == def.id, compact: true)
                                }.buttonStyle(.plain)
                            }
                        }
                        Button { showCatalog = true } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill").font(.title)
                                Text("全カード").font(.caption2.bold())
                            }.frame(width: 82, height: 92)
                                .background(MVTheme.panel, in: RoundedRectangle(cornerRadius: 13))
                        }.buttonStyle(.plain)
                    }
                    .padding(.vertical, 3)
                }
                MVPrimaryButton(title: "今の位置にカードを刺す", icon: "plus") {
                    if let card = selectedCard { Task { await store.addPin(card: card) } }
                }
                .disabled(store.videoURL == nil || selectedCard == nil)
                .opacity(store.videoURL == nil || selectedCard == nil ? 0.55 : 1)
            if let chosen = selectedCard,
               !(store.selectedDeck?.cardIDs.contains(chosen.id) ?? false) {
                Label("選択中：\(chosen.title)", systemImage: "checkmark.circle.fill")
                    .font(.caption2.bold()).foregroundStyle(MVTheme.yellow)
            }
        }
        .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 5)
        .frame(maxWidth: .infinity)
        .background(MVTheme.dark)
        .overlay(alignment: .top) { Rectangle().fill(MVTheme.yellow.opacity(0.55)).frame(height: 1) }
    }
}

private struct MVTimelineView: View {
    @ObservedObject var store: StudioStore
    // Keep a fixed five-slot timeline so a failed frame capture does not shift later frames.
    @State private var thumbnails: [UIImage?] = Array(repeating: nil, count: 5)
    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8).fill(MVTheme.panel)
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { i in
                            if thumbnails.indices.contains(i), let thumb = thumbnails[i] {
                                Image(uiImage: thumb).resizable().scaledToFill().frame(maxWidth: .infinity).frame(height: 49).clipped()
                            } else {
                                RoundedRectangle(cornerRadius: 2).fill(MVTheme.dark.opacity(0.9))
                                    .overlay(Image(systemName: "film").foregroundStyle(.white.opacity(0.25)))
                            }
                        }
                    }
                    .frame(height: 49).clipShape(RoundedRectangle(cornerRadius: 8))
                    ForEach(store.scenePlan.orderedPins) { pin in
                        let ratio = CGFloat(pin.seconds / max(1, store.duration))
                        Rectangle().fill(MVTheme.yellow).frame(width: 2, height: 51)
                            .offset(x: max(0, min(geo.size.width - 2, geo.size.width * ratio)))
                    }
                    Rectangle().fill(Color.orange).frame(width: 3, height: 56)
                        .offset(x: max(0, min(geo.size.width - 3, geo.size.width * CGFloat(store.currentTime / max(1, store.duration)))))
                }
            }.frame(height: 53)
            Slider(value: Binding(get: { min(store.currentTime, max(store.duration, 0.01)) }, set: { store.scrub(to: $0) }), in: 0...max(store.duration, 0.01))
                .tint(MVTheme.yellow).disabled(store.duration <= 0)
            HStack(spacing: 5) {
                timelineStep("−5s", -5)
                timelineStep("−1s", -1)
                Button { store.playPause() } label: {
                    Image(systemName: store.player.rate > 0 ? "pause.fill" : "play.fill")
                        .font(.headline).frame(minWidth: 48)
                }.buttonStyle(.borderedProminent).tint(MVTheme.yellow).foregroundStyle(MVTheme.navy)
                    .disabled(store.videoURL == nil)
                timelineStep("+1s", 1)
                timelineStep("+5s", 5)
            }.frame(maxWidth: .infinity)
        }
        .task(id: "\(store.videoURL?.absoluteString ?? "-")|\(store.duration)") {
            thumbnails = Array(repeating: nil, count: 5)
            guard let url = store.videoURL else { return }
            var images: [UIImage?] = Array(repeating: nil, count: 5)
            for i in 0..<5 {
                if Task.isCancelled { return }
                let t = max(0, store.duration * (Double(i) + 0.5) / 5.0)
                if let image = try? await VideoFrameService.frame(at: t, from: url) {
                    images[i] = image
                }
            }
            if store.videoURL == url { thumbnails = images }
        }
    }
    private func timelineStep(_ title: String, _ delta: Double) -> some View {
        Button(title) { store.seek(by: delta) }
            .font(.system(size: 12, weight: .bold)).buttonStyle(.bordered)
            .disabled(store.videoURL == nil)
    }
}

private struct MVCardView: View {
    let card: PinDefinition
    let selected: Bool
    var compact: Bool = false
    private var tile: Int {
        let value = card.title + " " + card.id
        if value.contains("驚") || value.contains("リアクション") || value.contains("反応") { return 1 }
        if value.contains("アクション") || value.contains("動") || value.contains("パンチ") { return 3 }
        if value.contains("説明") || value.contains("料理") { return 2 }
        if value.contains("感情") || value.contains("笑") || value.contains("感動") { return 4 }
        if value.contains("転") || value.contains("場面") { return 5 }
        if value.contains("結") || value.contains("オチ") { return 15 }
        return 0
    }
    var body: some View {
        VStack(spacing: 4) {
            MVSprite(tile: tile).frame(height: compact ? 53 : 78).clipped().cornerRadius(8)
            Text(card.title).font(.system(size: compact ? 11 : 13, weight: .black)).foregroundStyle(MVTheme.navy).lineLimit(1)
            Text(card.subtitle).font(.system(size: compact ? 9 : 10)).foregroundStyle(MVTheme.navy.opacity(0.77)).lineLimit(1)
        }
        .padding(compact ? 4 : 6).frame(width: compact ? 84 : 112, height: compact ? 96 : 129)
        .background(.white, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(selected ? MVTheme.yellow : Color.white.opacity(0.5), lineWidth: selected ? 4 : 1))
        .shadow(color: selected ? MVTheme.yellow.opacity(0.4) : .clear, radius: 8)
    }
}

private struct MVMangaView: View {
    @ObservedObject var store: StudioStore
    var goToEditor: () -> Void
    var goToWorks: () -> Void
    @State private var confirmRun = false
    @State private var previewPage = 0
    @State private var showReview = false
    private let styles: [(String, String, String, Int)] = [
        ("shonen", "熱血少年マンガ", "バトル・成長・友情", 8),
        ("shojo", "少女マンガ", "恋・青春・ドラマ", 9),
        ("american", "アメコミ風", "ヒーロー・迫力", 10),
        ("daily", "日常・ほのぼの", "くらし・癒やし", 11),
        ("suspense", "サスペンス", "ミステリー・緊張感", 12),
        ("fantasy", "ファンタジー", "冒険・魔法・異世界", 13),
        ("gag", "ギャグ漫画", "コミカル・表情", 1),
        ("horror", "ホラー漫画", "不安・恐怖", 12),
        ("retro", "レトロ漫画", "懐かしさ", 12),
        ("kids", "児童漫画", "かわいく楽しい", 11)
    ]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(store.pageImages.isEmpty ? "マンガ生成" : (store.hasCompleteComic ? "生成結果" : "途中まで生成"))
                        .font(.system(size: 22, weight: .heavy))
                    Spacer()
                    Text("ムビコマ").font(.caption.bold()).foregroundStyle(MVTheme.yellow)
                }.foregroundStyle(.white)
                if store.pageImages.isEmpty { generationView }
                else { resultView }
                if !store.message.isEmpty {
                    Text(store.message).font(.caption).foregroundStyle(.white.opacity(0.74))
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(MVTheme.panel, in: RoundedRectangle(cornerRadius: 10))
                }
            }.padding(14)
        }
        .background(MVTheme.navy)
        .confirmationDialog("自分のCloudflare Workers Free枠で生成しますか？", isPresented: $confirmRun) {
            Button("マンガを生成する") { Task { await store.generate(); previewPage = 0 } }
        } message: {
            Text("動画から保存したフレームをCloudflareへ送信します。Workers Paid契約では利用料金がかかる場合があります。自動的に有料サービスへ切り替えません。")
        }
        .sheet(isPresented: $showReview) { MVPanelReview(store: store) }
    }
    private var generationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            MVHero(text: "どんなマンガに\nする？\n画風を選んでね！", rexTile: 14)
            HStack {
                Text("画風（ジャンル）を選ぶ").font(.headline)
                Spacer()
                Text("\(store.data.pins.count)カード / \(store.scenePlan.pages)ページ")
                    .font(.caption.bold()).foregroundStyle(MVTheme.yellow)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(styles.indices, id: \.self) { i in
                    let item = styles[i]
                    Button { store.updateStyle(item.0) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            MVSprite(tile: item.3).frame(height: 103).clipped().cornerRadius(9)
                            Text(item.1).font(.system(size: 14, weight: .black)).foregroundStyle(MVTheme.navy)
                            Text(item.2).font(.system(size: 10)).foregroundStyle(MVTheme.navy.opacity(0.72))
                        }
                        .padding(7).frame(maxWidth: .infinity, alignment: .leading)
                        .background(MVTheme.paper, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(store.data.style == item.0 ? MVTheme.yellow : Color.clear, lineWidth: 4))
                        .overlay(alignment: .topTrailing) {
                            if store.data.style == item.0 {
                                Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(MVTheme.yellow).padding(6)
                            }
                        }
                    }.buttonStyle(.plain).disabled(store.isGenerating)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("表現の設定").font(.headline).foregroundStyle(MVTheme.navy)
                TextField("マンガのタイトル", text: Binding(get: { store.titleDraft }, set: { store.updateTitle($0) }))
                    .textFieldStyle(.roundedBorder).foregroundStyle(MVTheme.navy)
                HStack {
                    colorButton("白黒マンガ", "mono", "book.closed")
                    colorButton("カラー漫画", "color", "paintpalette")
                }
                Text("コマ数の目安：1ページ4コマ / 挿入カードは省略しません")
                    .font(.caption).foregroundStyle(MVTheme.navy.opacity(0.7))
            }
            .padding(13).background(MVTheme.paper, in: RoundedRectangle(cornerRadius: 13))
            MVPrimaryButton(title: store.isGenerating ? "マンガを生成中…" : "マンガを生成する", icon: "sparkles", enabled: !store.isGenerating && !store.data.pins.isEmpty) {
                confirmRun = true
            }
            Button {
                Task { await store.generateOffline(); previewPage = 0 }
            } label: {
                Label("無料でおためし生成（端末内）", systemImage: "wand.and.stars")
                    .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(10)
            }
            .buttonStyle(.bordered).tint(.white)
            .disabled(store.isGenerating || store.data.pins.isEmpty)
            if store.isGenerating { ProgressView().tint(MVTheme.yellow).frame(maxWidth: .infinity) }
            Text("AI作画は自分のCloudflare Workers Free枠を使用します（設定から接続）。端末内おためし生成はAIではなく漫画調フィルターで、動画を外部送信しません。")
                .font(.caption2).foregroundStyle(.white.opacity(0.75))
        }
    }
    private func colorButton(_ label: String, _ value: String, _ icon: String) -> some View {
        Button { store.updateColor(value) } label: {
            Label(label, systemImage: icon).font(.system(size: 12, weight: .bold))
                .foregroundStyle(MVTheme.navy).frame(maxWidth: .infinity).padding(9)
                .background(store.data.colorMode == value ? MVTheme.yellow : .white, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(MVTheme.navy.opacity(0.22)))
        }.buttonStyle(.plain).disabled(store.isGenerating)
    }
    private var resultView: some View {
        VStack(spacing: 14) {
            if !store.pageImages.isEmpty {
                if !store.hasCompleteComic {
                    VStack(spacing: 9) {
                        Label("まだ完成していません", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline).foregroundStyle(MVTheme.yellow)
                        Text("\(store.generatedPanelCount) / \(store.data.pins.count) コマ生成済み。完成まで保存はできません。")
                            .font(.subheadline).multilineTextAlignment(.center)
                        MVPrimaryButton(title: store.isGenerating ? "生成しています…" : "残りのコマを生成", icon: "arrow.clockwise", enabled: !store.isGenerating) {
                            if store.generatedOffline {
                                Task { await store.generateOffline(); previewPage = 0 }
                            } else {
                                confirmRun = true
                            }
                        }
                    }
                    .padding(13).frame(maxWidth: .infinity)
                    .background(MVTheme.panel, in: RoundedRectangle(cornerRadius: 14))
                }
                Text(store.generatedOffline ? "端末内・簡易漫画調（生成AIなし）" : "Cloudflare AI・漫画化結果")
                    .font(.caption.bold()).foregroundStyle(MVTheme.yellow)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(uiImage: store.pageImages[min(previewPage, store.pageImages.count - 1)])
                    .resizable().scaledToFit()
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                HStack(spacing: 20) {
                    Button { previewPage = max(0, previewPage - 1) } label: { Image(systemName: "chevron.left.circle.fill") }
                        .disabled(previewPage == 0)
                    Text("\(min(previewPage + 1, store.pageImages.count)) / \(store.pageImages.count)")
                        .font(.headline.monospacedDigit())
                    Button { previewPage = min(store.pageImages.count - 1, previewPage + 1) } label: { Image(systemName: "chevron.right.circle.fill") }
                        .disabled(previewPage >= store.pageImages.count - 1)
                }.foregroundStyle(.white)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(store.pageImages.indices, id: \.self) { i in
                            Button { previewPage = i } label: {
                                Image(uiImage: store.pageImages[i]).resizable().scaledToFit()
                                    .frame(width: 64, height: 89)
                                    .background(.white)
                                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(i == previewPage ? MVTheme.yellow : .clear, lineWidth: 4))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                HStack(spacing: 8) {
                    Button { showReview = true } label: { Label("編集", systemImage: "pencil") }
                    Button { store.discardGenerated(); previewPage = 0 } label: { Label("最初から再生成", systemImage: "arrow.clockwise") }
                        .disabled(store.isGenerating)
                    Button { if store.saveWork() { goToWorks() } } label: { Label("保存・共有", systemImage: "square.and.arrow.up") }
                        .tint(MVTheme.yellow).foregroundStyle(MVTheme.navy)
                        .disabled(!store.hasCompleteComic)
                }.font(.system(size: 12, weight: .bold)).buttonStyle(.borderedProminent)
                Button("動画の編集に戻る") { goToEditor() }.font(.footnote)
            }
        }
    }
}

private struct MVPanelReview: View {
    @ObservedObject var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 13) {
                    Text("各コマを元動画と比較。問題がある場合は元画像に戻せます。")
                        .font(.subheadline)
                    ForEach(store.generated) { panel in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(panel.cardTitle).font(.headline)
                            HStack {
                                VStack { Image(uiImage: panel.original).resizable().scaledToFit(); Text("元動画") }
                                VStack { Image(uiImage: panel.drawing).resizable().scaledToFit(); Text(store.generatedOffline ? "端末内漫画調" : "AI再描画") }
                            }.font(.caption).frame(height: 165)
                            if let warning = panel.warning { Text(warning).font(.caption).foregroundStyle(.orange) }
                            Button("このコマは元動画を使う") { store.chooseOriginal(panel.id) }
                        }.padding(10).background(MVTheme.panel, in: RoundedRectangle(cornerRadius: 12))
                    }
                }.padding()
            }
            .navigationTitle("コマを確認・編集")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完了") { dismiss() } } }
        }
    }
}

// The card library uses the same Rex artwork as the editor. Selecting a card
// returns to the timeline rather than inserting an unrelated timestamp.
private struct MVCatalogView: View {
    @ObservedObject var store: StudioStore
    var onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var category = "all"
    private let categories: [(String, String)] = [
        ("all", "すべて"), ("story", "物語"), ("feeling", "感情"),
        ("scene", "演出"), ("character", "キャラ"), ("editing", "編集")
    ]
    private var filtered: [PinDefinition] {
        store.cards.filter {
            (category == "all" || $0.category == category) &&
            (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.subtitle.localizedCaseInsensitiveContains(query))
        }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("使いたいカードを選んでね！")
                        .font(.headline).foregroundStyle(MVTheme.yellow)
                    TextField("カード名・キーワードで探す", text: $query)
                        .textFieldStyle(.roundedBorder)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories.indices, id: \.self) { index in
                                let item = categories[index]
                                Button(item.1) { category = item.0 }
                                    .font(.caption.bold())
                                    .padding(.horizontal, 13).padding(.vertical, 9)
                                    .background(category == item.0 ? MVTheme.yellow : MVTheme.panel, in: Capsule())
                                    .foregroundStyle(category == item.0 ? MVTheme.navy : .white)
                            }
                        }
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 115))], spacing: 12) {
                        ForEach(filtered) { card in
                            Button { onSelect(card.id); dismiss() } label: {
                                MVCardView(card: card, selected: false)
                                    .frame(maxWidth: .infinity)
                            }.buttonStyle(.plain)
                        }
                    }
                    Text("カードを選択して編集画面に戻り、現在時刻へ挿入します。")
                        .font(.footnote).foregroundStyle(.white.opacity(0.7))
                }.padding(14)
            }
            .background(MVTheme.navy)
            .navigationTitle("レックスのカード図鑑")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}

private struct MVDeckView: View {
    @ObservedObject var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var deckName = ""
    @State private var query = ""
    private var filtered: [PinDefinition] {
        store.cards.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    Text("よく使うカードを12枚まで登録できます")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.78))
                    if !store.data.decks.isEmpty {
                        Picker("マイデッキ", selection: Binding(
                            get: { store.selectedDeck?.id ?? store.data.decks[0].id },
                            set: { store.selectDeck($0) }
                        )) {
                            ForEach(store.data.decks) { deck in Text(deck.name).tag(deck.id) }
                        }.tint(MVTheme.yellow)
                    }
                    HStack {
                        TextField("新しいデッキ", text: $deckName).textFieldStyle(.roundedBorder)
                        Button("作成") {
                            store.addDeck(name: deckName.isEmpty ? "新しいデッキ" : deckName)
                            deckName = ""
                        }.disabled(store.data.decks.count >= 20)
                    }
                    if let deck = store.selectedDeck {
                        HStack {
                            Text("\(deck.name)：\(deck.cardIDs.count)/12枚").font(.headline)
                            Spacer()
                            Button("削除", role: .destructive) { store.deleteDeck(deck.id) }
                                .disabled(store.data.decks.count <= 1)
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(deck.cardIDs, id: \.self) { id in
                                    if let card = store.cards.first(where: { $0.id == id }) {
                                        VStack {
                                            MVCardView(card: card, selected: true)
                                            HStack {
                                                Button { store.moveDeckCard(id, by: -1) } label: { Image(systemName: "arrow.left") }
                                                Button { store.moveDeckCard(id, by: 1) } label: { Image(systemName: "arrow.right") }
                                                Button(role: .destructive) { store.toggleDeckCard(id) } label: { Image(systemName: "minus.circle") }
                                            }.buttonStyle(.bordered).font(.caption)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Divider()
                    Text("デッキに追加するカード").font(.headline)
                    TextField("カードを検索", text: $query).textFieldStyle(.roundedBorder)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 115))], spacing: 9) {
                        ForEach(filtered) { card in
                            Button { store.toggleDeckCard(card.id) } label: {
                                VStack(spacing: 4) {
                                    MVCardView(card: card, selected: store.selectedDeck?.cardIDs.contains(card.id) == true)
                                    Image(systemName: store.selectedDeck?.cardIDs.contains(card.id) == true ? "checkmark.circle.fill" : "plus.circle.fill")
                                        .foregroundStyle(MVTheme.yellow)
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding(14)
            }
            .background(MVTheme.navy)
            .navigationTitle("マイデッキ")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完了") { dismiss() } } }
        }.preferredColorScheme(.dark)
    }
}

private struct MVWorksView: View {
    @ObservedObject var store: StudioStore
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("作品一覧").font(.system(size: 25, weight: .black))
                        Spacer()
                        Text("\(store.data.works.count)作品").font(.caption.bold()).foregroundStyle(MVTheme.yellow)
                    }
                    if store.data.works.isEmpty {
                        VStack(spacing: 13) {
                            MVSprite(tile: 14).frame(width: 162, height: 135)
                                .clipped().cornerRadius(18)
                            Text("まだマンガがありません").font(.headline)
                            Text("動画を選び、カードを刺し、マンガを生成して保存しよう！")
                                .font(.footnote).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.75))
                        }.frame(maxWidth: .infinity).padding(28)
                            .background(MVTheme.panel, in: RoundedRectangle(cornerRadius: 18))
                    }
                    ForEach(store.data.works) { work in
                        VStack(alignment: .leading, spacing: 9) {
                            Text(work.title).font(.headline)
                            Text("\(work.sceneCount)コマ・\(work.files.count)ページ・\(work.createdAt.formatted(date: .numeric, time: .omitted))")
                                .font(.caption).foregroundStyle(.white.opacity(0.7))
                            let images = store.workImages(work)
                            if let first = images.first {
                                Image(uiImage: first).resizable().scaledToFit()
                                    .frame(maxWidth: .infinity).background(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 7))
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(work.files, id: \.self) { file in
                                        if let url = store.existingWorkURL(file) {
                                            ShareLink(item: url) {
                                                Label("PNGを保存・共有", systemImage: "square.and.arrow.up")
                                                    .font(.caption.bold()).padding(9)
                                                    .background(MVTheme.yellow, in: Capsule())
                                                    .foregroundStyle(MVTheme.navy)
                                            }
                                        }
                                    }
                                }
                            }
                        }.padding(13).background(MVTheme.panel, in: RoundedRectangle(cornerRadius: 14))
                    }
                }.padding(15)
            }.background(MVTheme.navy).navigationTitle("ムビコマの作品")
        }.preferredColorScheme(.dark)
    }
}

private struct MVSettingsView: View {
    @ObservedObject var store: StudioStore
    @State private var account = ""
    @State private var token = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("無料AI画像生成") {
                    Text("端末内おためし生成は無料で接続不要。AIによる描き直しを利用する場合は、自分のCloudflare Workers Freeアカウントを接続します。運営者のGPU枠は使用しません。")
                        .font(.footnote)
                    TextField("Cloudflare Account ID", text: $account)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Workers AI API Token", text: $token)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Toggle("Workers Free契約を確認しました", isOn: $store.confirmsFree).tint(MVTheme.yellow)
                    Button("自分の無料枠に接続する") {
                        store.cloudflareAccount = account
                        Task { await store.connect(token: token); token = "" }
                    }.disabled(account.isEmpty || token.isEmpty || !store.confirmsFree)
                    if store.isConnected || store.tokenExists {
                        Label("iPhoneのKeychainに安全に保存済み", systemImage: "lock.shield")
                        Button("接続を解除", role: .destructive) { store.disconnect() }
                    }
                    Text("API接続は開発版の機能です。プラン種別は自動検証できません。Workers Paid契約では利用料金が発生する場合があります。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("アプリ") {
                    LabeledContent("名称", value: "ムビコマ")
                    LabeledContent("UI", value: "レックス・コミックスタジオ")
                    LabeledContent("広告", value: "開発版では未配信")
                    Text("編集画面・生成画面に広告を重ねません。").font(.caption)
                }
                Section("状態") { Text(store.message).font(.footnote) }
            }
            .navigationTitle("設定")
            .onAppear { account = store.cloudflareAccount }
        }.preferredColorScheme(.dark)
    }
}
