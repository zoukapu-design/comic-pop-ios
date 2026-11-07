import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Production navigation extensions for the approved high-gloss Rex look.
/// These remain native controls; the only bitmap elements are Rex illustrations.
struct PopHomeScreen: View {
    @ObservedObject var store: StudioStore
    let chooseVideo: () -> Void
    let continueEditing: () -> Void
    let openWorks: () -> Void
    let openDeck: () -> Void
    let openSettings: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                ZStack(alignment: .bottomLeading) {
                    PopArtwork(kind: .hero)
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                    LinearGradient(colors: [.clear, PopColor.royal.opacity(0.96)],
                                   startPoint: .center, endPoint: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ムビコマ")
                            .font(.system(size: 37, weight: .black, design: .rounded))
                            .foregroundStyle(PopColor.yellow)
                        Text("動画を、マンガに変えよう！")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: PopColor.navy, radius: 4, y: 2)
                    .padding(14)
                }
                .overlay(RoundedRectangle(cornerRadius: 22)
                    .stroke(PopColor.edge, lineWidth: 3))
                .shadow(color: PopColor.navy.opacity(0.45), radius: 10, y: 4)

                PopSurface(accent: true) {
                    VStack(spacing: 12) {
                        HStack(spacing: 7) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(PopColor.royal)
                            Text("動画を選んで漫画を作ろう！")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundStyle(PopColor.ink)
                        }
                        PopYellowButton(title: "動画からマンガを作る",
                                        icon: "movieclapper.fill", action: chooseVideo)
                        if store.videoURL != nil {
                            Button(action: continueEditing) {
                                Label("前回の動画の編集を続ける", systemImage: "play.rectangle.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .foregroundStyle(PopColor.ink)
                                    .background(.white, in: Capsule())
                                    .overlay(Capsule().stroke(PopColor.edge, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                VStack(spacing: 9) {
                    feature("作品一覧", "作ったマンガを読む・共有", icon: "books.vertical.fill", action: openWorks)
                    feature("マイデッキ", "好きなカードをまとめる", icon: "star.square.fill", action: openDeck)
                    feature("設定", "画風・アカウント・ヘルプ", icon: "gearshape.fill", action: openSettings)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("３ステップで、マンガができる！")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    HStack(spacing: 5) {
                        miniStep("1", "動画を選ぶ", icon: "film.fill")
                        Image(systemName: "chevron.right").foregroundStyle(PopColor.yellow)
                        miniStep("2", "カードを挿す", icon: "pin.fill")
                        Image(systemName: "chevron.right").foregroundStyle(PopColor.yellow)
                        miniStep("3", "漫画に変換", icon: "book.fill")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(PopColor.navy.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 18)
        }
        .accessibilityIdentifier("popHomeScreen")
    }

    private func feature(_ title: String, _ subtitle: String, icon: String,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .heavy))
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .heavy))
            }
            .foregroundStyle(PopColor.ink)
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .background(LinearGradient(colors: [.white, PopColor.paper],
                                       startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17)
                .stroke(PopColor.edge, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private func miniStep(_ number: String, _ title: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Label(number, systemImage: icon)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(PopColor.yellow)
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Always selects the user's real Photos/Files video. Never displays stock media
/// as if it were the selected user's video.
struct PopVideoChooseScreen: View {
    @ObservedObject var store: StudioStore
    let startEditing: () -> Void
    let goBack: () -> Void
    @State private var chosenPhoto: PhotosPickerItem?
    @State private var importFile = false
    @State private var loading = false
    @State private var thumbnail: UIImage?
    @State private var shouldConfirmReplace = false
    @State private var pendingPhoto: PhotosPickerItem?
    @State private var pendingURL: URL?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Button(action: goBack) {
                        Label("ホーム", systemImage: "chevron.left")
                            .font(.system(size: 12, weight: .heavy))
                    }
                    Spacer()
                    Text("STEP 1 / 3")
                        .font(.system(size: 12, weight: .black))
                }
                .foregroundStyle(.white)

                PopBlueTitle(icon: "film.fill", title: "漫画にする動画を選ぶ")
                PopSurface {
                    VStack(spacing: 12) {
                        Text("写真アプリやファイルから動画を読み込みます")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(PopColor.ink)
                        HStack(spacing: 8) {
                            PhotosPicker(selection: $chosenPhoto, matching: .videos) {
                                Label("ライブラリ", systemImage: "photo.on.rectangle")
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 44)
                                    .background(PopColor.yellow,
                                                in: RoundedRectangle(cornerRadius: 12))
                            }
                            Button {importFile = true} label: {
                                Label("ファイル", systemImage: "folder.fill")
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 44)
                                    .background(PopColor.yellow,
                                                in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(PopColor.ink)
                        .buttonStyle(.plain)
                        if let url = store.videoURL {
                            if let image = thumbnail {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: 235)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(PopColor.royal)
                                    .frame(height: 140)
                                    .overlay(ProgressView().tint(.white))
                            }
                            HStack {
                                Label(store.data.videoTitle, systemImage: "checkmark.circle.fill")
                                    .lineLimit(1)
                                Spacer()
                                Text(store.formatted(store.duration))
                                    .monospacedDigit()
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(PopColor.ink)
                            .accessibilityIdentifier("popSelectedVideo")
                            Text("動画を変更すると、この動画のカードと未保存の生成結果は消去されます。保存済み作品とマイデッキは残ります。")
                                .font(.system(size: 10))
                                .foregroundStyle(PopColor.ink.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ZStack {
                                PopColor.royal.opacity(0.9)
                                VStack(spacing: 10) {
                                    Image(systemName: "video.badge.plus")
                                        .font(.system(size: 37))
                                    Text("動画はまだ選ばれていません")
                                        .font(.system(size: 13, weight: .heavy))
                                }.foregroundStyle(.white)
                            }
                            .frame(height: 190)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                if loading {
                    ProgressView("動画を読み込み中…")
                        .tint(.white)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("popVideoLoading")
                }
                PopYellowButton(title: "この動画で編集を始める", icon: "arrow.right.circle.fill",
                                enabled: !loading && store.videoURL != nil, action: startEditing)
                    .accessibilityIdentifier("popStartEditing")
                Text(store.message)
                    .font(.caption)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
        .task(id: store.videoURL?.absoluteString) {
            thumbnail = nil
            guard let url = store.videoURL else {return}
            let frame = try? await VideoFrameService.frame(
                at: max(0, min(store.duration / 3, 1)), from: url)
            if !Task.isCancelled && store.videoURL == url {thumbnail = frame}
        }
        .onChange(of: chosenPhoto) { _, next in
            guard let next else {return}
            if store.videoURL != nil && !store.data.pins.isEmpty {
                pendingPhoto = next
                shouldConfirmReplace = true
            } else {
                Task {await importPhoto(next)}
            }
        }
        .fileImporter(isPresented: $importFile, allowedContentTypes: [.movie],
                      allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url=urls.first else {return}
                if store.videoURL != nil && !store.data.pins.isEmpty {
                    pendingURL=url
                    shouldConfirmReplace=true
                } else {Task {await importVideo(url)}}
            case .failure(let error):
                store.message="動画の選択に失敗しました：\(error.localizedDescription)"
            }
        }
        .confirmationDialog("別の動画に変更しますか？",
                            isPresented: $shouldConfirmReplace, titleVisibility: .visible) {
            Button("変更してカードをリセット", role: .destructive) {
                if let photo = pendingPhoto {Task {await importPhoto(photo)}}
                else if let url = pendingURL {Task {await importVideo(url)}}
                pendingPhoto=nil
                pendingURL=nil
            }
            Button("変更しない", role: .cancel) {
                pendingPhoto=nil
                pendingURL=nil
            }
        } message: {
            Text("現在の動画の挿入カードと未保存の生成結果が消えます。マイデッキと保存済み作品は残ります。")
        }
    }

    private func importPhoto(_ photo: PhotosPickerItem) async {
        guard !loading else {return}
        loading = true
        defer {loading = false}
        do {
            guard let movie = try await photo.loadTransferable(type: MovieImport.self) else {
                store.message = "動画を読み込めませんでした。別の動画を選択してください。"
                return
            }
            await store.replaceVideo(movie.url)
        } catch {store.message="動画取り込みに失敗しました：\(error.localizedDescription)"}
    }
    private func importVideo(_ url: URL) async {
        guard !loading else {return}
        loading=true
        defer {loading=false}
        await store.replaceVideo(url)
    }
}

/// Real saved work + share actions, with no non-functional PDF button.
struct PopSavedConfirmation: View {
    @ObservedObject var store: StudioStore
    let goHome: () -> Void
    let goToWorks: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var pdfURL:URL?
    @State private var showPDFShare=false
    @State private var readingWork:SavedWork?
    private var saved: SavedWork? {store.data.works.first}
    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                PopArtwork(kind: .hero)
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                Text("マンガが完成しました！")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                if let saved {
                    PopSurface {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label(saved.title, systemImage: "checkmark.seal.fill")
                                    .font(.system(size: 15, weight: .heavy))
                                    .lineLimit(2)
                                Spacer()
                                Text("\(saved.files.count)ページ")
                                    .font(.system(size: 11, weight: .heavy))
                            }
                            if let cover = store.workImages(saved).first {
                                Image(uiImage: cover)
                                    .resizable().scaledToFit()
                                    .frame(maxWidth: .infinity)
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(Array(saved.files.enumerated()), id: \.offset) { entry in
                                        if let url=store.existingWorkURL(entry.element) {
                                            ShareLink(item: url) {
                                                Label("\(entry.offset+1)ページを共有",
                                                      systemImage: "square.and.arrow.up")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .padding(9)
                                                    .background(PopColor.yellow, in: Capsule())
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .foregroundStyle(PopColor.ink)
                    }
                }
                if let saved {
                    Button {
                        pdfURL = store.exportPDF(saved)
                        showPDFShare = pdfURL != nil
                    } label: {
                        Label("全ページをPDFで共有",systemImage:"doc.richtext")
                            .font(.system(size:13,weight:.heavy))
                            .frame(maxWidth:.infinity)
                            .padding(12)
                            .foregroundStyle(PopColor.ink)
                            .background(.white,in:Capsule())
                    }
                    .buttonStyle(.plain)
                }
                if let saved {
                    PopYellowButton(title:"完成した漫画を読む（全\(saved.files.count)ページ）",
                                    icon:"book.closed.fill") {
                        readingWork=saved
                    }
                }
                PopYellowButton(title: "作品一覧で見る", icon: "books.vertical.fill") {
                    dismiss()
                    goToWorks()
                }
                Button {
                    dismiss()
                    goHome()
                } label: {
                    Label("ホームに戻る", systemImage: "house.fill")
                        .font(.system(size: 14, weight: .heavy))
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(.white, in: Capsule())
                        .foregroundStyle(PopColor.ink)
                }
                .buttonStyle(.plain)
            }
            .padding(15)
        }
        .background(PopBackground())
        .presentationDragIndicator(.visible)
        .sheet(isPresented:$showPDFShare) {
            if let pdfURL {PopFileShareSheet(files:[pdfURL])}
        }
        .fullScreenCover(item:$readingWork) { work in
            PopComicReader(store:store,work:work)
        }
    }
}
