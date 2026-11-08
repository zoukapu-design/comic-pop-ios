import Foundation

/// Deterministic entry point for the genre screen. An existing comic should
/// never appear as a new AI job, and partial panels must remain resumable.
enum MangaGenerationRoute: Equatable {
    case chooseMode
    case reviewStoryboard
    case resumeOffline
    case resumeOnline
    case viewCompleted

    static func resolve(
        hasCompleteComic: Bool,
        generatedPanelCount: Int,
        generatedOffline: Bool,
        storyboardReady: Bool
    ) -> MangaGenerationRoute {
        if hasCompleteComic { return .viewCompleted }
        if generatedPanelCount > 0 {
            return generatedOffline ? .resumeOffline : .resumeOnline
        }
        if storyboardReady { return .reviewStoryboard }
        return .chooseMode
    }
}
