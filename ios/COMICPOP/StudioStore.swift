import AVFoundation
import Combine
import Foundation
import UIKit

struct PreviewPanel: Identifiable {
    let id: UUID
    let cardTitle: String
    let original: UIImage
    var drawing: UIImage
    var warning: String?
    var caption: String = ""
    var dialogue: String = ""
    var storyPrompt: String = ""
    var storyScene: String = ""
}

@MainActor final class StudioStore: ObservableObject {
    @Published private(set) var data: StudioData
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var generated: [PreviewPanel] = []
    @Published var pageImages: [UIImage] = []
    @Published var isGenerating = false
    @Published private(set) var isAddingPin = false
    @Published var message = "カードを刺して漫画を作ろう"
    @Published private(set) var storySummary: String = ""
    @Published private(set) var storyCreationMode: String = ""
    @Published var cloudflareAccount: String = UserDefaults.standard.string(forKey:"cfAccountId") ?? ""
    @Published var isConnected = false
    /// Remember the user's explicit Workers Free confirmation across app updates.
    /// Cloudflare plan status still cannot be verified automatically.
    @Published var confirmsFree = UserDefaults.standard.bool(forKey:"cfWorkersFreeConfirmed") {
        didSet { UserDefaults.standard.set(confirmsFree,forKey:"cfWorkersFreeConfirmed") }
    }
    @Published var deckEditing = false
    @Published var titleDraft = ""
    let player = AVPlayer()
    let catalog: [PinDefinition]
    private var observer: Any?
    // Invalidate delayed video-frame tasks when the source video or pins are reset.
    private var videoSession = UUID()
    private var pinsResetEpoch = UUID()
    private var pinsRevision = UUID()
    // Any persisted or reset screenplay/artwork invalidates an in-flight
    // delayed frame acquisition started against an older draft.
    private var draftRevision = UUID()
    // A partial AI result can only be resumed with exactly the same style and colour.
    private var generatedStyle: String?
    private var generatedColor: String?
    private var generatedMode: String?
    private var storyPlan: MangaStoryPlan?
    private var finishingBase:[UUID:UIImage]=[:]
    private var panelRetryCount:[UUID:Int]=[:]
    /// Artwork files are versioned, never overwritten before JSON commits.
    private var storedArtworkFiles:[UUID:String]=[:]
    private var dirtyArtworkIDs:Set<UUID>=[]

    private let fm = FileManager.default
    private let support: URL
    private var modelURL: URL { support.appendingPathComponent("studio.json") }
    private var draftURL: URL { support.appendingPathComponent("manga-draft.json") }
    var videoURL:URL? {data.videoFile.map{support.appendingPathComponent($0)}}
    var tokenExists: Bool {CloudflareCredentialVault.load() != nil}
    /// A stored credential pair is reusable without a fresh sign-in or token entry.
    /// isConnected is only a local storage state, not an online plan verification.
    var hasCloudflareSetup: Bool {
        tokenExists && !cloudflareAccount.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty
    }
    var selectedDeck: UserDeck? {data.decks.first(where:{$0.id == data.activeDeckID}) ?? data.decks.first}
    var cards: [PinDefinition] {catalog}
    var scenePlan: ScenePlan {ScenePlan(pins:data.pins)}
    var hasCompleteComic: Bool {
        GenerationIntegrity.isComplete(
            completedIDs: generated.map(\.id), plannedIDs: scenePlan.renderPins.map(\.id),
            pageCount: pageImages.count, expectedPageCount: scenePlan.pages,
            isGenerating: isGenerating
        )
    }
    /// A screenplay is ready for review BEFORE paying for all image calls.
    var storyboardReady: Bool {
        generated.isEmpty && !isGenerating && generatedMode == "online" &&
        generatedStyle == data.style && generatedColor == data.colorMode &&
        storyPlan?.beats.map(\.id) == scenePlan.renderPins.map(\.id)
    }
    var storyboardBeats:[MangaStoryBeat] {
        guard storyboardReady else {return []}
        return storyPlan?.beats ?? []
    }

    var generatedPanelCount: Int { generated.count }
    var generatedOffline: Bool { generatedMode == "offline" }
    var hasRecoverableDraft: Bool { fm.fileExists(atPath:draftURL.path) }
    /// Unpublished artwork or an AI storyboard would be lost by a style change.
    /// Stored works are not included; they remain in the works library.
    var hasUncommittedGeneration: Bool { !generated.isEmpty || storyPlan != nil }
    func clearGenerated() {
        removeDraftCheckpoint()
        draftRevision = UUID()
        generated = []; pageImages = []
        generatedStyle = nil; generatedColor = nil; generatedMode = nil
        storyPlan = nil;storySummary = "";storyCreationMode = ""
        finishingBase.removeAll();panelRetryCount.removeAll()
    }
    func discardGenerated() {
        guard !isGenerating else {message = "生成中は再生成できません";return}
        clearGenerated();message = "カードは残したまま生成結果をリセットしました"
    }

    init() {
        // Story-aware generation uses audio when the user permits it.
        UserDefaults.standard.register(defaults:[
            "pop.story.useVoice":true,
            "pop.story.useVisualAI":true
        ])
        support = fm.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("COMICPOP",isDirectory:true)
        try? fm.createDirectory(at:support,withIntermediateDirectories:true)
        let url=Bundle.main.url(forResource:"cards",withExtension:"json")
        catalog=url.flatMap {try? Data(contentsOf:$0).decodeCards()} ?? []
        data=(try? JSONDecoder().decode(StudioData.self,from:Data(contentsOf:support.appendingPathComponent("studio.json")))) ?? StudioData()
        if data.activeDeckID == nil {data.activeDeckID=data.decks.first?.id}
        isConnected=hasCloudflareSetup
        titleDraft=data.workTitle
        if let file=data.videoFile, fm.fileExists(atPath:support.appendingPathComponent(file).path) {
            player.replaceCurrentItem(with:AVPlayerItem(url:support.appendingPathComponent(file)))
            Task {await self.loadDuration()}
        }
        restoreDraftCheckpoint()
        observer=player.addPeriodicTimeObserver(forInterval:CMTime(seconds:0.15,preferredTimescale:600),queue:.main){[weak self] time in
            Task { @MainActor in self?.currentTime=time.seconds.isFinite ? time.seconds : 0 }
        }
    }
    @discardableResult private func persist(_ snapshot: StudioData? = nil) -> Bool {
        do {
            try StudioAtomicPersistence.write(snapshot ?? data,to:modelURL)
            return true
        } catch {
            message="端末への保存に失敗しました：\(error.localizedDescription)"
            return false
        }
    }
    /// Publish the editor change only after its durable, atomic JSON write
    /// succeeds. Failed saves must not make the displayed pins diverge from disk.
    @discardableResult private func commit(_ candidate: StudioData) -> Bool {
        guard persist(candidate) else {return false}
        data=candidate
        return true
    }
    /// Restore only if the same video, all user pin records and scene grouping
    /// remain unchanged. A missing/corrupt image ends the recoverable prefix.
    private func restoreDraftCheckpoint() {
        guard let contents=try? Data(contentsOf:draftURL),
              let saved=try? JSONDecoder().decode(MangaDraftCheckpoint.self,from:contents),
              saved.isCompatible(
                videoFile:data.videoFile,pins:data.pins,
                sceneIDs:scenePlan.renderPins.map(\.id),
                style:data.style,colorMode:data.colorMode
              ) else {return}
        let sourcePins=Dictionary(uniqueKeysWithValues:scenePlan.renderPins.map{($0.id,$0)})
        var recovered:[PreviewPanel]=[]
        var recoveredFiles:[UUID:String]=[:]
        for art in saved.artworks {
            guard let pin=sourcePins[art.id],
                  let original=snapshot(for:pin),
                  let drawing=UIImage(contentsOfFile:support.appendingPathComponent(art.drawingFile).path)
            else {break}
            recovered.append(PreviewPanel(
                id:art.id,cardTitle:art.cardTitle,original:original,
                drawing:drawing,warning:nil,caption:art.caption,
                dialogue:art.dialogue,storyPrompt:art.storyPrompt,
                storyScene:art.storyScene
            ))
            recoveredFiles[art.id]=art.drawingFile
        }
        generatedStyle=saved.style;generatedColor=saved.colorMode
        generatedMode=saved.mode
        storyPlan=saved.plan
        storySummary=saved.summary
        storyCreationMode=saved.creationMode
        generated=recovered
        storedArtworkFiles=recoveredFiles
        // A partially missing PNG truncates the recovered prefix. Only
        // restore retake seeds for drawings that actually survived.
        let recoveredIDs=Set(recovered.map(\.id))
        panelRetryCount=(saved.retryCounts ?? [:]).filter {
            recoveredIDs.contains($0.key)
        }
        if recovered.count != saved.artworks.count {
            // Repair the metadata: missing file(s) must not create holes in
            // the completed prefix or cause an unnecessary repeat AI call.
            _ = saveDraftCheckpoint()
        } else {
            // An interrupted write may leave an orphan PNG that is no longer
            // referenced by the last-good, atomically saved JSON.
            cleanupUnreferencedDraftArtwork()
        }
        if !generated.isEmpty {
            refreshArtworkSimilarityWarnings()
            rebuildPages()
            message="中断していた漫画を端末から復元しました（\(generated.count)/\(scenePlan.renderedPanelCount)コマ）。"
        } else {
            message="中断していた脚本を復元しました。確認してから作画を開始できます。"
        }
    }

