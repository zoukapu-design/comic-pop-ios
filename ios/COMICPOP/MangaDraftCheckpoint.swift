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
    /// Retake attempts alter the deterministic FLUX seed. Persist them so
    /// restarting the app cannot silently reuse an already-spent AI seed.
    /// Optional for compatibility with all existing version-1 checkpoints.
    var retryCounts: [UUID: Int]? = nil

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
        let renderedIDs=Set(artworks.map(\.id))
        // Only already-rendered panels can have a retake count. A bounded
        // nonnegative number prevents invalid or overflowing retry seeds.
        let validRetries=retryCounts?.allSatisfy {
            renderedIDs.contains($0.key) && (0...100_000).contains($0.value)
        } ?? true
        let filenames=artworks.map(\.drawingFile)
        return validRetries && Set(filenames).count == filenames.count && filenames.allSatisfy {
            $0.hasPrefix("draft-art-") && $0.hasSuffix(".png") &&
            !$0.contains("/") && !$0.contains("\\") && !$0.contains("..")
        }
    }
}
