import Foundation

/// Scene indices selected as style/identity references; the original video
/// frame is always image 0. Never send the same drawing twice.
enum MangaReferencePolicy {
    static func drawingIndices(for sceneIndex: Int) -> [Int] {
        guard sceneIndex > 0 else { return [] }
        if sceneIndex == 1 { return [0] }
        return [sceneIndex - 1, 0]
    }
}
