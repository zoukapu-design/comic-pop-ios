import Foundation

/// Assesses actual panel artwork, not composed pages. Page headers, numbering,
/// captions and speech balloons cannot hide a repeated illustration.
struct MangaArtworkComparison: Equatable {
    /// Zero-based index in the generated storyboard.
    let earlier: Int
    let later: Int
    /// Mean normalized grayscale difference of the actual drawing pixels.
    let distance: Double
    /// User deliberately chose a replay/flashback card for the later scene.
    let intentionalReprise: Bool
}

enum MangaArtworkUniqueness {
    /// Deliberately strict: auto-block only effectively identical artwork.
    /// Merely similar compositions are handled by the review UI instead.
    static let duplicateThreshold = 0.004

    static func firstUnintendedDuplicate(
        _ comparisons: [MangaArtworkComparison],
        threshold: Double = duplicateThreshold
    ) -> MangaArtworkComparison? {
        let limit=max(0,threshold)
        return comparisons.first {
            $0.earlier >= 0 && $0.later > $0.earlier &&
            $0.distance.isFinite && $0.distance <= limit &&
            !$0.intentionalReprise
        }
    }
}
