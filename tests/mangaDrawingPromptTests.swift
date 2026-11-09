import Foundation

@main struct MangaDrawingPromptTests {
    static func main() {
        let allIDs=[
            "beforeafter","frustration","inspiration","background",
            "finishfood","confession","objectzoom","silhouette",
            "flashback","narration","challenge","embarrass"
        ]
        let input=MangaDrawingPromptInput(
            stylePrompt:String(repeating:"ink ",count:60),
            colorInstruction:String(repeating:"monochrome ",count:30),
            plotAction:"ACTUAL_PLOT_"+String(repeating:"A",count:180),
            userNote:"ORIGINAL_NOTE_"+String(repeating:"注",count:160),
            userDirection:"MANUAL_DIRECTION_"+String(repeating:"指",count:360),
            cardIDs:allIDs,
            cardInstruction:"FUSED_CARD_MEANING_"+String(repeating:"F",count:900),
            visualInstruction:"MANGA_COMPOSITION_"+String(repeating:"V",count:900),
            causalLink:"CAUSE_OF_NEXT_SCENE_"+String(repeating:"C",count:140),
            narrativeRole:String(repeating:"ROLE",count:200),
            referenceInstruction:"0=video moment; 1=previous manga; 2=opening manga, if present. Same identity/line style, NEW action.",
            alternateInstruction:String(repeating:"RETAKE",count:200),
            seriesPremise:String(repeating:"CHAPTER",count:150),
            sceneContext:String(repeating:"CONTEXT",count:150),
            transition:String(repeating:"TRANSITION",count:150),
            consistencyHints:String(repeating:"SOFT_HINT",count:250)
        )
        let packed=MangaDrawingPrompt.compose(input)
        precondition(packed.count<=MangaDrawingPrompt.maxCharacters,
                     "Drawing API must never receive overlong instruction text")
        precondition(packed.hasSuffix(MangaDrawingPrompt.noLettering),
                     "Japanese is drawn with native text; no AI-gibberish glyphs")
        precondition(packed.contains(allIDs.joined(separator:",")),
                     "Every simultaneous card ID must survive a saturated prompt")
        precondition(packed.contains("ORIGINAL_NOTE_"),
                     "User-written original scene notes must never be dropped")
        precondition(packed.contains("MANUAL_DIRECTION_"),
                     "Manual visual direction must outrank the AI plot")
        precondition(packed.contains("FUSED_CARD_MEANING_"),
                     "Card combination is an essential requested scene")
        precondition(packed.contains("MANGA_COMPOSITION_"),
                     "Drawn composition must survive, even with verbose hints")
        precondition(packed.contains("CAUSE_OF_NEXT_SCENE_"),
                     "Scene causality must not be pushed out by the storyboard")
        precondition(packed.contains("0=video moment"),
                     "Panel identity reference must be retained")
        precondition(packed.range(of:"ORIGINAL_NOTE_")!.lowerBound <
                     packed.range(of:"MANGA_COMPOSITION_")!.lowerBound,
                     "User story comes before optional AI composition")
        precondition(packed.range(of:"MANUAL_DIRECTION_")!.lowerBound <
                     packed.range(of:"MANGA_COMPOSITION_")!.lowerBound,
                     "Direct user edits must not be truncated behind suggestions")

        let short=MangaDrawingPromptInput(
            stylePrompt:"shonen ink",colorInstruction:"black ink",
            plotAction:"主人公が鍋を持ち上げる",
            userNote:"面白いオチにしたい",userDirection:"カメラを斜め下から",
            cardIDs:["intro","dramatic"],cardInstruction:"Combine both emotions in ONE event.",
            visualInstruction:"low camera angle on a pan",
            causalLink:"火が強くなったため",narrativeRole:"payoff",
            referenceInstruction:"0=video; 1=previous manga; same clothing",
            alternateInstruction:"change camera distance",
            seriesPremise:"a cooking mistake",sceneContext:"kitchen",
            transition:"follows the flame",consistencyHints:"same jacket and ink style"
        )
        let compact=MangaDrawingPrompt.compose(short)
        precondition(compact.contains("CONSISTENCY: same jacket and ink style"),
                     "Optional continuity details should remain when space permits")
        precondition(compact.contains("WHOLE CHAPTER: a cooking mistake"))
        precondition(compact.contains("intro,dramatic"))
        precondition(!compact.contains("SOFT_HINT"))
        precondition(compact.count<=MangaDrawingPrompt.maxCharacters)
        precondition(compact.hasSuffix(MangaDrawingPrompt.noLettering))
        print("PASS: manga drawing prompt priorities — 12 card IDs, manual notes, causality, continuity and no AI lettering")
    }
}
