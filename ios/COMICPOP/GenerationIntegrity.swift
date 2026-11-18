import Foundation

/// Pure, deterministic rules for mapping time-stamped pin cards to AI manga panels.
/// UIKit and Cloudflare are intentionally excluded so the rules can be unit tested on Linux.
enum GenerationIntegrity {
    static func isComplete(completedIDs: [UUID], plannedIDs: [UUID], pageCount: Int, expectedPageCount: Int, isGenerating: Bool) -> Bool {
        !isGenerating && !plannedIDs.isEmpty &&
            completedIDs == plannedIDs && pageCount == expectedPageCount
    }

    static func canResume(completedIDs: [UUID], plannedIDs: [UUID], sameStyle: Bool, sameColor: Bool) -> Bool {
        !completedIDs.isEmpty && completedIDs.count < plannedIDs.count && sameStyle && sameColor &&
            completedIDs == Array(plannedIDs.prefix(completedIDs.count))
    }
}