    /// Persist a screenplay and an ordered prefix of artwork after EACH
    /// successful AI call. Do not silently spend the next credit if this fails.
    @discardableResult private func saveDraftCheckpoint() -> Bool {
        guard let plan=storyPlan,
              let movie=data.videoFile,
              let style=generatedStyle,
              let color=generatedColor,
              let mode=generatedMode else {return false}
        let previous=storedArtworkFiles
        var next=previous
        var newFiles:[String]=[]
        do {
            for panel in generated {
                // Check the actual image on disk, not only its cached file
                // name. The PNG may have been removed after the last save.
                let needsWrite=MangaDraftFilePolicy.needsWrite(
                    existingFile:next[panel.id],
                    isDirty:dirtyArtworkIDs.contains(panel.id),
                    fileExists:{ fm.fileExists(atPath:support.appendingPathComponent($0).path) }
                )
                guard needsWrite else {continue}
                guard let png=panel.drawing.pngData(),!png.isEmpty else {
                    throw MangaError.invalidImage
                }
                let file="draft-art-\(UUID().uuidString).png"
                try png.write(to:support.appendingPathComponent(file),options:.atomic)
                newFiles.append(file)
                next[panel.id]=file
            }
            let artworks=try generated.map { panel -> MangaDraftArtwork in
                guard let file=next[panel.id] else {throw MangaError.invalidImage}
                return MangaDraftArtwork(
                    id:panel.id,drawingFile:file,cardTitle:panel.cardTitle,
                    caption:panel.caption,dialogue:panel.dialogue,
                    storyPrompt:panel.storyPrompt,storyScene:panel.storyScene
                )
            }
            let currentArtworkIDs=Set(artworks.map(\.id))
            let checkpoint=MangaDraftCheckpoint(
                version:1,videoFile:movie,sourcePins:data.pins,
                sceneIDs:scenePlan.renderPins.map(\.id),
                style:style,colorMode:color,mode:mode,plan:plan,
                summary:storySummary,creationMode:storyCreationMode,
                artworks:artworks,
                retryCounts:panelRetryCount.filter {currentArtworkIDs.contains($0.key)}
            )
            guard checkpoint.isCompatible(
                videoFile:movie,pins:data.pins,
                sceneIDs:scenePlan.renderPins.map(\.id),
                style:data.style,colorMode:data.colorMode
            ) else {throw MangaStoryError.missingPanels}
            try StudioAtomicPersistence.write(checkpoint,to:draftURL)
            storedArtworkFiles=next
            dirtyArtworkIDs.removeAll()
            draftRevision=UUID()
            for (id,file) in previous where next[id] != file {
                try? fm.removeItem(at:support.appendingPathComponent(file))
            }
            cleanupUnreferencedDraftArtwork()
            return true
        } catch {
            for file in newFiles {try? fm.removeItem(at:support.appendingPathComponent(file))}
            message="漫画の復元データを端末に保存できませんでした：\(error.localizedDescription)"
            return false
        }
    }

    /// Only after a verified checkpoint is present may abandoned PNGs be
    /// collected. Never touch original video, pins or saved manga pages.
    private func cleanupUnreferencedDraftArtwork() {
        guard fm.fileExists(atPath:draftURL.path),
              let files=try? fm.contentsOfDirectory(atPath:support.path) else {return}
        let referenced=Set(storedArtworkFiles.values)
        for file in MangaDraftFilePolicy.orphanFiles(
            available:files,referenced:referenced
        ) {
            try? fm.removeItem(at:support.appendingPathComponent(file))
        }
    }

    /// Remove the checkpoint index before its referenced image files, so a
    /// reset can never restore a previously discarded manga on next launch.
    private func removeDraftCheckpoint() {
        try? fm.removeItem(at:draftURL)
        // A deliberate reset drops all temporary draft PNGs, but does not
        // touch any original video, pin snapshot or saved comic page.
        if let files=try? fm.contentsOfDirectory(atPath:support.path) {
            for file in MangaDraftFilePolicy.orphanFiles(
                available:files,referenced:[]
            ) {
                try? fm.removeItem(at:support.appendingPathComponent(file))
            }
        }
        storedArtworkFiles.removeAll()
        dirtyArtworkIDs.removeAll()
    }

