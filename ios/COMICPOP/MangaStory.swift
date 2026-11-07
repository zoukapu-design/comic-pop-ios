import Foundation

struct MangaStoryEvidence {
    let pinID: UUID
    let seconds: Double
    let cardID: String
    let cardTitle: String
    let cardHint: String
    let visual: String
    let neighborVisual: String
    let heard: String
    let userNote: String
    let userDialogue: String
}

struct MangaStoryBeat: Identifiable {
    let id: UUID
    let index: Int
    let caption: String
    let dialogue: String
    let scene: String
    let imagePrompt: String
    let transition: String
}

struct MangaStoryPlan {
    let title: String
    let premise: String
    let beats: [MangaStoryBeat]
    let isAIStory: Bool
}

private struct AIStoryDocument: Decodable {
    let title: String
    let premise: String
    let panels: [AIStoryPanel]
}
private struct AIStoryPanel: Decodable {
    let index: Int
    let caption: String
    let dialogue: String
    let scene: String
    let imagePrompt: String
    let transition: String
}

enum MangaStoryPlanner {
    static func role(for id: String) -> String {
        switch id {
        case "intro", "setup": return "導入：人物・場所・目的を示す"
        case "slow", "freeze": return "伏線：緊張感を高め次の出来事に備える"
        case "dramatic", "climax", "action": return "山場：前後の因果を描く"
        case "tsukkomi", "reaction": return "直前へのリアクション・ツッコミ"
        case "idea", "reveal": return "気付き：前の情報を新しい発見につなぐ"
        case "sad", "taste": return "感情：人物が出来事を受け止める"
        case "large", "foodzoom": return "見せ場：重要な物や動作を大きく描く"
        case "horror", "fear": return "恐怖：人物の表情・不穏な照明・緊迫した空気を作る"
        case "punch", "ending": return "オチ・結末：展開を回収して閉じる"
        default: return "前後の場面がつながる一幕"
        }
    }

    static func fallback(_ evidence: [MangaStoryEvidence]) -> MangaStoryPlan {
        let beats=evidence.enumerated().map { index,e in
            let caption: String
            if !e.userNote.isEmpty {caption=clip(e.userNote,46)}
            else if !e.heard.isEmpty {caption=clip(e.heard,46)}
            else if index==0 {caption="こうして、一つの出来事が始まった。"}
            else if index==evidence.count-1 {caption="そして、物語はひとつの結末へ。"}
            else {caption=["そのとき、思わぬ展開が。","けれど、まだ終わらない。","次の瞬間、状況が動いた。"][index%3]}
            return MangaStoryBeat(id:e.pinID,index:index+1,caption:caption,
                dialogue:clip(e.userDialogue,35),scene:role(for:e.cardID),
                imagePrompt:"Shot \(index+1): \(shotHint(for:index)). Keep the same protagonists and setting. Combine ALL directions for this single scene: \(e.cardHint). Primary role: \(role(for:e.cardID)). Observed scene: \(e.visual). Transition: \(e.neighborVisual). User note: \(e.userNote).",
                transition:index==0 ? "Opening" : "Continue directly from preceding panel")
        }
        return MangaStoryPlan(title:"動画から生まれた物語",premise:"カードから組み立てた仮の構成",beats:beats,isAIStory:false)
    }

