import Foundation

/// Card meaning must be derived from real IDs, never from a fixed "dramatic
/// + horror" example inserted into every multi-card prompt.
enum MangaCardFusion {
    static func instruction(cardIDs:[String],title:String,subtitle:String)->String {
        let ids=Set(cardIDs.map{$0.lowercased()})
        if ids.count>1 && ids.contains("dramatic") && ids.contains("horror") {
            return "ONE SINGLE VIDEO MOMENT, ONE manga illustration. Blend DRAMATIC and HORROR: a high-stakes event, striking cinematic perspective, visible fear and ominous lighting. The same event must not become two near-identical panels."
        }
        if ids.count>1 {
            return "ONE SINGLE VIDEO MOMENT, ONE manga illustration. Combine ONLY these inserted cards: \(title). Their actual direction is: \(subtitle). Any new action or emotion must come from these cards or directly from the video/story, not from examples of unrelated card combinations."
        }
        return "Express ONLY this inserted card in the scene: \(title), \(subtitle). Other unrelated emotional effects are not requested."
    }
}