    private func loadDuration() async {
        guard let url=videoURL else { duration=0; return }
        let loaded=(try? await AVURLAsset(url:url).load(.duration))?.seconds ?? 0
        // A slower previous video must never overwrite the new video's duration.
        guard videoURL==url else {return}
        duration=loaded.isFinite ? max(0,loaded) : 0
    }
    func replaceVideo(_ importedURL:URL,allowDiscard:Bool = false) async {
        guard !isGenerating else {
            message="漫画の脚本・画像を生成中です。完了後に動画を変更してください。"
            return
        }
        guard MangaDraftEditGuard.allowsChange(
            hasDraft:hasUncommittedGeneration,confirmed:allowDiscard
        ) else {
            message="未保存の漫画・AI脚本があります。動画変更の確認画面から続行してください。"
            return
        }
        do {
            let security=importedURL.startAccessingSecurityScopedResource()
            defer {if security {importedURL.stopAccessingSecurityScopedResource()}}
            let newName="video-\(UUID().uuidString).\(importedURL.pathExtension.isEmpty ? "mov" : importedURL.pathExtension)"
            let dest=support.appendingPathComponent(newName)
            try fm.copyItem(at:importedURL,to:dest)
            // Commit the NEW video and empty timeline to disk BEFORE deleting
            // old source/snapshot files. An interrupted or failed write must
            // not permanently destroy the user's previous editing session.
            let oldData=data
            let oldVideo=data.videoFile
            let oldSnapshots=data.pins.map(\.snapshotFile)
            data.videoFile=newName
            data.videoTitle=importedURL.lastPathComponent
            data.pins=[]
            guard persist() else {
                data=oldData
                try? fm.removeItem(at:dest)
                return
            }
            videoSession = UUID()
            pinsResetEpoch = UUID()
            pinsRevision = UUID()
            player.pause()
            player.replaceCurrentItem(with:AVPlayerItem(url:dest))
            clearGenerated();duration=0;currentTime=0
            await loadDuration()
            for file in oldSnapshots {try? fm.removeItem(at:support.appendingPathComponent(file))}
            if let oldVideo {try? fm.removeItem(at:support.appendingPathComponent(oldVideo))}
            message="動画を変更しました。以前のピンカードは削除しました（マイデッキと作品は保持）。"
        } catch {message="動画を取り込めませんでした：\(error.localizedDescription)"}
    }
    func scrub(to seconds:Double) {
        let bounded=max(0,min(max(duration-0.05,0),seconds));currentTime=bounded
        player.seek(to:CMTime(seconds:bounded,preferredTimescale:600),toleranceBefore:.zero,toleranceAfter:.zero)
    }
    func seek(by delta:Double) {scrub(to:currentTime+delta)}
    func playPause(){player.rate>0 ? player.pause() : player.play()}
    func addPin(card:PinDefinition,allowDiscard:Bool = false) async {
        guard !isGenerating else {
            message="漫画生成中はカードを追加できません。生成完了後に編集してください。"
            return
        }
        guard !isAddingPin else {return}
        guard let url=videoURL else {message="先に動画を選んでください";return}
        guard MangaSceneCapacity.canInsert(into:data.pins,at:currentTime) else {
            message="1作品は最大12シーン、同じ場面はカード3枚までです。時間を変えるか、別のカードを外してください。"
            return
        }
        guard MangaDraftEditGuard.allowsChange(
            hasDraft:hasUncommittedGeneration,confirmed:allowDiscard
        ) else {
            message="未保存の漫画・脚本があります。カード追加前に破棄確認が必要です。"
            return
        }
        isAddingPin=true
        defer {isAddingPin=false}
        let seconds=currentTime
        let capturedSession=videoSession
        let capturedReset=pinsResetEpoch
        let capturedRevision=pinsRevision
        let capturedDraftRevision=draftRevision
        do {
            let frame=try await VideoFrameService.frame(at:seconds,from:url)
            // A pending frame cannot add a stale pin to a new video or cleared session.
            guard capturedSession == videoSession &&
                  capturedReset == pinsResetEpoch &&
                  capturedRevision == pinsRevision &&
                  capturedDraftRevision == draftRevision else {return}
            // Frame extraction can finish while the user starts AI generation.
            // Do not append a late pin and invalidate already paid AI calls.
            guard !isGenerating else {
                message="漫画生成が始まったため、処理中のカード追加は見送りました。"
                return
            }
            guard MangaSceneCapacity.canInsert(into:data.pins,at:seconds) else {
                message="カードの追加により12シーンまたは同じ場面の3枚を超えるため、挿入しませんでした。"
                return
            }
            guard MangaDraftEditGuard.allowsChange(
            hasDraft:hasUncommittedGeneration,confirmed:allowDiscard
        ) else {
                message="カード取得中に未保存の漫画ができました。既存の漫画を保護するため挿入を中止しました。"
                return
            }
            guard let bytes=VideoFrameService.compactJPEG(frame) else {throw MangaError.invalidImage}
            let file="pin-\(UUID().uuidString).jpg"
            let snapshotURL=support.appendingPathComponent(file)
            try bytes.write(to:snapshotURL,options:.atomic)
            var candidate=data
            candidate.pins.append(MangaPin(cardID:card.id,seconds:seconds,snapshotFile:file))
            guard commit(candidate) else {
                // Never leave an orphan JPEG for a pin absent from saved JSON.
                try? fm.removeItem(at:snapshotURL)
                return
            }
            pinsRevision = UUID()
            clearGenerated()
            message="\(formatted(seconds)) に「\(card.title)」を挿入しました"
        } catch {message="その場面を保存できませんでした：\(error.localizedDescription)"}
    }
    /// User notes and dialogue are stronger evidence than automatically
    /// inferred actions and are included in the whole-series story script.
    @discardableResult func updatePinStory(_ id:UUID,note:String,dialogue:String,allowDiscard:Bool = false) -> Bool {
        guard !isGenerating else {message="漫画生成中はカードを編集できません";return false}
        guard let index=data.pins.firstIndex(where:{$0.id==id}) else {return false}
        let cleanNote=String(note.prefix(260))
        let cleanDialogue=String(dialogue.prefix(160))
        guard data.pins[index].note != cleanNote ||
              data.pins[index].dialogue != cleanDialogue else {return true}
        guard MangaDraftEditGuard.allowsChange(
            hasDraft:hasUncommittedGeneration,confirmed:allowDiscard
        ) else {
            message="未保存の漫画・脚本があります。メモ変更前に破棄確認が必要です。"
            return false
        }
        var candidate=data
        candidate.pins[index].note=cleanNote
        candidate.pins[index].dialogue=cleanDialogue
        guard commit(candidate) else {return false}
        pinsRevision=UUID()
        clearGenerated()
        message="カードの物語メモとセリフを保存しました"
        return true
    }

    /// Edits Japanese lettering without another paid image-generation call.
    func updatePanelText(_ id:UUID,caption:String,dialogue:String) {
        guard !isGenerating else {message="生成中はセリフを変更できません";return}
        guard let index=generated.firstIndex(where:{$0.id==id}) else {return}
        let previousPanel=generated[index]
        generated[index].caption=String(caption.prefix(100))
        generated[index].dialogue=String(dialogue.prefix(80))
        guard saveDraftCheckpoint() else {
            // JSON still contains the previous lettering: do not show an edit
            // that will silently disappear the next time the app starts.
            generated[index]=previousPanel
            return
        }
        rebuildPages()
        message="日本語のセリフ・ナレーションを修正しました"
    }