    static func decodeAIStory(_ raw: String, evidence: [MangaStoryEvidence]) throws -> MangaStoryPlan {
        guard !evidence.isEmpty,
              let first=raw.firstIndex(of:"{"),let last=raw.lastIndex(of:"}"),first<last else {
            throw MangaStoryError.invalidJSON
        }
        let bytes=Data(raw[first...last].utf8)
        guard let draft=try? JSONDecoder().decode(AIStoryDocument.self,from:bytes),
              draft.panels.count==evidence.count,
              draft.panels.map(\.index)==Array(1...evidence.count) else {
            throw MangaStoryError.missingPanels
        }
        let backup=fallback(evidence)
        // Reject an obviously repeated draft BEFORE spending any image quota.
        // Repeated clothing/location phrases are fine; identical consecutive
        // action+composition and narration are not a story progression.
        for index in 1..<draft.panels.count {
            let a=draft.panels[index-1], b=draft.panels[index]
            let sceneA=normalized(a.imagePrompt+" "+a.scene)
            let sceneB=normalized(b.imagePrompt+" "+b.scene)
            let textA=normalized(a.caption+" "+a.dialogue)
            let textB=normalized(b.caption+" "+b.dialogue)
            if !sceneA.isEmpty && sceneA==sceneB && textA==textB {
                throw MangaStoryError.repetitiveScenes
            }
        }
        let beats=zip(draft.panels,evidence).enumerated().map { index,pair -> MangaStoryBeat in
            let (line,source)=pair
            let standard=backup.beats[index]
            return MangaStoryBeat(id:source.pinID,index:index+1,
                caption:japanese(line.caption,otherwise:standard.caption,limit:46),
                dialogue:!source.userDialogue.isEmpty ? clip(source.userDialogue,35) : japanese(line.dialogue,otherwise:"",limit:35),
                scene:clip(line.scene,120).isEmpty ? standard.scene : clip(line.scene,120),
                imagePrompt:"Shot \(index+1): \(shotHint(for:index)). "+(clip(line.imagePrompt,590).isEmpty ? standard.imagePrompt : clip(line.imagePrompt,590)),
                transition:clip(line.transition,160))
        }
        return MangaStoryPlan(title:japanese(draft.title,otherwise:backup.title,limit:38),
            premise:japanese(draft.premise,otherwise:backup.premise,limit:145),beats:beats,isAIStory:true)
    }

    static func evidenceJSON(_ evidence:[MangaStoryEvidence]) -> String {
        let rows=evidence.enumerated().map { index,e in
            ["index":String(index+1),"time":String(format:"%.1f",e.seconds),
             "card":e.cardTitle,"role":role(for:e.cardID),
             "combinedDirections":clip(e.cardHint,340),
             "image":clip(e.visual,140),"betweenFrames":clip(e.neighborVisual,130),
             "speech":clip(e.heard,180),"note":clip(e.userNote,160),
             "dialogue":clip(e.userDialogue,110)]
        }
        guard let data=try? JSONSerialization.data(withJSONObject:rows,options:[.sortedKeys]),
              let string=String(data:data,encoding:.utf8) else {return "[]"}
        return string
    }

    /// Global shot grammar encourages varied camera distances across scenes,
    /// while the actual shot content still comes from the full-story AI.
    private static func shotHint(for index:Int) -> String {
        let shots=[
            "establishing wide shot with location and protagonist",
            "medium shot showing a clear action and spatial relation",
            "expressive close-up of changed character emotion",
            "dynamic cinematic angle revealing an important new event",
            "tight reaction shot or meaningful object detail",
            "wide payoff or aftermath with visible narrative consequence"
        ]
        return shots[index % shots.count]
    }
    private static func normalized(_ value:String)->String {
        value.lowercased().filter{!$0.isWhitespace && !$0.isNewline}
    }

    private static func japanese(_ string:String,otherwise fallback:String,limit:Int)->String {
        let value=clip(string,limit)
        let valid=value.unicodeScalars.contains { (0x3040...0x30ff).contains(Int($0.value)) || (0x3400...0x9fff).contains(Int($0.value)) }
        return valid ? value : fallback
    }
    private static func clip(_ value:String,_ limit:Int)->String {
        String(value.replacingOccurrences(of:"\n",with:" ")
            .replacingOccurrences(of:"\r",with:" ")
            .trimmingCharacters(in:.whitespacesAndNewlines).prefix(limit))
    }
}

enum MangaStoryError: LocalizedError {
    case invalidJSON,missingPanels,repetitiveScenes
    var errorDescription:String? {
        switch self {
        case .invalidJSON:return "ストーリー案のデータを読み取れませんでした。もう一度試してください。"
        case .missingPanels:return "ストーリー案が全シーン分ありません。もう一度試してください。"
        case .repetitiveScenes:return "連続コマの内容とセリフが重複しています。作画前に脚本を作り直してください。"
        }
    }
}