import Foundation

/// Quota-safe prompt packing for the per-panel drawing API. Crucial story
/// events, original card notes and *every* inserted card ID must survive
/// the model's 2400-character budget; only supplementary hints may be dropped.
struct MangaDrawingPromptInput {
    let stylePrompt:String
    let colorInstruction:String
    let plotAction:String
    let userNote:String
    let userDirection:String
    let cardIDs:[String]
    let cardInstruction:String
    let visualInstruction:String
    let causalLink:String
    let narrativeRole:String
    let referenceInstruction:String
    let alternateInstruction:String
    let seriesPremise:String
    let sceneContext:String
    let transition:String
    let consistencyHints:String
}

enum MangaDrawingPrompt {
    static let maxCharacters=2400
    static let noLettering="ABSOLUTELY NO WORDS, NO KANJI, NO FAKE LETTERS OR SPEECH BALLOONS. APP TYPESETS ALL JAPANESE LETTERING AFTER GENERATION."

    static func compose(_ input:MangaDrawingPromptInput,sourceLocked:Bool = false)->String {
        var parts:[String]=[]
        let reserved=noLettering.count+1
        var used=reserved

        func add(_ label:String,_ source:String,max:Int,required:Bool) {
            let value=String(source.trimmingCharacters(in:.whitespacesAndNewlines).prefix(max))
            guard !value.isEmpty else {return}
            let text=label.isEmpty ? value : "\(label): \(value)"
            let separator=parts.isEmpty ? 0 : 1
            let available=maxCharacters-used-separator
            guard available>0 else {return}
            if text.count<=available {
                parts.append(text)
                used+=text.count+separator
            } else if required {
                // Required directions are packed first with bounded fields;
                // overflow cannot spill into the reserved NO-LETTERING rule.
                parts.append(String(text.prefix(available)))
                used+=available+separator
            }
        }

        if sourceLocked {
            // A source frame is evidence, NOT a suggestion. Give this the
            // highest prompt priority: no storyboard, previous drawing or
            // creativity directive may turn the subject into someone else.
            // The rest of the book's story is lettered separately by the app.
            add("",MangaSourceFidelityPolicy.lockedSourceRule,max:500,required:true)
            add("MANGA STYLE ONLY",input.stylePrompt,max:90,required:true)
            add("INK / TONES ONLY",input.colorInstruction,max:70,required:true)
            add("USER NOTES: APPLY AS VISUAL MOOD ONLY",
                input.userNote,max:800,required:true)
            add("USER ART DIRECTION: STYLE ONLY",
                input.userDirection,max:200,required:true)
            add("ALL INSERTED CARD IDS (SAME VIDEO FRAME)",
                input.cardIDs.joined(separator:","),max:150,required:true)
            add("CARD MOOD",MangaSourceFidelityPolicy.sceneMood,
                max:100,required:true)
            add("REFERENCE",MangaSourceFidelityPolicy.sourceReference,
                max:125,required:true)
            return parts.joined(separator:" ")+" "+noLettering
        }

        // Dense combined moments can contain three separate 260-character
        // user notes. Preserve all notes before spending space on optional
        // artistic details and long image-model scene speculation.
        let denseNotes=input.userNote.count>160
        // The maximum required fields for denseNotes occupy at most 2397
        // characters including labels and the reserved NO-LETTERING rule.
        // The order is intentional. Never put long AI speculation before the
        // user's original notes or the simultaneous-card instructions.
        add("", "Create ONE new sequential Japanese manga illustration, not a photo filter.",
            max:80,required:true)
        add("STYLE",input.stylePrompt,max:120,required:true)
        add("COLOR",input.colorInstruction,max:denseNotes ? 80 : 95,required:true)
        add("ACTUAL PLOT EVENT (reviewed storyboard)",input.plotAction,
            max:denseNotes ? 105 : 150,required:true)
        add("USER'S ORIGINAL CARD NOTE (HIGH PRIORITY)",input.userNote,
            max:denseNotes ? 800 : 160,required:true)
        add("HIGHEST PRIORITY USER DIRECTION",input.userDirection,
            max:denseNotes ? 280 : 300,required:true)
        // Each card ID appears in full, even when a long card subtitle needs
        // shortening. One scene, not one separate illustration per card.
        add("ALL INSERTED CARD IDS (ONE SHARED SCENE)",
            input.cardIDs.joined(separator:","),max:denseNotes ? 140 : 150,required:true)
        add("COMBINED CARD DIRECTIVES (ONE PANEL)",input.cardInstruction,
            max:denseNotes ? 110 : 330,required:true)
        add("DRAW THIS SPECIFIC EVENT AND COMPOSITION",input.visualInstruction,
            max:denseNotes ? 120 : 380,required:true)
        // Causality and continuity refs are short enough to fit even when all
        // high-priority storyboard and multi-card fields reach their caps.
        add("CAUSE",input.causalLink,max:denseNotes ? 70 : 110,required:true)
        add("IMAGE REFS",input.referenceInstruction,max:denseNotes ? 90 : 105,required:true)

        // Optional context improves composition when capacity permits,
        // without ever hiding user-authored directions or required cards.
        add("STORY ROLE",input.narrativeRole,max:95,required:false)
        add("SHOT VARIETY",input.alternateInstruction,max:150,required:false)
        add("WHOLE CHAPTER",input.seriesPremise,max:145,required:false)
        add("SCENE CONTEXT",input.sceneContext,max:120,required:false)
        add("TRANSITION",input.transition,max:125,required:false)
        add("CONSISTENCY",input.consistencyHints,max:240,required:false)

        return parts.joined(separator:" ")+" "+noLettering
    }
}