    func removePin(_ pin:MangaPin,allowDiscard:Bool = false){
        guard !isGenerating else {message="漫画生成中はカードを削除できません";return}
        guard let existing=data.pins.first(where:{$0.id==pin.id}) else {return}
        guard MangaDraftEditGuard.allowsChange(
            hasDraft:hasUncommittedGeneration,confirmed:allowDiscard
        ) else {
            message="未保存の漫画・脚本があります。カード削除前に破棄確認が必要です。"
            return
        }
        var candidate=data
        candidate.pins.removeAll{$0.id==existing.id}
        // Commit first: if disk write fails, both the pin and JPEG remain.
        guard commit(candidate) else {return}
        pinsResetEpoch=UUID();pinsRevision=UUID()
        clearGenerated()
        try? fm.removeItem(at:support.appendingPathComponent(existing.snapshotFile))
        message="カードを削除しました"
    }
    func clearPins(allowDiscard:Bool = false){
        guard !isGenerating else {message="漫画生成中はカードを全削除できません";return}
        guard MangaDraftEditGuard.allowsChange(
            hasDraft:hasUncommittedGeneration,confirmed:allowDiscard
        ) else {
            message="未保存の漫画・脚本があります。全削除前に破棄確認が必要です。"
            return
        }
        let oldSnapshots=data.pins.map(\.snapshotFile)
        var candidate=data
        candidate.pins=[]
        guard commit(candidate) else {return}
        pinsResetEpoch=UUID();pinsRevision=UUID()
        clearGenerated()
        for file in oldSnapshots {try? fm.removeItem(at:support.appendingPathComponent(file))}
        message="カードを全削除しました"
    }
    func snapshot(for pin:MangaPin)->UIImage? {UIImage(contentsOfFile:support.appendingPathComponent(pin.snapshotFile).path)}
    func card(for pin:MangaPin)->PinDefinition {
        catalog.first(where:{$0.id==pin.cardID}) ?? catalog.first ??
            PinDefinition(id:"unknown",title:"未登録カード",subtitle:"カード情報を確認",category:"editing",art:0,color:"#eeeeee")
    }
    func updateStyle(_ style:String) {
        guard !isGenerating else {
            message="漫画生成中は画風を変更できません。作画完了後に変更してください。"
            return
        }
        guard data.style != style else {return}
        guard !hasUncommittedGeneration else {
            message="生成済みの絵や脚本があります。画風を変える場合は確認して生成結果をリセットしてください。"
            return
        }
        var candidate=data
        candidate.style=style
        // Preserve an explicit monochrome/colour choice when browsing genre cards.
        if !UserDefaults.standard.bool(forKey:"pop.userChoseColor") {
            candidate.colorMode=MangaStyles.all.first(where:{$0.id==style})?.defaultColor ?? "mono"
        }
        guard commit(candidate) else {return}
        clearGenerated()
    }
    func updateColor(_ value:String) {
        guard !isGenerating else {
            message="漫画生成中はカラー設定を変更できません。作画完了後に変更してください。"
            return
        }
        guard value=="mono" || value=="color" else {return}
        guard data.colorMode == value || !hasUncommittedGeneration else {
            message="生成済みの絵や脚本があります。色の設定を変える場合は確認して生成結果をリセットしてください。"
            return
        }
        guard data.colorMode != value else {
            UserDefaults.standard.set(true,forKey:"pop.userChoseColor")
            return
        }
        var candidate=data
        candidate.colorMode=value
        guard commit(candidate) else {return}
        UserDefaults.standard.set(true,forKey:"pop.userChoseColor")
        clearGenerated()
    }
    func updateTitle(_ value:String){
        guard !isGenerating else {message="漫画生成中はタイトルを変更できません";return}
        var candidate=data
        candidate.workTitle=String(value.prefix(80))
        guard commit(candidate) else {return}
        titleDraft=data.workTitle
        // Do not rasterize every page on each keyboard keystroke. Flush when
        // editing finishes or before saving, while preserving the text now.
    }
    func refreshPageTitle() {
        guard !isGenerating && !generated.isEmpty else {return}
        rebuildPages()
    }
    func selectDeck(_ id:UUID) {
        guard data.decks.contains(where:{$0.id==id}) else {return}
        var candidate=data
        candidate.activeDeckID=id
        commit(candidate)
    }
    func addDeck(name:String) {
        guard data.decks.count<20 else {message="デッキは最大20個です";return}
        let deck=UserDeck(name:String(name.prefix(24)),cardIDs:[])
        var candidate=data
        candidate.decks.append(deck)
        candidate.activeDeckID=deck.id
        commit(candidate)
    }
    func renameDeck(_ id:UUID,to name:String) {
        guard let i=data.decks.firstIndex(where:{$0.id==id}) else {return}
        var candidate=data
        candidate.decks[i].name=String(name.prefix(24))
        commit(candidate)
    }
    func deleteDeck(_ id:UUID) {
        guard data.decks.count>1 else {message="デッキは1個以上必要です";return}
        var candidate=data
        candidate.decks.removeAll{$0.id==id}
        guard candidate.decks.count<data.decks.count else {return}
        if candidate.activeDeckID==id {candidate.activeDeckID=candidate.decks.first?.id}
        commit(candidate)
    }
    func toggleDeckCard(_ cardID:String) {
        guard let id=data.activeDeckID,
              let i=data.decks.firstIndex(where:{$0.id==id}) else {return}
        var candidate=data
        if let pos=candidate.decks[i].cardIDs.firstIndex(of:cardID) {
            candidate.decks[i].cardIDs.remove(at:pos)
        } else if candidate.decks[i].cardIDs.count<12 {
            candidate.decks[i].cardIDs.append(cardID)
        } else {
            message="1デッキ最大12枚です"
            return
        }
        commit(candidate)
    }
    func moveDeckCard(_ cardID:String,by offset:Int) {
        guard let id=data.activeDeckID,
              let i=data.decks.firstIndex(where:{$0.id==id}),
              let start=data.decks[i].cardIDs.firstIndex(of:cardID) else {return}
        let end=start+offset
        guard data.decks[i].cardIDs.indices.contains(end) else {return}
        var candidate=data
        candidate.decks[i].cardIDs.swapAt(start,end)
        commit(candidate)
    }
    /// Keep the former call site working, but only publish a new account
    /// after a valid token is securely saved. A failed replacement leaves
    /// the existing account and Keychain value untouched.
    func connect(token:String) async {
        _ = await connect(account:cloudflareAccount,token:token)
    }
    @discardableResult func connect(account candidate:String,token:String) async -> Bool {
        guard confirmsFree else {
            message="Workers Free契約を確認してから接続してください"
            return false
        }
        let cleanAccount=candidate.trimmingCharacters(in:.whitespacesAndNewlines)
        let cleanToken=token.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !cleanAccount.isEmpty && !cleanToken.isEmpty else {
            message="Account IDとAPIトークンを入力してください"
            return false
        }
        do {
            let valid=try await CloudflareAIService.verify(account:cleanAccount,token:cleanToken)
            guard valid else {throw MangaError.server("Cloudflareトークンが無効です")}
            guard CloudflareCredentialVault.save(cleanToken) else {
                throw MangaError.server("iPhoneのKeychainに保存できませんでした")
            }
            cloudflareAccount=cleanAccount
            UserDefaults.standard.set(cleanAccount,forKey:"cfAccountId")
            isConnected=true
            message="CloudflareのAPIトークンを安全に保存しました。次回から再入力は不要です。"
            return true
        } catch {
            message="接続失敗：\(error.localizedDescription)"
            return false
        }
    }
    /// Verify a token already stored on this iPhone without asking for it again.
    /// Does not print, transmit to our server or overwrite the Keychain token.
    @discardableResult func reconnectSavedCloudflare(account candidate:String) async -> Bool {
        guard confirmsFree else {
            message="Workers Free契約を確認してから接続してください"
            return false
        }
        let cleanAccount=candidate.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !cleanAccount.isEmpty else {message="Account IDを入力してください";return false}
        guard let savedToken=CloudflareCredentialVault.load(),!savedToken.isEmpty else {
            isConnected=false
            message="保存済みトークンがありません。新しいAPIトークンを登録してください"
            return false
        }
        do {
            let valid=try await CloudflareAIService.verify(account:cleanAccount,token:savedToken)
            guard valid else {throw MangaError.server("保存済みCloudflareトークンが無効です")}
            cloudflareAccount=cleanAccount
            UserDefaults.standard.set(cleanAccount,forKey:"cfAccountId")
            isConnected=true
            message="保存済みAPIトークンの有効性を確認しました"
            return true
        } catch {
            isConnected=false
            message="接続確認に失敗しました：\(error.localizedDescription)"
            return false
        }
    }
    func disconnect(){CloudflareCredentialVault.remove();isConnected=false;message="個人GPU接続を解除しました"}
    /// Gather evidence around EACH timestamp and build ONE continuous script
    /// before any cloud image calls. Existing user cards remain the story skeleton.
    private func prepareStory(pins:[MangaPin],online:Bool,
                              account:String,token:String) async throws -> MangaStoryPlan {
        guard let movie=videoURL else {throw MangaError.noVideo}
        var evidence:[MangaStoryEvidence]=[]
        let wantsSpeech=UserDefaults.standard.bool(forKey:"pop.story.useVoice")
        let speechEnabled=wantsSpeech ? await MangaSpeechEvidence.permission() : false
        if wantsSpeech && !speechEnabled {
            message="日本語音声認識は利用できないため、カードと映像から構成します"
        }
        var lastSpoken = ""
        var lastSpeechTime = -1000.0
        var speechCalls = 0
        for (index,pin) in pins.enumerated() {
            guard let snap=snapshot(for:pin) else {throw MangaError.invalidImage}
            message="動画の展開とカードを分析中 \(index+1)/\(pins.count)"
            let visible=await MangaSceneObservation.describe(snap)
            // One contextual midpoint helps distinguish an event transition
            // from an isolated still frame, without processing the entire movie.
            var neighbor=""
            if index>0 {
                let before=pins[index-1].seconds
                let middle=(before+pin.seconds)*0.5
                if pin.seconds-before>=1,
                   let frame=try? await VideoFrameService.frame(at:middle,from:movie) {
                    neighbor=await MangaSceneObservation.describe(frame)
                }
            }
            var speech = ""
            if speechEnabled {
                // Nearby pins share the same 10-second speech window. At most
                // eight recognitions avoids excessive heat on older iPhones.
                if pin.seconds - lastSpeechTime < 8 {
                    speech = lastSpoken
                } else if speechCalls < 8 {
                    speech=await MangaSpeechEvidence.around(
                        video:movie,seconds:pin.seconds,duration:duration)
                    lastSpoken=speech
                    lastSpeechTime=pin.seconds
                    speechCalls+=1
                }
            }
            guard let scene=scenePlan.scenes.first(where:{$0.id==pin.id}) else {
                throw MangaStoryError.missingPanels
            }
            let cards=scene.pins.map{card(for:$0)}
            let combinedTitle=cards.map(\.title).joined(separator:"＋")
            let combinedHints=zip(scene.pins,cards).map { scenePin,card in
                "\(card.title): \(MangaStoryPlanner.role(for:scenePin.cardID)) / \(card.subtitle)"
            }.joined(separator:" | ")
            let notes=scene.pins.map(\.note).filter{!$0.isEmpty}.joined(separator:" / ")
            let userSpeech=scene.pins.map(\.dialogue).filter{!$0.isEmpty}.joined(separator:" / ")
            evidence.append(MangaStoryEvidence(
                pinID:pin.id,seconds:pin.seconds,cardID:pin.cardID,
                cardTitle:combinedTitle,cardHint:combinedHints,visual:visible,
                neighborVisual:neighbor,heard:speech,
                userNote:notes,userDialogue:userSpeech,
                allCardIDs:scene.cardIDs
            ))
        }
        if online {
            message="カード全体から一つの漫画ストーリーを構成中…（個人のCloudflare枠）"
            return try await MangaStoryAIService.createPlan(
                evidence:evidence,
                frames:pins.compactMap{snapshot(for:$0)},
                video:movie,duration:duration,
                account:account,token:token
            )
        }
        return MangaStoryPlanner.fallback(evidence)
    }

