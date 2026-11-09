import Foundation

/// A restart-safe, local-only generation checkpoint. No API token, audio,
/// source-video bytes or unapproved uploads are stored in this document.
struct MangaDraftArtwork: Codable, Equatable {
    let id: UUID
    let drawingFile: String
    let cardTitle: String
    let caption: String
    let dialogue: String
    let storyPrompt: String
    let storyScene: String
}

struct MangaDraftCheckpoint: Codable {
    let version: Int
    let videoFile: String
    let sourcePins: [MangaPin]
    let sceneIDs: [UUID]
    let style: String
    let colorMode: String
    let mode: String
    let plan: MangaStoryPlan
    let summary: String
    let creationMode: String
    let artworks: [MangaDraftArtwork]

    /// Never restore images from another video, different card notes,
    /// another scene grouping, or a different rendering style.
    func isCompatible(
        videoFile currentVideo: String?,
        pins currentPins: [MangaPin],
        sceneIDs currentSceneIDs: [UUID],
        style currentStyle: String,
        colorMode currentColor: String
    ) -> Bool {
        guard version == 1,
              videoFile == currentVideo,
              sourcePins == currentPins,
              sceneIDs == currentSceneIDs,
              !sceneIDs.isEmpty && sceneIDs.count <= 12,
              style == currentStyle && colorMode == currentColor,
              mode == "online" || mode == "offline",
              (mode == "online") == plan.isAIStory,
              plan.beats.map(\.id) == sceneIDs,
              artworks.count <= sceneIDs.count,
              artworks.map(\.id) == Array(sceneIDs.prefix(artworks.count))
        else { return false }
        let filenames=artworks.map(\.drawingFile)
        return Set(filenames).count == filenames.count && filenames.allSatisfy {
            $0.hasPrefix("draft-art-") && $0.hasSuffix(".png") &&
            !$0.contains("/") && !$0.contains("\\") && !$0.contains("..")
        }
    }
}
