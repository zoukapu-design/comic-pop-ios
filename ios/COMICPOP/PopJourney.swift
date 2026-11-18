import ImageIO
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Read work covers as cached thumbnails, not full-resolution PDF-like pages.
/// Full-size images are loaded only when the reader actually opens a work.
@MainActor private enum PopWorkCover {
    private static let cache = NSCache<NSString, UIImage>()
    static func image(at url: URL) -> UIImage? {
        let key = url.path as NSString
        if let image = cache.object(forKey: key) {return image}
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let thumb = CGImageSourceCreateThumbnailAtIndex(
                source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 360
                ] as CFDictionary) else {return nil}
        let result = UIImage(cgImage: thumb)
        cache.setObject(result, forKey: key)
        return result
    }
}

/// Active production home. Every action routes to a real StudioStore flow;
/// only the approved Rex illustrations, never entire screens, are bitmaps.
struct PopHomeScreen: View {
    @ObservedObject var store: StudioStore
    let chooseVideo: () -> Void
    let continueEditing: () -> Void
    let continueManga: () -> Void
    let openWorks: () -> Void
    let openDeck: () -> Void
    let openSettings: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 17) {
                hero
                createPanel
                if store.hasUncommittedGeneration { resumeCard }
                worksGallery
                creatorTools
                steps
            }
            .padding(.horizontal, 14)
            .padding(.top, 7)
            .padding(.bottom, 30)
        }
        .accessibilityIdentifier("popHomeScreen")
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            PopArtwork(kind: .hero).frame(height: 244)
            LinearGradient(
                stops: [
                    .init(color: PopColor.navy.opacity(0.04), location: 0),
                    .init(color: PopColor.navy.opacity(0.35), location: 0.43),
                    .init(color: PopColor.navy.opacity(0.96), location: 1)
                ],
                startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 4) {
                Text("MOVIE × MANGA")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(2).foregroundStyle(PopColor.cyan)
                Text("ムビコマ")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .italic().foregroundStyle(PopColor.yellow)
                    .shadow(color: PopColor.navy, radius: 3, x: 2, y: 3)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text("動画の一瞬が、物語の1コマになる。")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
        }
        .frame(height: 244)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(PopColor.edge, lineWidth: 2))
        .shadow(color: PopColor.navy.opacity(0.45), radius: 12, y: 5)
        .accessibilityElement(children: .combine)
    }

    private var createPanel: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 11) {
                Image(systemName: "film.stack.fill")
                    .font(.system(size: 23, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 45, height: 45)
                    .background(PopColor.blue, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text("さあ、漫画を作ろう！")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                    Text("好きな動画から、オチも感動も1冊に。")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PopColor.ink.opacity(0.75))
                }
                Spacer(minLength: 0)
            }
            PopYellowButton(title: "新しい動画で漫画を作る",
                            icon: "video.fill", action: chooseVideo)
                .accessibilityIdentifier("popCreateFromVideo")
            if store.videoURL != nil {
                Button(action: continueEditing) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("前回の動画の編集を続ける")
                                .font(.system(size: 13, weight: .bold))
                            Text(store.data.videoTitle.isEmpty
                                 ? "選択中の動画" : store.data.videoTitle)
                                .font(.system(size: 10)).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.right")
                    }
                    .padding(.horizontal, 13).frame(minHeight: 49)
                    .background(.white, in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13)
                             .stroke(PopColor.edge, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("popContinueVideo")
            }
        }
        .foregroundStyle(PopColor.ink)
        .padding(15)
        .background(
            LinearGradient(colors: [.white, PopColor.paper],
                           startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(PopColor.edge, lineWidth: 2))
        .shadow(color: PopColor.navy.opacity(0.25), radius: 8, y: 4)
    }

    private var resumeCard: some View {
        Button(action: continueManga) {
            HStack(spacing: 11) {
                Image(systemName: store.hasCompleteComic
                      ? "checkmark.seal.fill" : "clock.arrow.circlepath")
                    .font(.system(size: 27, weight: .heavy))
                    .foregroundStyle(PopColor.yellow)
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.hasCompleteComic
                         ? "完成済み漫画を開く" : "作りかけの漫画を再開")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                    Text(store.hasCompleteComic
                         ? "\(store.generatedPanelCount)コマ完成。レビューから保存できます。"
                         : "\(store.generatedPanelCount) / \(store.scenePlan.renderedPanelCount) コマ。続きを作成できます。")
                        .font(.system(size: 11, weight: .medium))
                    if !store.hasRecoverableDraft {
                        Text("端末への復元データ保存は未確認")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(PopColor.yellow)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(.white)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
            .background(
                LinearGradient(colors: [PopColor.royal, PopColor.navy],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17)
                     .stroke(PopColor.yellow, lineWidth: 2))
        }
        .disabled(store.isGenerating)
        .opacity(store.isGenerating ? 0.6 : 1)
        .buttonStyle(.plain)
        .accessibilityIdentifier("popResumeComic")
    }

    private var worksGallery: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading("マイコミックス", caption: "保存したマンガはここに並びます")
            if store.data.works.isEmpty {
                Button(action: openWorks) {
                    HStack(spacing: 13) {
                        PopArtwork(kind: .genres, index: 0)
                            .frame(width: 90, height: 82)
                            .clipShape(RoundedRectangle(cornerRadius: 11))
                        VStack(alignment: .leading, spacing: 6) {
                            Text("最初の1冊を作ろう")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                            Text("まだ保存した作品はありません")
                                .font(.system(size: 11, weight: .medium))
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                    }
                    .foregroundStyle(PopColor.ink)
                    .padding(11)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16)
                             .stroke(PopColor.edge, lineWidth: 2))
                }
                .buttonStyle(.plain)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(Array(store.data.works.prefix(5))) { work in
                            Button(action: openWorks) {
                                VStack(alignment: .leading, spacing: 6) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12).fill(.white)
                                        if let first = work.files.first,
                                           let url = store.existingWorkURL(first),
                                           let image = PopWorkCover.image(at: url) {
                                            Image(uiImage: image)
                                                .resizable().scaledToFit().padding(3)
                                        } else {
                                            PopArtwork(kind: .genres, index: 1)
                                        }
                                    }
                                    .frame(height: 174)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12)
                                             .stroke(PopColor.edge, lineWidth: 2))
                                    Text(work.title)
                                        .font(.system(size: 12, weight: .black, design: .rounded))
                                        .lineLimit(2).foregroundStyle(.white)
                                    Text("\(work.sceneCount)コマ · \(work.files.count)ページ")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.78))
                                }
                                .frame(width: 132, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Button(action: openWorks) {
                    Label("作品一覧を開く", systemImage: "books.vertical.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(PopColor.royal, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var creatorTools: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading("クリエイターメニュー", caption: "カードと作品を管理")
            HStack(spacing: 11) {
                tool(title: "マイデッキ", detail: "自分だけのカード",
                     art: 1, action: openDeck)
                tool(title: "作品ライブラリ", detail: "マンガを保存・共有",
                     art: 2, action: openWorks)
            }
            Button(action: openSettings) {
                HStack(spacing: 9) {
                    Image(systemName: "slider.horizontal.3")
                    Text("画風・音声・AI接続の設定")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(minHeight: 46)
                .background(PopColor.navy.opacity(0.8),
                            in: RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
        }
    }

    private func tool(title: String, detail: String, art: Int,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                PopArtwork(kind: .cards, index: art)
                    .frame(height: 103).clipShape(RoundedRectangle(cornerRadius: 11))
                Text(title).font(.system(size: 14, weight: .black, design: .rounded))
                Text(detail).font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(PopColor.ink)
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PopColor.paper, in: RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17)
                     .stroke(PopColor.edge, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(title)
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 11) {
            heading("3ステップで完成", caption: "動画 × カード × マンガ")
            HStack(alignment: .top, spacing: 8) {
                step("01", "動画を選ぶ", art: 0)
                step("02", "カードを挿す", art: 3)
                step("03", "漫画に変換", art: 5)
            }
        }
    }

    private func step(_ number: String, _ name: String, art: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            PopArtwork(kind: .genres, index: art)
                .frame(height: 77)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(number).font(.system(size: 11, weight: .black))
                .foregroundStyle(PopColor.yellow)
            Text(name).font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func heading(_ title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 19, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(caption).font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.76))
        }
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
            if store.videoURL != nil && (!store.data.pins.isEmpty || store.hasUncommittedGeneration) {
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
                if store.videoURL != nil && (!store.data.pins.isEmpty || store.hasUncommittedGeneration) {
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
                if let photo = pendingPhoto {Task {await importPhoto(photo,allowDiscard:true)}}
                else if let url = pendingURL {Task {await importVideo(url,allowDiscard:true)}}
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

    private func importPhoto(_ photo: PhotosPickerItem,allowDiscard:Bool = false) async {
        guard !loading else {return}
        loading = true
        defer {loading = false}
        do {
            guard let movie = try await photo.loadTransferable(type: MovieImport.self) else {
                store.message = "動画を読み込めませんでした。別の動画を選択してください。"
                return
            }
            await store.replaceVideo(movie.url,allowDiscard:allowDiscard)
        } catch {store.message="動画取り込みに失敗しました：\(error.localizedDescription)"}
    }
    private func importVideo(_ url: URL,allowDiscard:Bool = false) async {
        guard !loading else {return}
        loading=true
        defer {loading=false}
        await store.replaceVideo(url,allowDiscard:allowDiscard)
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