    /// One drawing unit per scene; every inserted card still contributes its
    /// own emotional/narrative direction, even when timestamps coincide.
    private func combinedCard(for pin:MangaPin) -> PinDefinition {
        let scene=scenePlan.scenes.first(where:{$0.id==pin.id})
        let all=scene?.pins.map{card(for:$0)} ?? [card(for:pin)]
        let first=all[0]
        guard all.count>1 else {return first}
        let title=all.map(\.title).joined(separator:"＋")
        let roles=all.map{card in
            "\(card.title): \(card.subtitle)"
        }.joined(separator:" / ")
        return PinDefinition(id:first.id,title:title,subtitle:roles,
                             category:first.category,art:first.art,color:first.color)
    }

    /// First step of AI creation: spend text/vision inference only, then
    /// let the user review the coherent Japanese chapter BEFORE image calls.
    func prepareStoryboard() async {
        await prepareStoryboard(force:false)
    }
    /// The review screen has a separate, explicit quota-consuming retry.
    func recreateStoryboard() async {
        await prepareStoryboard(force:true)
    }
    private func prepareStoryboard(force:Bool) async {
        guard !isGenerating else {return}
        guard videoURL != nil else {message="動画を選択してください";return}
        guard generated.isEmpty else {
            message="生成した絵を残すには先に作品として保存してください"
            return
        }
        let pins=scenePlan.renderPins
        guard !pins.isEmpty else {message="編集画面でカードを挿してください";return}
        // Apply the same limit BEFORE text/vision inference; otherwise a user
        // could spend free quota drafting a 20-scene story that the image
        // workflow later refuses to draw.
        guard pins.count<=12 else {
            message="現在のAIモードは12シーンまでです（カードは統合前なら12枚を超えても構いません）。脚本生成前に場面を絞ってください。"
            return
        }
        guard force || !storyboardReady else {
            message="脚本は作成済みです。内容を確認してから作画してください。再作成は脚本画面の確認ボタンから行えます。"
            return
        }
        guard confirmsFree else {
            message="AI漫画化の前に、設定でWorkers Free契約を確認してください。保存済みトークンの再入力は不要です"
            return
        }
        guard let token=CloudflareCredentialVault.load(),
              !cloudflareAccount.isEmpty else {
            message=tokenExists ?
                "保存済みトークンはあります。設定でCloudflare Account IDを確認してください" :
                "初回のみCloudflareのAccount IDとAPIトークンを登録してください"
            return
        }
        let capturedSession=videoSession
        let capturedRevision=pinsRevision
        let style=data.style,color=data.colorMode,account=cloudflareAccount
        isGenerating=true
        defer {isGenerating=false}
        do {
            let plan=try await prepareStory(pins:pins,online:true,account:account,token:token)
            guard capturedSession == videoSession &&
                  capturedRevision == pinsRevision &&
                  data.style == style && data.colorMode == color else {
                clearGenerated()
                message="動画・カード・画風が変わったため、古い脚本は破棄しました"
                return
            }
            storyPlan=plan
            generatedStyle=style
            generatedColor=color
            generatedMode="online"
            storySummary=plan.premise
            storyCreationMode=plan.usedVisualEvidence
                ? "動画の各シーンを画像AIが確認して脚本を作成"
                : "カード・字幕・音声の文字情報から脚本を作成"
            guard saveDraftCheckpoint() else {return}
            message="脚本を端末に保存しました。各シーンの展開・日本語を確認してから作画してください。"
        } catch {
            message="脚本の作成に失敗しました。以前の脚本は残しました：\(error.localizedDescription)"
        }
    }

    /// Only pre-render story text is editable here. Changes cannot silently
    /// affect an already generated manga or incur extra Cloudflare quota.
    func updateStoryboardBeat(
        _ id:UUID,caption:String,dialogue:String,plotDescription:String,
        visualDirection:String,causalLink:String
    ) {
        guard !isGenerating,generated.isEmpty,let plan=storyPlan,
              let index=plan.beats.firstIndex(where:{$0.id==id}) else {return}
        var beats=plan.beats
        let old=beats[index]
        beats[index]=MangaStoryBeat(
            id:old.id,index:old.index,
            caption:String(caption.prefix(100)),
            dialogue:String(dialogue.prefix(80)),
            scene:old.scene,imagePrompt:old.imagePrompt,transition:old.transition,
            plotDescriptionJP:String(plotDescription.prefix(130)),
            userVisualDirection:String(visualDirection.prefix(320)),
            narrativeDutyJP:old.narrativeDutyJP,
            causalLinkJP:old.index==1 ? "" : String(causalLink.prefix(110)),
            userSceneNoteJP:old.userSceneNoteJP
        )
        storyPlan=MangaStoryPlan(
            title:plan.title,premise:plan.premise,beats:beats,
            isAIStory:plan.isAIStory,usedVisualEvidence:plan.usedVisualEvidence
        )
        guard saveDraftCheckpoint() else {
            storyPlan=plan
            return
        }
        message="脚本の修正を端末に保存しました。画像生成の追加消費はありません。"
    }

