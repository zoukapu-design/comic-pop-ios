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
}

@MainActor final class StudioStore: ObservableObject {
    @Published private(set) var data: StudioData
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var generated: [PreviewPanel] = []
    @Published var pageImages: [UIImage] = []
    @Published var isGenerating = false
    @Published var message = "カードを刺して漫画を作ろう"
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

    private let fm = FileManager.default
    private let support: URL
    private var modelURL: URL { support.appendingPathComponent("studio.json") }
    var videoURL:URL? {data.videoFile.map{support.appendingPathComponent($0)}}
    var tokenExists: Bool {CloudflareCredentialVault.load() != nil}
    var selectedDeck: UserDeck? {data.decks.first(where:{$0.id == data.activeDeckID}) ?? data.decks.first}
    var cards: [PinDefinition] {catalog}
    var scenePlan: ScenePlan {ScenePlan(pins:data.pins)}

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
    private func persist() {
        do { let out=try JSONEncoder().encode(data);try out.write(to:modelURL,options:.atomic) }
        catch {message="端末への保存に失敗しました：\(error.localizedDescription)"}
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
            data.pins=[];generated=[];pageImages=[];duration=0;currentTime=0
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
        guard let url=videoURL else {message="先に動画を選んでください";return}
        let seconds=currentTime
        let capturedSession=videoSession
        let capturedReset=pinsResetEpoch
        do {
            let frame=try await VideoFrameService.frame(at:seconds,from:url)
            // AVFoundation frame extraction may finish AFTER the user selects another video or clears pins.
            guard capturedSession == videoSession && capturedReset == pinsResetEpoch else { return }
            guard let bytes=VideoFrameService.compactJPEG(frame) else {throw MangaError.invalidImage}
            let file="pin-\(UUID().uuidString).jpg"
            try bytes.write(to:support.appendingPathComponent(file),options:.atomic)
            data.pins.append(MangaPin(cardID:card.id,seconds:seconds,snapshotFile:file))
            pinsRevision = UUID()
            persist();message="\(formatted(seconds)) に「\(card.title)」を挿入しました。"
        } catch {message="その場面を保存できませんでした：\(error.localizedDescription)"}
    }
    func removePin(_ pin:MangaPin){data.pins.removeAll{$0.id==pin.id};pinsRevision=UUID();try? fm.removeItem(at:support.appendingPathComponent(pin.snapshotFile));generated=[];pageImages=[];persist()}
    func clearPins(){pinsResetEpoch=UUID();pinsRevision=UUID();for p in data.pins {try? fm.removeItem(at:support.appendingPathComponent(p.snapshotFile))};data.pins=[];generated=[];pageImages=[];persist()}
    func snapshot(for pin:MangaPin)->UIImage? {UIImage(contentsOfFile:support.appendingPathComponent(pin.snapshotFile).path)}
    func card(for pin:MangaPin)->PinDefinition {catalog.first(where:{$0.id==pin.cardID}) ?? catalog[0]}
    func updateStyle(_ style:String) {data.style=style;data.colorMode=MangaStyles.all.first(where:{$0.id==style})?.defaultColor ?? "mono";persist()}
    func updateColor(_ value:String){data.colorMode=value;persist()}
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
    func generate() async {
        guard !isGenerating else {return}
        guard videoURL != nil else {message="動画を選択してください";return}
        guard !scenePlan.orderedPins.isEmpty else {message="まずカードを刺してください";return}
        guard scenePlan.orderedPins.count<=12 else {message="無料枠保護のため一度に12コマまでです。カードは削除していません。";return}
        guard confirmsFree,let token=CloudflareCredentialVault.load(),!cloudflareAccount.isEmpty else {message="自分のWorkers Freeアカウントを接続してください";return}
        isGenerating=true;generated=[];pageImages=[]
        defer {isGenerating=false}
        let startingSession=videoSession
        let startingRevision=pinsRevision
        let pins=scenePlan.orderedPins
        for (index,pin) in pins.enumerated() {
            do {
                guard let original=snapshot(for:pin) else {throw MangaError.invalidImage}
                message="AIで描き直しています \(index+1)/\(pins.count)（ユーザーの無料枠）"
                let card=card(for:pin)
                // Each frame has a unique deterministic seed; no previous scene image is supplied.
                let seed=Int(UInt32(truncatingIfNeeded:pin.id.uuidString.utf8.reduce(2166136261 as UInt32){($0 ^ UInt32($1)) &* 16777619}))
                let image=try await CloudflareAIService.redraw(image:original,card:card,pin:pin,style:data.style,colorMode:data.colorMode,account:cloudflareAccount,token:token,seed:seed)
                // Do not show a completed image belonging to an old video after a video switch.
                guard startingSession == videoSession && startingRevision == pinsRevision else {
                    message="動画またはピンカードが変更されたため、以前の生成結果を破棄しました。"
                    generated=[];pageImages=[];return
                }
                let warning: String? = {
                    guard let prev=generated.last else {return nil}
                    let originalDifference=ImageDifference.distance(original,prev.original)
                    let generatedDifference=ImageDifference.distance(image,prev.drawing)
                    return originalDifference>0.19 && generatedDifference<0.06 ? "元動画が変化しているのにAI絵が前コマと似ています。元画像を比較してください。" : nil
                }()
                generated.append(PreviewPanel(id:pin.id,cardTitle:card.title,original:original,drawing:image,warning:warning))
            } catch {
                // A failed request may complete after video/pin replacement; never revive an old page.
                guard startingSession == videoSession && startingRevision == pinsRevision else {
                    generated=[];pageImages=[];return
                }
                message="\(index)/\(pins.count)コマ作成後に停止：\(error.localizedDescription)。未生成のカードは残っています。"
                rebuildPages();return
            }
        }
        rebuildPages();message="全\(generated.count)コマのAI描き直しが完了。各コマを確認してください。"
    }
    func chooseOriginal(_ id:UUID){guard let i=generated.firstIndex(where:{$0.id==id}) else {return};generated[i].drawing=generated[i].original;generated[i].warning=nil;rebuildPages()}
    func rebuildPages(){pageImages=stride(from:0,to:generated.count,by:4).map{i in ComicRenderer.page(panels:Array(generated[i..<min(i+4,generated.count)]),title:data.workTitle.isEmpty ? "COMIC POP!" : data.workTitle,pageNumber:i/4+1,total:Int(ceil(Double(generated.count)/4)))} }
    func saveWork() {
        guard !pageImages.isEmpty else {message="漫画が生成されていません";return}
        var filenames:[String]=[]
        for image in pageImages {guard let png=image.pngData() else {continue};let name="comic-\(UUID().uuidString).png";do{try png.write(to:support.appendingPathComponent(name));filenames.append(name)}catch{}}
        guard !filenames.isEmpty else {message="漫画を保存できませんでした";return}
        data.works.insert(SavedWork(id:UUID(),title:data.workTitle.isEmpty ? "漫画 \(Date().formatted(date:.abbreviated,time:.shortened))" : data.workTitle,files:filenames,createdAt:Date(),sceneCount:generated.count,style:data.style),at:0)
        persist();message="作品一覧に保存しました"
    }
    func workImages(_ work:SavedWork)->[UIImage]{work.files.compactMap{UIImage(contentsOfFile:support.appendingPathComponent($0).path)}}
    func formatted(_ seconds:Double)->String {String(format:"%02d:%02d",Int(max(0,seconds))/60,Int(max(0,seconds))%60)}
}

private extension Data {
    func decodeCards() throws -> [PinDefinition] {try JSONDecoder().decode([PinDefinition].self,from:self)}
}
