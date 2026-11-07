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
    @Published var confirmsFree = false
    @Published var deckEditing = false
    @Published var titleDraft = ""
    let player = AVPlayer()
    let catalog: [PinDefinition]
    private var observer: Any?
    // Invalidate delayed video-frame tasks when the source video or pins are reset.
    private var videoSession = UUID()
    private var pinsResetEpoch = UUID()
    private var pinsRevision = UUID()
    // A partial AI result can only be resumed with exactly the same style and colour.
    private var generatedStyle: String?
    private var generatedColor: String?
    private var generatedMode: String?
    private var storyPlan: MangaStoryPlan?
    private var finishingBase:[UUID:UIImage]=[:]
    private var panelRetryCount:[UUID:Int]=[:]

    private let fm = FileManager.default
    private let support: URL
    private var modelURL: URL { support.appendingPathComponent("studio.json") }
    var videoURL:URL? {data.videoFile.map{support.appendingPathComponent($0)}}
    var tokenExists: Bool {CloudflareCredentialVault.load() != nil}
    var selectedDeck: UserDeck? {data.decks.first(where:{$0.id == data.activeDeckID}) ?? data.decks.first}
    var cards: [PinDefinition] {catalog}
    var scenePlan: ScenePlan {ScenePlan(pins:data.pins)}
    var hasCompleteComic: Bool {
        GenerationIntegrity.isComplete(
            completedIDs: generated.map(\.id), plannedIDs: scenePlan.orderedPins.map(\.id),
            pageCount: pageImages.count, expectedPageCount: scenePlan.pages,
            isGenerating: isGenerating
        )
    }
    var generatedPanelCount: Int { generated.count }
    var generatedOffline: Bool { generatedMode == "offline" }
    func clearGenerated() {
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
        support = fm.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("COMICPOP",isDirectory:true)
        try? fm.createDirectory(at:support,withIntermediateDirectories:true)
        let url=Bundle.main.url(forResource:"cards",withExtension:"json")
        catalog=url.flatMap {try? Data(contentsOf:$0).decodeCards()} ?? []
        data=(try? JSONDecoder().decode(StudioData.self,from:Data(contentsOf:support.appendingPathComponent("studio.json")))) ?? StudioData()
        if data.activeDeckID == nil {data.activeDeckID=data.decks.first?.id}
        isConnected=CloudflareCredentialVault.load() != nil
        titleDraft=data.workTitle
        if let file=data.videoFile, fm.fileExists(atPath:support.appendingPathComponent(file).path) {
            player.replaceCurrentItem(with:AVPlayerItem(url:support.appendingPathComponent(file)))
            Task {await self.loadDuration()}
        }
        observer=player.addPeriodicTimeObserver(forInterval:CMTime(seconds:0.15,preferredTimescale:600),queue:.main){[weak self] time in
            Task { @MainActor in self?.currentTime=time.seconds.isFinite ? time.seconds : 0 }
        }
    }
    @discardableResult private func persist() -> Bool {
        do {
            let out=try JSONEncoder().encode(data)
            try out.write(to:modelURL,options:.atomic)
            return true
        } catch {
            message="端末への保存に失敗しました：\(error.localizedDescription)"
            return false
        }
    }
    private func loadDuration() async {
        guard let url=videoURL else { duration=0; return }
        let loaded=(try? await AVURLAsset(url:url).load(.duration))?.seconds ?? 0
        // A slower previous video must never overwrite the new video's duration.
        guard videoURL==url else {return}
        duration=loaded.isFinite ? max(0,loaded) : 0
    }
    func replaceVideo(_ importedURL:URL) async {
        do {
            let security=importedURL.startAccessingSecurityScopedResource()
            defer {if security {importedURL.stopAccessingSecurityScopedResource()}}
            let newName="video-\(UUID().uuidString).\(importedURL.pathExtension.isEmpty ? "mov" : importedURL.pathExtension)"
            let dest=support.appendingPathComponent(newName)
            try fm.copyItem(at:importedURL,to:dest)
            // The previous pins and their snapshots belong to the previous video only.
            videoSession = UUID()
            pinsResetEpoch = UUID()
            pinsRevision = UUID()
            let oldVideo=data.videoFile
            let oldSnapshots=data.pins.map(\.snapshotFile)
            player.pause();player.replaceCurrentItem(with:AVPlayerItem(url:dest))
            data.videoFile=newName;data.videoTitle=importedURL.lastPathComponent
            data.pins=[];clearGenerated();duration=0;currentTime=0
            persist();await loadDuration()
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
    func addPin(card:PinDefinition) async {
        guard !isAddingPin else {return}
        guard let url=videoURL else {message="先に動画を選んでください";return}
        guard data.pins.count < 12 else {message="挿入できるカードは一度に12枚までです";return}
        isAddingPin=true
        defer {isAddingPin=false}
        let seconds=currentTime
        let capturedSession=videoSession
        let capturedReset=pinsResetEpoch
        do {
            let frame=try await VideoFrameService.frame(at:seconds,from:url)
            // A pending frame cannot add a stale pin to a new video or cleared session.
            guard capturedSession == videoSession && capturedReset == pinsResetEpoch else {return}
            guard data.pins.count < 12 else {message="カードは最大12枚です";return}
            guard let bytes=VideoFrameService.compactJPEG(frame) else {throw MangaError.invalidImage}
            let file="pin-\(UUID().uuidString).jpg"
            try bytes.write(to:support.appendingPathComponent(file),options:.atomic)
            data.pins.append(MangaPin(cardID:card.id,seconds:seconds,snapshotFile:file))
            pinsRevision = UUID()
            clearGenerated()
            persist()
            message="\(formatted(seconds)) に「\(card.title)」を挿入しました"
        } catch {message="その場面を保存できませんでした：\(error.localizedDescription)"}
    }
    /// User notes and dialogue are stronger evidence than automatically
    /// inferred actions and are included in the whole-series story script.
    func updatePinStory(_ id:UUID,note:String,dialogue:String) {
        guard !isGenerating else {message="漫画生成中はカードを編集できません";return}
        guard let index=data.pins.firstIndex(where:{$0.id==id}) else {return}
        let cleanNote=String(note.prefix(260))
        let cleanDialogue=String(dialogue.prefix(160))
        guard data.pins[index].note != cleanNote ||
              data.pins[index].dialogue != cleanDialogue else {return}
        data.pins[index].note=cleanNote
        data.pins[index].dialogue=cleanDialogue
        pinsRevision=UUID()
        clearGenerated()
        persist()
        message="カードの物語メモとセリフを保存しました"
    }

    /// Edits Japanese lettering without another paid image-generation call.
    func updatePanelText(_ id:UUID,caption:String,dialogue:String) {
        guard !isGenerating else {message="生成中はセリフを変更できません";return}
        guard let index=generated.firstIndex(where:{$0.id==id}) else {return}
        generated[index].caption=String(caption.prefix(100))
        generated[index].dialogue=String(dialogue.prefix(80))
        rebuildPages()
        message="日本語のセリフ・ナレーションを修正しました"
    }

    func removePin(_ pin:MangaPin){data.pins.removeAll{$0.id==pin.id};pinsResetEpoch=UUID();pinsRevision=UUID();try? fm.removeItem(at:support.appendingPathComponent(pin.snapshotFile));clearGenerated();persist()}
    func clearPins(){pinsResetEpoch=UUID();pinsRevision=UUID();for p in data.pins {try? fm.removeItem(at:support.appendingPathComponent(p.snapshotFile))};data.pins=[];clearGenerated();persist()}
    func snapshot(for pin:MangaPin)->UIImage? {UIImage(contentsOfFile:support.appendingPathComponent(pin.snapshotFile).path)}
    func card(for pin:MangaPin)->PinDefinition {
        catalog.first(where:{$0.id==pin.cardID}) ?? catalog.first ??
            PinDefinition(id:"unknown",title:"未登録カード",subtitle:"カード情報を確認",category:"editing",art:0,color:"#eeeeee")
    }
    func updateStyle(_ style:String) {
        guard data.style != style else {return}
        data.style=style
        // Preserve an explicit monochrome/colour choice when browsing genre cards.
        if !UserDefaults.standard.bool(forKey:"pop.userChoseColor") {
            data.colorMode=MangaStyles.all.first(where:{$0.id==style})?.defaultColor ?? "mono"
        }
        clearGenerated();persist()
    }
    func updateColor(_ value:String) {
        guard value=="mono" || value=="color" else {return}
        UserDefaults.standard.set(true,forKey:"pop.userChoseColor")
        guard data.colorMode != value else {return}
        data.colorMode=value;clearGenerated();persist()
    }
    func updateTitle(_ value:String){data.workTitle=value;titleDraft=value;persist()}
    func selectDeck(_ id:UUID) {data.activeDeckID=id;persist()}
    func addDeck(name:String){guard data.decks.count<20 else {message="デッキは最大20個です";return};let deck=UserDeck(name:String(name.prefix(24)),cardIDs:[]);data.decks.append(deck);data.activeDeckID=deck.id;persist()}
    func renameDeck(_ id:UUID,to name:String){guard let i=data.decks.firstIndex(where:{$0.id==id}) else {return};data.decks[i].name=String(name.prefix(24));persist()}
    func deleteDeck(_ id:UUID){guard data.decks.count>1 else {message="デッキは1個以上必要です";return};data.decks.removeAll{$0.id==id};if data.activeDeckID==id {data.activeDeckID=data.decks.first?.id};persist()}
    func toggleDeckCard(_ cardID:String){guard let id=data.activeDeckID,let i=data.decks.firstIndex(where:{$0.id==id}) else {return};if let pos=data.decks[i].cardIDs.firstIndex(of:cardID){data.decks[i].cardIDs.remove(at:pos)} else if data.decks[i].cardIDs.count<12 {data.decks[i].cardIDs.append(cardID)}else{message="1デッキ最大12枚です"};persist()}
    func moveDeckCard(_ cardID:String,by offset:Int){guard let id=data.activeDeckID,let i=data.decks.firstIndex(where:{$0.id==id}),let start=data.decks[i].cardIDs.firstIndex(of:cardID) else {return};let end=start+offset;guard data.decks[i].cardIDs.indices.contains(end) else{return};data.decks[i].cardIDs.swapAt(start,end);persist()}
    func connect(token:String) async {
        guard confirmsFree else {message="Workers Free契約を確認してから接続してください";return}
        guard !cloudflareAccount.isEmpty else {message="Account IDを入力してください";return}
        do {
            let valid=try await CloudflareAIService.verify(account:cloudflareAccount,token:token)
            guard valid else {throw MangaError.server("Cloudflareトークンが無効です")}
            guard CloudflareCredentialVault.save(token) else {throw MangaError.server("iPhoneのKeychainに保存できませんでした")}
            UserDefaults.standard.set(cloudflareAccount,forKey:"cfAccountId")
            isConnected=true
            message="個人GPU接続を確認しました。契約種別はAPIから確認できません。"
        } catch {message="接続失敗：\(error.localizedDescription)"}
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
            let speech = speechEnabled
                ? await MangaSpeechEvidence.around(video:movie,seconds:pin.seconds,duration:duration)
                : ""
            let card=card(for:pin)
            evidence.append(MangaStoryEvidence(
                pinID:pin.id,seconds:pin.seconds,cardID:pin.cardID,
                cardTitle:card.title,cardHint:card.subtitle,visual:visible,
                neighborVisual:neighbor,heard:speech,
                userNote:pin.note,userDialogue:pin.dialogue
            ))
        }
        if online {
            message="カード全体から一つの漫画ストーリーを構成中…（個人のCloudflare枠）"
            return try await MangaStoryAIService.createPlan(
                evidence:evidence,account:account,token:token
            )
        }
        return MangaStoryPlanner.fallback(evidence)
    }

    func generate() async {
        guard !isGenerating else {return}
        guard videoURL != nil else {message="動画を選択してください";return}
        let pins=scenePlan.orderedPins
        guard !pins.isEmpty else {message="まずカードを刺してください";return}
        guard pins.count<=12 else {message="無料枠保護のため一度に12コマまでです。カードは削除していません。";return}
        guard confirmsFree,let token=CloudflareCredentialVault.load(),!cloudflareAccount.isEmpty else {message="自分のWorkers Freeアカウントを接続してください";return}
        let startingSession=videoSession
        let startingRevision=pinsRevision
        let style=data.style
        let colorMode=data.colorMode
        let account=cloudflareAccount
        // Only skip previously completed panels when ALL of their pin IDs and
        // generation settings still match. Do not spend free quota twice on success.
        let resumable = GenerationIntegrity.canResume(
            completedIDs: generated.map(\.id), plannedIDs: pins.map(\.id),
            sameStyle: generatedStyle == style, sameColor: generatedColor == colorMode
        ) && generatedMode == "online" &&
            storyPlan?.beats.map(\.id) == pins.map(\.id)
        if !resumable {clearGenerated()}
        generatedStyle=style;generatedColor=colorMode;generatedMode="online"
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
                storyCreationMode="カード＋動画＋音声からAIが物語を構成"
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
                let card=card(for:pin)
                guard let beat=storyPlan?.beats.first(where:{$0.id==pin.id}) else {
                    throw MangaStoryError.missingPanels
                }
                let seed=Int(UInt32(truncatingIfNeeded:pin.id.uuidString.utf8.reduce(2166136261 as UInt32){($0 ^ UInt32($1)) &* 16777619}))
                let image=try await CloudflareAIService.redraw(
                    image:original,card:card,pin:pin,style:style,colorMode:colorMode,
                    account:account,token:token,seed:seed,
                    story:beat,seriesPremise:storyPlan?.premise ?? ""
                )
                // An in-flight request must never revive old or differently styled results.
                guard startingSession == videoSession && startingRevision == pinsRevision &&
                    style == data.style && colorMode == data.colorMode else {
                    clearGenerated()
                    message="動画・カード・画風が変更されたため古い生成結果を破棄しました。"
                    return
                }
                let warning: String? = {
                    guard let prev=generated.last else {return nil}
                    let originalDifference=ImageDifference.distance(original,prev.original)
                    let generatedDifference=ImageDifference.distance(image,prev.drawing)
                    return originalDifference>0.19 && generatedDifference<0.06 ? "元動画が変化しているのにAI絵が前コマと似ています。元画像を比較してください。" : nil
                }()
                generated.append(PreviewPanel(
                    id:pin.id,cardTitle:card.title,original:original,drawing:image,warning:warning,
                    caption:beat.caption,dialogue:beat.dialogue,
                    storyPrompt:beat.imagePrompt,storyScene:beat.scene
                ))
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
        let pins=scenePlan.orderedPins
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
                id:pin.id,cardTitle:card(for:pin).title,
                original:original,drawing:drawing,warning:nil,
                caption:beat.caption,dialogue:beat.dialogue,
                storyPrompt:beat.imagePrompt,storyScene:beat.scene
            ))
        }
        rebuildPages()
        message="全\(generated.count)コマを端末内で簡易漫画化しました（生成AIではありません）。"
    }
    /// Run actual Core Image post-processing and rebuild all pages for saving.
    /// Preserve an unfiltered baseline so moving a slider never compounds filters.
    func applyFinishing(contrast:Double,brightness:Double,saturation:Double,sharpness:Double) {
        guard hasCompleteComic else {message="すべてのコマ生成後に調整してください";return}
        var finished:[UUID:UIImage]=[:]
        for panel in generated {
            let base=finishingBase[panel.id] ?? panel.drawing
            guard let output=PopPageFinisher.render(base,contrast:contrast,brightness:brightness,
                                                      saturation:saturation,sharpness:sharpness) else {
                message="画質調整に失敗しました。元の漫画は保持しています。"
                return
            }
            finishingBase[panel.id]=base
            finished[panel.id]=output
        }
        for index in generated.indices {
            if let output=finished[generated[index].id] {generated[index].drawing=output}
        }
        rebuildPages()
        message="ページ全体の描線・明るさ・彩度・輪郭を調整しました。"
    }

    /// Retake one existing, ordered panel. Does not modify pins, titles or other
    /// generated panels. Online retry consumes one additional user AI request.
    func regeneratePanel(_ id:UUID) async {
        guard !isGenerating else {return}
        guard let index=generated.firstIndex(where:{$0.id==id}),
              let pin=scenePlan.orderedPins.first(where:{$0.id==id}) else {
            message="選択されたコマを見つけられません";return
        }
        let mode=generatedMode ?? "offline"
        let style=data.style,colorMode=data.colorMode
        let startingSession=videoSession,startingRevision=pinsRevision
        let original=generated[index].original
        let attempt=panelRetryCount[id,default:0]+1
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
                updated=try await CloudflareAIService.redraw(
                    image:original,card:card(for:pin),pin:pin,style:style,colorMode:colorMode,
                    account:cloudflareAccount,token:token,seed:base+attempt*997,
                    story:storyPlan?.beats.first(where:{$0.id==id}),
                    seriesPremise:storyPlan?.premise ?? ""
                )
            }
            guard startingSession==videoSession && startingRevision==pinsRevision &&
                  style==data.style && colorMode==data.colorMode &&
                  generated.indices.contains(index) && generated[index].id==id else {
                message="元データが変更されたため再生成を破棄しました";return
            }
            panelRetryCount[id]=attempt
            finishingBase[id]=updated
            generated[index].drawing=updated
            generated[index].warning=nil
            rebuildPages()
            message="選択コマを再生成しました。保存前に結果を確認してください。"
        } catch {
            message="コマ再生成に失敗しました：\(error.localizedDescription)"
        }
    }
    func chooseOriginal(_ id:UUID){guard let i=generated.firstIndex(where:{$0.id==id}) else {return};finishingBase[id]=nil;generated[i].drawing=generated[i].original;generated[i].warning=nil;rebuildPages()}
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
        var filenames:[String]=[]
        for image in pageImages {
            guard let png=image.pngData() else {
                for name in filenames {try? fm.removeItem(at:support.appendingPathComponent(name))}
                message="漫画ページの変換に失敗しました";return false
            }
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