    func generate() async {
        guard !isGenerating else {return}
        guard videoURL != nil else {message="動画を選択してください";return}
        let pins=scenePlan.renderPins
        guard !pins.isEmpty else {message="まずカードを刺してください";return}
        guard pins.count<=12 else {message="無料枠保護のため一度に12コマまでです。カードは削除していません。";return}
        guard confirmsFree else {
            message="設定でWorkers Free契約を確認してください。保存済みトークンの再入力は不要です"
            return
        }
        guard let token=CloudflareCredentialVault.load(),
              !cloudflareAccount.isEmpty else {
            message=tokenExists ?
                "Cloudflare Account IDを設定で確認してください。トークンは保存済みです" :
                "初回のみCloudflareアカウントを接続してください"
            return
        }
        let startingSession=videoSession
        let startingRevision=pinsRevision
        let style=data.style
        let colorMode=data.colorMode
        let account=cloudflareAccount
        // Never start twelve paid image calls again on an already completed
        // chapter. For a new full rendering, the user must explicitly reset.
        guard !(hasCompleteComic && generatedMode == "online" &&
                generatedStyle == style && generatedColor == colorMode) else {
            message="AI漫画はすでに完成しています。修正したいコマだけ再生成するか、生成結果を明示的にリセットしてください。"
            return
        }
        // Only skip previously completed panels when ALL of their pin IDs and
        // generation settings still match. Do not spend free quota twice on success.
        let resumable = GenerationIntegrity.canResume(
            completedIDs: generated.map(\.id), plannedIDs: pins.map(\.id),
            sameStyle: generatedStyle == style, sameColor: generatedColor == colorMode
        ) && generatedMode == "online" &&
            storyPlan?.beats.map(\.id) == pins.map(\.id)
        let preparedDraft=generated.isEmpty &&
            storyPlan?.beats.map(\.id)==pins.map(\.id) &&
            generatedStyle==style && generatedColor==colorMode &&
            generatedMode=="online"
        if !resumable && !preparedDraft {clearGenerated()}
        generatedStyle=style;generatedColor=colorMode;generatedMode="online"
        // An earlier save may have failed after the AI already returned an
        // image. Retry the local checkpoint BEFORE spending another credit.
        if storyPlan != nil {
            guard saveDraftCheckpoint() else {return}
        }
        isGenerating=true;pageImages=[]
        defer {isGenerating=false}
        if storyPlan == nil {
            do {
                let plan=try await prepareStory(pins:pins,online:true,account:account,token:token)
                guard startingSession == videoSession && startingRevision == pinsRevision &&
                      style == data.style && colorMode == data.colorMode else {
                    clearGenerated();message="動画・カード・画風が変更されたため脚本を破棄しました"
                    return
                }
                storyPlan=plan
                storySummary=plan.premise
                storyCreationMode=plan.usedVisualEvidence
                    ? "選択した動画シーンを画像AIが理解し、カードと日本語音声で物語を構成"
                    : "カード・字幕・日本語音声からAIが物語を構成（画像理解AIは未使用）"
                // Do not start billable image requests before the screenplay
                // has been backed up on this iPhone.
                guard saveDraftCheckpoint() else {return}
            } catch {
                clearGenerated()
                message="脚本の生成に失敗しました。AI作画の無料枠はまだ使っていません：\(error.localizedDescription)"
                return
            }
        }
        let startIndex=generated.count
        for index in startIndex..<pins.count {
            let pin=pins[index]
            do {
                guard let original=snapshot(for:pin) else {throw MangaError.invalidImage}
                message="AIで描き直しています \(index+1)/\(pins.count)（ユーザーの無料枠）"
                let card=combinedCard(for:pin)
                guard let beat=storyPlan?.beats.first(where:{$0.id==pin.id}) else {
                    throw MangaStoryError.missingPanels
                }
                let seed=Int(UInt32(truncatingIfNeeded:pin.id.uuidString.utf8.reduce(2166136261 as UInt32){($0 ^ UInt32($1)) &* 16777619}))
                let image=try await CloudflareAIService.redraw(
                    image:original,card:card,pin:pin,style:style,colorMode:colorMode,
                    account:account,token:token,seed:seed,
                    story:beat,seriesPremise:storyPlan?.premise ?? "",
                    previousDrawing:generated.last?.drawing,
                    openingDrawing:MangaReferencePolicy.drawingIndices(for:index).count>1
                        ? generated.first?.drawing : nil,
                    combinedCardIDs:scenePlan.scenes.first(where:{$0.id==pin.id})?.cardIDs ?? [pin.cardID]
                )
                // An in-flight request must never revive old or differently styled results.
                guard startingSession == videoSession && startingRevision == pinsRevision &&
                    style == data.style && colorMode == data.colorMode else {
                    clearGenerated()
                    message="動画・カード・画風が変更されたため古い生成結果を破棄しました。"
                    return
                }
                let finishedImage:UIImage
                if colorMode=="mono" {
                    // Do not allow color to drift between panels when the user
                    // explicitly selected a black-and-white comic.
                    finishedImage=PopPageFinisher.render(
                        image,contrast:1.05,brightness:0,saturation:0,sharpness:0.15
                    ) ?? image
                } else {
                    finishedImage=image
                }
                generated.append(PreviewPanel(
                    id:pin.id,cardTitle:card.title,original:original,
                    drawing:finishedImage,warning:nil,
                    caption:beat.caption,dialogue:beat.dialogue,
                    storyPrompt:beat.imagePrompt,storyScene:beat.scene
                ))
                dirtyArtworkIDs.insert(pin.id)
                guard saveDraftCheckpoint() else {
                    rebuildPages()
                    message="AI作画したコマを端末に保存できませんでした。アプリを終了せず、空き容量を確認してください。追加のAI呼出しは停止しました。"
                    return
                }
                refreshArtworkSimilarityWarnings()
            } catch {
                guard startingSession == videoSession && startingRevision == pinsRevision &&
                    style == data.style && colorMode == data.colorMode else {
                    clearGenerated();return
                }
                // Keep successful panels in sequence; the user can resume at the
                // first unfinished pin without consuming quota for those panels again.
                rebuildPages()
                message="\(generated.count)/\(pins.count)コマまで生成。残りは再試行できます：\(error.localizedDescription)"
                return
            }
        }
        rebuildPages()
        message="全\(generated.count)コマを脚本の流れに沿って漫画化しました。日本語と展開を確認してください。"
    }
    /// Always-free trial mode: comic-style image processing happens locally.
    /// No API key, GPU account, uploaded frames or paid service is involved.
    func generateOffline() async {
        guard !isGenerating else {return}
        guard videoURL != nil else {message="動画を選択してください";return}
        let pins=scenePlan.renderPins
        guard !pins.isEmpty else {message="まずカードを刺してください";return}
        guard pins.count<=12 else {message="一度に12コマまでです";return}
        let startingSession=videoSession
        let startingRevision=pinsRevision
        let style=data.style
        let colorMode=data.colorMode
        let resumable=GenerationIntegrity.canResume(
            completedIDs:generated.map(\.id),plannedIDs:pins.map(\.id),
            sameStyle:generatedStyle == style,sameColor:generatedColor == colorMode
        ) && generatedMode == "offline" &&
            storyPlan?.beats.map(\.id) == pins.map(\.id)
        if !resumable {clearGenerated()}
        generatedStyle=style;generatedColor=colorMode;generatedMode="offline"
        if storyPlan != nil {
            guard saveDraftCheckpoint() else {return}
        }
        isGenerating=true;pageImages=[]
        defer {isGenerating=false}
        if storyPlan == nil {
            do {
                let plan=try await prepareStory(pins:pins,online:false,account:"",token:"")
                guard startingSession == videoSession && startingRevision == pinsRevision &&
                      style == data.style && colorMode == data.colorMode else {
                    clearGenerated();return
                }
                storyPlan=plan
                storySummary=plan.premise
                storyCreationMode="端末内のカード構成（文章AIなし）"
                guard saveDraftCheckpoint() else {return}
            } catch {
                clearGenerated();message="カードの構成に失敗しました：\(error.localizedDescription)"
                return
            }
        }
        let startIndex=generated.count
        for index in startIndex..<pins.count {
            let pin=pins[index]
            guard let original=snapshot(for:pin) else {
                rebuildPages();message="元動画の\(index+1)コマ目を取得できません";return
            }
            message="端末内で漫画調に変換しています \(index+1)/\(pins.count)"
            let drawing=await Task.detached(priority:.userInitiated) {
                OfflineComicFilter.render(original,style:style,colorMode:colorMode)
            }.value
            guard startingSession == videoSession && startingRevision == pinsRevision &&
                style == data.style && colorMode == data.colorMode else {
                clearGenerated();message="編集中に元データが変わったため変換結果を破棄しました";return
            }
            guard let drawing else {
                rebuildPages();message="\(generated.count)/\(pins.count)コマまで変換。残りを再試行してください";return
            }
            guard let beat=storyPlan?.beats.first(where:{$0.id==pin.id}) else {
                clearGenerated();message="カードの脚本が不足しています";return
            }
            generated.append(PreviewPanel(
                id:pin.id,cardTitle:combinedCard(for:pin).title,
                original:original,drawing:drawing,warning:nil,
                caption:beat.caption,dialogue:beat.dialogue,
                storyPrompt:beat.imagePrompt,storyScene:beat.scene
            ))
            dirtyArtworkIDs.insert(pin.id)
            guard saveDraftCheckpoint() else {
                rebuildPages()
                message="簡易漫画のコマを端末に保存できませんでした。空き容量を確認してください。"
                return
            }
            refreshArtworkSimilarityWarnings()
        }
        rebuildPages()
        message="全\(generated.count)コマを端末内で簡易漫画化しました（生成AIではありません）。"
    }
    /// Run actual Core Image post-processing and rebuild all pages for saving.
    /// Preserve an unfiltered baseline so moving a slider never compounds filters.
    func applyFinishing(contrast:Double,brightness:Double,saturation:Double,sharpness:Double) {
        guard hasCompleteComic else {message="すべてのコマ生成後に調整してください";return}
        let previousPanels=generated
        let previousFinishingBase=finishingBase
        let previousDirty=dirtyArtworkIDs
        var finished:[UUID:UIImage]=[:]
        for panel in generated {
            let base=finishingBase[panel.id] ?? panel.drawing
            guard let output=PopPageFinisher.render(base,contrast:contrast,brightness:brightness,
                                                      saturation:saturation,sharpness:sharpness) else {
                finishingBase=previousFinishingBase
                message="画質調整に失敗しました。元の漫画は保持しています。"
                return
            }
            finishingBase[panel.id]=base
            finished[panel.id]=output
        }
        for index in generated.indices {
            if let output=finished[generated[index].id] {generated[index].drawing=output}
        }
        dirtyArtworkIDs.formUnion(generated.map(\.id))
        guard saveDraftCheckpoint() else {
            generated=previousPanels
            finishingBase=previousFinishingBase
            dirtyArtworkIDs=previousDirty
            return
        }
        refreshArtworkSimilarityWarnings()
        rebuildPages()
        message="ページ全体の描線・明るさ・彩度・輪郭を調整しました。"
    }

