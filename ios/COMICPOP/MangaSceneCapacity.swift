import Foundation

/// A card is an instruction for a video moment, not a paid drawing.
/// Permit combining cards at the same timestamp while bounding screenplay
/// complexity and protecting the 12-image-per-chapter budget.
enum MangaSceneCapacity {
    static let maxScenes=12
    static let maxCardsPerScene=3
    static let maxTotalCards=maxScenes*maxCardsPerScene

    static func canInsert(into pins:[MangaPin],at seconds:Double) -> Bool {
        guard seconds.isFinite,pins.count<maxTotalCards else {return false}
        let planned=MangaPin(cardID:"__capacity__",seconds:seconds,snapshotFile:"")
        let scenes=ScenePlan(pins:pins+[planned]).scenes
        return scenes.count<=maxScenes &&
            scenes.allSatisfy{$0.pins.count<=maxCardsPerScene}
    }
}
