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
    let evidenceRestrictions: String
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
            let limitations=storyRestrictions(ids)
            return MangaNarrativeCue(index:index+1,role:role,
                                     allCardIDs:ids,causalDuty:causal,
                                     evidenceRestrictions:limitations,
                                     isCombinedMoment:ids.count>1)
        }
    }

    private static func storyRestrictions(_ ids:[String]) -> String {
        let tags=Set(ids.map{$0.lowercased()})
        var rules:[String]=[]
        if tags.contains("exact") {
            rules.append("元の人物・行動・場所を忠実に反映し、映像と矛盾する出来事を推測で作らない")
        }
        if tags.contains("noextra") {
            rules.append("動画で確認できない登場人物・動物・重要物を勝手に追加しない")
        }
        if tags.contains("quote") {
            rules.append("引用セリフはユーザー入力や確認できた字幕・音声だけを使い、発言を創作しない")
        }
        if tags.contains("must") {
            rules.append("このシーンを必ず物語の展開に採用する")
        }
        if tags.contains("context") || tags.contains("before") {
            rules.append("前後の場面を見て、切り出した1枚の誤認識を避ける")
        }
        return rules.joined(separator:"。")
    }

    private static func chooseRole(ids:[String],index:Int,count:Int)->MangaNarrativeRole {
        let tags=Set(ids.map{$0.lowercased()})
        func includes(_ choices:[String])->Bool {
            !tags.isDisjoint(with:choices)
        }
        if count==1 {return .standalone}

        // Concrete story/food/result cards matter more than decorative effects.
        if includes(["punch","ending","finishfood","success","triumph","after"]) {
            return .payoff
        }
        // When both dramatic and horror are inserted, the final role is ONE
        // crisis scene and ALL cards still drive its drawing.
        if includes(["horror","fear","failure","chaos","sweat","frustration"]) {
            return .crisis
        }
        if includes(["tsukkomi","reaction","cry","anger","embarrass",
                     "awkward","relief","happy","smile","crowd","funny"]) {
            return .reaction
        }
        if includes(["idea","inspiration","reveal","beforeafter","compare"]) {
            return .discovery
        }
        if includes(["dramatic","climax","impact"]) {
            return .climax
        }
        if index==0 || includes(["intro","setup","challenge","panorama"]) {
            return .introduction
        }
        if includes(["slow","freeze","suspense","tension","shadow",
                     "flashback","pause","silence"]) {
            return .foreshadowing
        }
        if index==count-1 {
            // If no explicit result card or observed outcome exists, do not
            // force a fake victory or disaster into the last panel.
            return .openEnding
        }
        return .development
    }
}