    /// Retake one existing, ordered panel. Does not modify pins, titles or other
    /// generated panels. Online retry consumes one additional user AI request.
    func regeneratePanel(_ id:UUID) async {
        guard !isGenerating else {return}
        guard let index=generated.firstIndex(where:{$0.id==id}),
              let pin=scenePlan.renderPins.first(where:{$0.id==id}) else {
            message="選択されたコマを見つけられません";return
        }
        let mode=generatedMode ?? "offline"
        let style=data.style,colorMode=data.colorMode
        let startingSession=videoSession,startingRevision=pinsRevision
        let original=generated[index].original
        let attempt=panelRetryCount[id,default:0]+1
        // Protect the current panel before a user explicitly spends another
        // AI request on retaking it.
        guard saveDraftCheckpoint() else {return}
        isGenerating=true
        defer {isGenerating=false}
        do {
            let updated:UIImage
            if mode=="offline" {
                guard let image=OfflineComicFilter.render(original,style:style,colorMode:colorMode) else {
                    throw MangaError.invalidImage
                }
                updated=image
            } else {
                guard confirmsFree,let token=CloudflareCredentialVault.load(),
                      !cloudflareAccount.isEmpty else {
                    throw MangaError.credentialsMissing
                }
                let base=Int(UInt32(truncatingIfNeeded:id.uuidString.utf8.reduce(2166136261 as UInt32){
                    ($0 ^ UInt32($1)) &* 16777619
                }))
                let redrawn=try await CloudflareAIService.redraw(
                    image:original,card:combinedCard(for:pin),pin:pin,style:style,colorMode:colorMode,
                    account:cloudflareAccount,token:token,seed:base+attempt*997,
                    story:storyPlan?.beats.first(where:{$0.id==id}),
                    seriesPremise:storyPlan?.premise ?? "",
                    previousDrawing:index>0 ? generated[index-1].drawing : nil,
                    openingDrawing:MangaReferencePolicy.drawingIndices(for:index).count>1
                        ? generated.first?.drawing : nil,
                    alternateComposition:true,
                    combinedCardIDs:scenePlan.scenes.first(where:{$0.id==pin.id})?.cardIDs ?? [pin.cardID]
                )
                updated=colorMode=="mono"
                    ? (PopPageFinisher.render(
                        redrawn,contrast:1.05,brightness:0,saturation:0,sharpness:0.15
                      ) ?? redrawn)
                    : redrawn
            }
            guard startingSession==videoSession && startingRevision==pinsRevision &&
                  style==data.style && colorMode==data.colorMode &&
                  generated.indices.contains(index) && generated[index].id==id else {
                message="元データが変更されたため再生成を破棄しました";return
            }
            // Publish the new drawing only if the durable checkpoint can
            // be written. On disk failure keep the previous visual, filters,
            // retry seed and dirty markers consistent with the saved draft.
            let previousDrawing=generated[index].drawing
            let previousFinishingBase=finishingBase[id]
            let previousRetryCount=panelRetryCount[id]
            let previousDirty=dirtyArtworkIDs
            panelRetryCount[id]=attempt
            finishingBase[id]=updated
            generated[index].drawing=updated
            dirtyArtworkIDs.insert(id)
            guard saveDraftCheckpoint() else {
                generated[index].drawing=previousDrawing
                finishingBase[id]=previousFinishingBase
                panelRetryCount[id]=previousRetryCount
                dirtyArtworkIDs=previousDirty
                message += "。再生成前の絵は保持されています。"
                return
            }
            refreshArtworkSimilarityWarnings()
            rebuildPages()
            message="選択コマを再生成しました。保存前に結果を確認してください。"
        } catch {
            message="コマ再生成に失敗しました：\(error.localizedDescription)"
        }
    }
    func chooseOriginal(_ id:UUID){
        guard !isGenerating else {message="漫画生成中は絵を切り替えられません";return}
        guard let i=generated.firstIndex(where:{$0.id==id}) else {return}
        let previousDrawing=generated[i].drawing
        let previousFinishingBase=finishingBase[id]
        let previousDirty=dirtyArtworkIDs
        finishingBase[id]=nil
        generated[i].drawing=generated[i].original
        dirtyArtworkIDs.insert(id)
        guard saveDraftCheckpoint() else {
            generated[i].drawing=previousDrawing
            finishingBase[id]=previousFinishingBase
            dirtyArtworkIDs=previousDirty
            return
        }
        refreshArtworkSimilarityWarnings()
        rebuildPages()
    }
    /// Compare the actual artwork, not page headers or captions. This also
    /// catches panel 5 repeating panel 1, which adjacent-panel checks miss.
    /// Review warnings are advisory and never spend AI credits automatically.
    private func refreshArtworkSimilarityWarnings() {
        guard !generated.isEmpty else {return}
        for index in generated.indices {
            generated[index].warning=nil
        }
        guard generated.count>1 else {return}
        for later in 1..<generated.count {
            let isFlashback=scenePlan.scenes.indices.contains(later) &&
                MangaReplayIntent.isIntentional(cardIDs:scenePlan.scenes[later].cardIDs)
            let comparisons=(0..<later).map { earlier in
                MangaArtworkComparison(
                    earlier:earlier,later:later,
                    distance:ImageDifference.distance(
                        generated[earlier].drawing,generated[later].drawing),
                    intentionalReprise:isFlashback
                )
            }
            if let match=MangaArtworkUniqueness.firstUnintendedSimilarity(comparisons) {
                let pageA=match.earlier/4+1, pageB=match.later/4+1
                generated[later].warning="コマ\(match.earlier+1)（\(pageA)ページ目）とコマ\(later+1)（\(pageB)ページ目）の絵が似ています。別の展開ならコマ単位で再生成できます。"
            }
        }
    }

