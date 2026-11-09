import Foundation

/// A style/colour edit invalidates all draft artwork and its screenplay.
/// The decision must be resolved before changing user-visible project state.
enum MangaAppearanceChangePolicy: Equatable {
    case unchanged
    case applyNow
    case needsDiscardConfirmation
    case blockedWhileGenerating

    static func decide(
        isGenerating: Bool,
        hasUncommittedGeneration: Bool,
        isSameSelection: Bool
    ) -> MangaAppearanceChangePolicy {
        if isSameSelection { return .unchanged }
        if isGenerating { return .blockedWhileGenerating }
        if hasUncommittedGeneration { return .needsDiscardConfirmation }
        return .applyNow
    }
}
