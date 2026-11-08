import Foundation

/// A narrative role is NOT another panel and does not change card counts.
/// It is a responsibility assigned to the scene created from inserted cards.
enum MangaNarrativeRole: String {
    case standalone
    case introduction
    case foreshadowing
    case development
    case crisis
    case reaction
    case discovery
    case climax
    case payoff
    case openEnding

    var japanese: String {
        switch self {
        case .standalone: return "一場面の見せ場"
        case .introduction: return "導入・状況提示"
        case .foreshadowing: return "伏線・緊張の積み上げ"
        case .development: return "展開・状況の変化"
        case .crisis: return "危機・緊迫した山場"
        case .reaction: return "前の出来事への反応"
        case .discovery: return "発見・気付き"
        case .climax: return "クライマックス"
        case .payoff: return "回収・結末"
        case .openEnding: return "余韻・次への引き"
        }
    }

    var imageComposition: String {
        switch self {
        case .standalone:
            return "A clear visual gag or decisive single-panel event, one unambiguous focal point"
        case .introduction:
            return "Wide establishing shot explaining protagonist, goal and surrounding location"
        case .foreshadowing:
            return "Close shot of a significant gesture or clue, anticipation before the next action"
        case .development:
            return "Medium action shot showing protagonist doing something NEW and its visible consequence"
        case .crisis:
            return "Dramatic angle, anxious expression and ominous atmosphere in ONE intense scene"
        case .reaction:
            return "Expressive close-up or two-shot showing a visible reaction to the previous event"
        case .discovery:
            return "Reveal an important object, realization or changed facial expression"
        case .climax:
            return "Dynamic full-body action, decisive peak of the conflict with readable staging"
        case .payoff:
            return "Show the consequence of the prior setup, a resolved outcome or clear punchline"
        case .openEnding:
            return "Show the truthful last visible state and leave a believable question or aftermath"
        }
    }

    var narrativeRequirement: String {
        switch self {
        case .standalone:
            return "このカードの見せ場を、一目で状況が伝わる独立した場面にする"
        case .introduction:
            return "主人公・場所・挑戦することを示し、次に何が起きるかを期待させる"
        case .foreshadowing:
            return "次の出来事に関係する具体的な手掛かりを描き、意味のない引き延ばしをしない"
        case .development:
            return "直前から人物の行動か状況を実際に変化させる"
        case .crisis:
            return "何に恐怖・緊張を感じているのかを出来事で示し、同じ場面の感情カードを合成する"
        case .reaction:
            return "直前の出来事に誰がどう反応したか分かるように描く"
        case .discovery:
            return "それまでの行動に結びつく新しい気付きや情報を示す"
        case .climax:
            return "物語の山場を原因と結果が分かる動作・表情・構図で描く"
        case .payoff:
            return "先に示した挑戦・伏線・トラブルの結果を描き、無関係なオチを作らない"
        case .openEnding:
            return "動画から確認できない完了・成功を捏造せず、最後の状態を余韻として描く"
        }
    }
}

struct MangaNarrativeCue {
    let index: Int
    let role: MangaNarrativeRole
    let allCardIDs: [String]
    let causalDuty: String
    let isCombinedMoment: Bool
}

enum MangaNarrativeDirector {
    /// Preserves user card meaning even for a two-card merged moment.
    /// With fewer than four scenes we do not hallucinate a four-act plot.
    static func cues(for evidence: [MangaStoryEvidence]) -> [MangaNarrativeCue] {
        evidence.enumerated().map { index,scene in
            let ids = scene.allCardIDs.isEmpty ? [scene.cardID] : scene.allCardIDs
            let role = chooseRole(ids:ids,index:index,count:evidence.count)
            let causal: String
            if index==0 {
                causal="最初の状況と挑戦を示す。未確認の過去の出来事を事実として作らない"
            } else {
                let previous = evidence[index-1]
                causal="直前のシーン\(index)（カード：\(previous.cardTitle)）から現在の出来事へ、原因→行動→結果のつながりを一つ以上示す。観測できない事実は推測として扱う"
            }
            return MangaNarrativeCue(index:index+1,role:role,
                                     allCardIDs:ids,causalDuty:causal,
                                     isCombinedMoment:ids.count>1)
        }
    }

    private static func chooseRole(ids:[String],index:Int,count:Int)->MangaNarrativeRole {
        let tags=Set(ids.map{$0.lowercased()})
        if count==1 {return .standalone}
        if tags.contains("punch") || tags.contains("ending") {
            return .payoff
        }
        // Combine dramatic + horror as a crisis, never as two separate scenes.
        if tags.contains("horror") || tags.contains("fear") {
            return .crisis
        }
        if tags.contains("tsukkomi") || tags.contains("reaction") {
            return .reaction
        }
        if tags.contains("idea") || tags.contains("reveal") {
            return .discovery
        }
        if tags.contains("dramatic") || tags.contains("climax") ||
           tags.contains("action") {
            return .climax
        }
        if index==0 || tags.contains("intro") || tags.contains("setup") {
            return .introduction
        }
        if tags.contains("slow") || tags.contains("freeze") {
            return .foreshadowing
        }
        if index==count-1 {
            // Do not invent a successful ending when the video only ends.
            return .openEnding
        }
        return .development
    }
}
