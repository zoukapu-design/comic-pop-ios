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

        // Three emotional/directing cards at one time may each contain a
        // 260-character personal note. No third note may be silently dropped
        // merely because the whole chapter has many scene constraints.
        let longNotes=[
            "カード1："+String(repeating:"始",count:255),
            "カード2："+String(repeating:"驚",count:255),
            "カード3："+String(repeating:"終",count:255)
        ].joined(separator:" / ")
        let dense=MangaDrawingPromptInput(
            stylePrompt:String(repeating:"s",count:120),
            colorInstruction:String(repeating:"c",count:80),
            plotAction:"主人公が新しい行動を始める",
            userNote:longNotes,
            userDirection:String(repeating:"D",count:280),
            cardIDs:["dramatic","horror","punch"],
            cardInstruction:String(repeating:"E",count:110),
            visualInstruction:String(repeating:"V",count:120),
            causalLink:String(repeating:"C",count:70),
            narrativeRole:String(repeating:"R",count:95),
            referenceInstruction:String(repeating:"P",count:90),
            alternateInstruction:"",seriesPremise:"",
            sceneContext:"",transition:"",consistencyHints:""
        )
        let densePrompt=MangaDrawingPrompt.compose(dense)
        precondition(densePrompt.count<=MangaDrawingPrompt.maxCharacters)
        precondition(densePrompt.hasSuffix(MangaDrawingPrompt.noLettering))
        precondition(densePrompt.contains(longNotes),
                     "All 3 original notes must survive prompt packing, in full")
        precondition(densePrompt.contains("dramatic,horror,punch"),
                     "All merged card identities must remain in the drawing prompt")
        precondition(densePrompt.contains("HIGHEST PRIORITY USER DIRECTION"),
                     "Manually reviewed drawing direction must not disappear")
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
        // A user's request for a scary tone is not proof of a filmed scary
        // action. It must remain an artistic direction, not a fabricated fact.
        let emotionOnly=MangaDrawingPromptInput(
            stylePrompt:"noir ink",colorInstruction:"monochrome",
            plotAction:"",userNote:"怖く演出して",userDirection:"",
            cardIDs:["horror"],cardInstruction:"Make the atmosphere unsettling",
            visualInstruction:"dim corridor from the source video",
            causalLink:"",narrativeRole:"crisis",
            referenceInstruction:"0=video moment",
            alternateInstruction:"",seriesPremise:"",
            sceneContext:"",transition:"",consistencyHints:""
        )
        let emotionPrompt=MangaDrawingPrompt.compose(emotionOnly)
        precondition(!emotionPrompt.contains("ACTUAL PLOT EVENT"),
                     "Missing observed action must not be replaced by a mood")
        precondition(emotionPrompt.contains("USER'S ORIGINAL CARD NOTE (HIGH PRIORITY): 怖く演出して"),
                     "Emotional direction must still reach image inference")
        precondition(emotionPrompt.count<=MangaDrawingPrompt.maxCharacters)
        // A source-locked manga must NOT depict the model's invented plot
        // as a factual visual event. Even saturated combined card notes remain.
        let strict=MangaDrawingPrompt.compose(dense,sourceLocked:true)
        precondition(strict.count<=MangaDrawingPrompt.maxCharacters)
        precondition(strict.hasSuffix(MangaDrawingPrompt.noLettering))
        precondition(strict.contains("SOURCE-LOCKED IMAGE EDIT OF input_image_0"))
        precondition(strict.contains(longNotes),"The source lock must not delete original notes")
        precondition(strict.contains("dramatic,horror,punch"),
                     "All three same-timestamp cards must survive strict mode")
        precondition(!strict.contains("ACTUAL PLOT EVENT"),
                     "Source-locked visuals must ignore unsupported screenplay events")
        precondition(!strict.contains("SHOT VARIETY"),
                     "Do not hallucinate another pose to make scenes different")
        precondition(strict.contains("MANGA STYLE ONLY"))
        precondition(strict.contains("REFERENCE: input_image_0"),
                     "Strict mode must use the actual video frame as sole reference")
        print("PASS: source-locked manga prompt preserves source subject, card notes and all card IDs without invented actions")
        print("PASS: manga drawing prompt priorities — 12 card IDs, manual notes, causality, continuity and no AI lettering")
    }
}
