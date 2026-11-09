import Foundation

/// Source-independent permission check for destructive editor mutations.
/// All actual deletion happens after a successful atomic StudioData commit.
enum MangaDraftEditGuard {
    static func allowsChange(hasDraft: Bool, confirmed: Bool) -> Bool {
        !hasDraft || confirmed
    }

    static func mayApply(
        isGenerating: Bool, hasDraft: Bool,
        confirmed: Bool, hasActualChange: Bool
    ) -> Bool {
        if !hasActualChange {return true}
        return !isGenerating && allowsChange(hasDraft:hasDraft,confirmed:confirmed)
    }
}