    func rebuildPages() {
        let title=data.workTitle.isEmpty ? (storyPlan?.title ?? "ムビコマ") : data.workTitle
        pageImages=stride(from:0,to:generated.count,by:4).map { offset in
            ComicRenderer.page(
                panels:Array(generated[offset..<min(offset+4,generated.count)]),
                title:title,pageNumber:offset/4+1,
                total:Int(ceil(Double(generated.count)/4))
            )
        }
    }
    @discardableResult func saveWork() -> Bool {
        guard hasCompleteComic else {
            message="未完成の漫画は保存できません。すべてのカードの生成を完了してください。"
            return false
        }
        // Check illustrations themselves. Comparing composed page PNGs alone
        // misses duplicates because every page has a different number/header.
        // Rechecking all pairs also catches panel 5 repeating panel 1.
        var visualComparisons:[MangaArtworkComparison]=[]
        if generated.count>1 {
            for later in 1..<generated.count {
                let intentionalReplay=scenePlan.scenes.indices.contains(later) &&
                    MangaReplayIntent.isIntentional(cardIDs:scenePlan.scenes[later].cardIDs)
                for earlier in 0..<later {
                    visualComparisons.append(MangaArtworkComparison(
                        earlier:earlier,later:later,
                        distance:ImageDifference.distance(
                            generated[earlier].drawing,generated[later].drawing),
                        intentionalReprise:intentionalReplay
                    ))
                }
            }
        }
        if let duplicate=MangaArtworkUniqueness.firstUnintendedDuplicate(visualComparisons) {
            message="絵が重複しています（コマ\(duplicate.earlier+1)と\(duplicate.later+1)）。文章ではなく画像が同じため、該当コマを別構図で再生成してから保存してください。"
            return false
        }
        // Ensure a finished-but-previously-unbacked draft has a recovery
        // checkpoint too. A failed backup must not silently claim success.
        guard saveDraftCheckpoint() else {return false}
        // Recompose headers from the latest title before saving. The editable
        // title field intentionally avoids expensive per-keystroke rendering.
        refreshPageTitle()
        // Validate the ENTIRE manga before writing the first file. A failed
        // second page can no longer leave a half-saved work on disk.
        let encodedPages=pageImages.compactMap{$0.pngData()}
        guard encodedPages.count==pageImages.count,
              encodedPages.count==scenePlan.pages,
              encodedPages.allSatisfy({!$0.isEmpty}) else {
            message="漫画ページの生成数か画像データが不正です。生成結果を確認してください。"
            return false
        }
        if let repeated=MangaPageIntegrity.firstDuplicatePage(encodedPages) {
            message="\(repeated+1)ページ目が他のページと同じ内容です。生成を確認してから保存してください。"
            return false
        }
        var filenames:[String]=[]
        for png in encodedPages {
            let name="comic-\(UUID().uuidString).png"
            do {try png.write(to:support.appendingPathComponent(name),options:.atomic);filenames.append(name)}
            catch {
                for previous in filenames {try? fm.removeItem(at:support.appendingPathComponent(previous))}
                message="漫画の保存に失敗しました：\(error.localizedDescription)";return false
            }
        }
        guard filenames.count == scenePlan.pages else {
            message="ページ数が一致しません";return false
        }
        let work=SavedWork(id:UUID(),title:data.workTitle.isEmpty ? (storyPlan?.title ?? "漫画 \(Date().formatted(date:.abbreviated,time:.shortened))") : data.workTitle,files:filenames,createdAt:Date(),sceneCount:generated.count,style:data.style)
        data.works.insert(work,at:0)
        guard persist() else {
            data.works.removeAll{$0.id==work.id}
            for name in filenames {try? fm.removeItem(at:support.appendingPathComponent(name))}
            return false
        }
        message="全\(generated.count)コマを作品一覧に保存しました"
        return true
    }
    func workImages(_ work:SavedWork)->[UIImage]{work.files.compactMap{UIImage(contentsOfFile:support.appendingPathComponent($0).path)}}

    /// Export a real multi-page A4-like PDF from an already saved manga.
    /// This has no API/GPU requirement and never changes the saved PNG pages.
    func exportPDF(_ work:SavedWork) -> URL? {
        let images=workImages(work)
        guard !images.isEmpty && images.count == work.files.count else {
            message="PDFにする漫画ページを読み込めませんでした"
            return nil
        }
        let bounds=CGRect(x:0,y:0,width:595,height:842)
        let renderer=UIGraphicsPDFRenderer(bounds:bounds)
        let contents=renderer.pdfData { context in
            for image in images {
                context.beginPage()
                let scale=min(bounds.width/max(image.size.width,1),
                              bounds.height/max(image.size.height,1))
                let size=CGSize(width:image.size.width*scale,height:image.size.height*scale)
                let rect=CGRect(x:(bounds.width-size.width)/2,y:(bounds.height-size.height)/2,
                                width:size.width,height:size.height)
                UIColor.white.setFill()
                UIRectFill(bounds)
                image.draw(in:rect)
            }
        }
        let url=fm.temporaryDirectory.appendingPathComponent("movikoma-\(work.id.uuidString).pdf")
        do {
            try contents.write(to:url,options:.atomic)
            return url
        } catch {
            message="PDFの作成に失敗しました：\(error.localizedDescription)"
            return nil
        }
    }

    /// Remove only a saved work and its pages; never remove the user's video,
    /// other works, pin cards or decks.
    @discardableResult func deleteWork(_ id:UUID) -> Bool {
        guard let index=data.works.firstIndex(where:{$0.id==id}) else {return false}
        let original=data.works[index]
        data.works.remove(at:index)
        guard persist() else {
            data.works.insert(original,at:index)
            return false
        }
        for file in original.files {
            try? fm.removeItem(at:support.appendingPathComponent(file))
        }
        message="作品を削除しました"
        return true
    }
    func formatted(_ seconds:Double)->String {String(format:"%02d:%02d",Int(max(0,seconds))/60,Int(max(0,seconds))%60)}
}

private extension Data {
    func decodeCards() throws -> [PinDefinition] {try JSONDecoder().decode([PinDefinition].self,from:self)}
}
