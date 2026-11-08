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
    /// All cards attached to this one moment, including secondary emotion cards.
    var allCardIDs: [String] = []
}

struct MangaStoryBeat: Identifiable {
    let id: UUID
    let index: Int
    let caption: String
    let dialogue: String
    let scene: String
    let imagePrompt: String
    let transition: String
    /// Human-readable summary of what physically happens in this panel.
    var plotDescriptionJP: String = ""
    /// Explicit user instructions for how the scene should be drawn.
    var userVisualDirection: String = ""
    /// The expected story function assigned from card semantics and sequence.
    var narrativeDutyJP: String = ""
    /// How the event is caused by, or reacts to, the previous scene.
    var causalLinkJP: String = ""
}

struct MangaStoryPlan {
    let title: String
    let premise: String
    let beats: [MangaStoryBeat]
    let isAIStory: Bool
    var usedVisualEvidence: Bool = false
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
    let plotDescriptionJP: String?
    let causalLinkJP: String?
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
        let cues=MangaNarrativeDirector.cues(for:evidence)
        let beats=evidence.enumerated().map { index,e in
            let cue=cues[index]
            // The offline renderer cannot invent a truthful plot from an
            // unclassified video frame. Never fill missing evidence with
            // generic "dramatic turn" or fabricated "happy ending" captions.
            // The user can explicitly add narration in the review editor.
            let caption: String
            if !e.userNote.isEmpty {caption=clip(e.userNote,46)}
            else if !e.heard.isEmpty {caption=clip(e.heard,46)}
            else {caption=""}
            return MangaStoryBeat(id:e.pinID,index:index+1,caption:caption,
                dialogue:clip(e.userDialogue,35),scene:role(for:e.cardID),
                imagePrompt:"Shot \(index+1): \(cue.role.imageComposition). \(shotHint(for:index)). Story duty: \(cue.role.narrativeRequirement). Constraints: \(cue.evidenceRestrictions). Keep the same protagonists and setting. Combine ALL directions for this single scene: \(e.cardHint). Primary role: \(role(for:e.cardID)). Observed scene: \(e.visual). Transition: \(e.neighborVisual). User note: \(e.userNote).",
                transition:index==0 ? "Opening" : "Continue directly from preceding panel",
                // Story roles are *instructions*, not observed events.
                // Keep the factual scene description empty without a note.
                plotDescriptionJP:clip(e.userNote,100),
                narrativeDutyJP:cue.role.japanese,
                causalLinkJP:"")
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
        let cues=MangaNarrativeDirector.cues(for:evidence)
        // Reject an obviously repeated draft BEFORE spending any image quota.
        // Repeated clothing/location phrases are fine; identical consecutive
        // action+composition and narration are not a story progression.
        for index in 1..<draft.panels.count {
            let a=draft.panels[index-1], b=draft.panels[index]
            let sceneA=normalized(a.imagePrompt+" "+a.scene)
            let sceneB=normalized(b.imagePrompt+" "+b.scene)
            // Two different captions do not make the same picture into a new
            // scene. Require an action or composition change in the storyboard.
            if !sceneA.isEmpty && sceneA==sceneB {
                throw MangaStoryError.repetitiveScenes
            }
        }
        let beats=zip(draft.panels,evidence).enumerated().map { index,pair -> MangaStoryBeat in
            let (line,source)=pair
            let standard=backup.beats[index]
            // Rejecting pseudo-Japanese must never silently replace it with
            // an unrelated dramatic cliché that was not observed in the video.
            // Keep trusted user notes / recognized speech when available;
            // otherwise leave text empty for the storyboard review.
            let trustedCaption = !source.userNote.isEmpty
                ? clip(source.userNote,46)
                : (!source.heard.isEmpty ? clip(source.heard,46) : "")
            return MangaStoryBeat(id:source.pinID,index:index+1,
                caption:japanese(line.caption,otherwise:trustedCaption,limit:46),
                dialogue:!source.userDialogue.isEmpty ? clip(source.userDialogue,35) : japanese(line.dialogue,otherwise:"",limit:35),
                scene:clip(line.scene,120).isEmpty ? standard.scene : clip(line.scene,120),
                imagePrompt:"Shot \(index+1): \(shotHint(for:index)). "+(clip(line.imagePrompt,590).isEmpty ? standard.imagePrompt : clip(line.imagePrompt,590)),
                transition:clip(line.transition,160),
                // The user's pinned description is a hard story constraint.
                // An AI-generated, valid Japanese sentence may still contradict
                // the actual event explicitly entered by the user.
                plotDescriptionJP:source.userNote.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty
                    ? japanese(line.plotDescriptionJP ?? "",otherwise:"",limit:100)
                    : clip(source.userNote,100),
                narrativeDutyJP:cues[index].role.japanese,
                causalLinkJP:index==0 ? "" : japanese(
                    line.causalLinkJP ?? "",otherwise:"",limit:110))
        }
        return MangaStoryPlan(title:japanese(draft.title,otherwise:backup.title,limit:38),
            premise:japanese(draft.premise,otherwise:backup.premise,limit:145),beats:beats,isAIStory:true)
    }

    static func evidenceJSON(_ evidence:[MangaStoryEvidence]) -> String {
        let cues=MangaNarrativeDirector.cues(for:evidence)
        let rows:[[String:Any]]=evidence.enumerated().map { index,e in
            let cue=cues[index]
            return [
                "index":index+1,
                "time":String(format:"%.1f",e.seconds),
                "card":e.cardTitle,"cardIDs":cue.allCardIDs,
                "role":role(for:e.cardID),
                "combinedDirections":clip(e.cardHint,340),
                "storyFunction":cue.role.rawValue,
                "storyFunctionJP":cue.role.japanese,
                "storyDuty":cue.role.narrativeRequirement,
                "evidenceRestrictions":cue.evidenceRestrictions,
                "connectionToPrevious":cue.causalDuty,
                "suggestedShot":cue.role.imageComposition,
                "isCombinedMoment":cue.isCombinedMoment,
                "image":clip(e.visual,140),"betweenFrames":clip(e.neighborVisual,130),
                "speech":clip(e.heard,180),"note":clip(e.userNote,160),
                "dialogue":clip(e.userDialogue,110)
            ]
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
        MangaJapaneseLettering.clean(string,fallback:fallback,limit:limit)
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