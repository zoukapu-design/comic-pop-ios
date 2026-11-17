import Foundation

/// Conservatively compares the generative drawing against a device-local
/// comic rendering of the SAME original frame. Never infer fidelity from
/// caption/story text. Feature distances are heuristic, not a guarantee.
enum MangaFidelityDistancePolicy {
    static func isUnreliable(generated:Float,localComic:Float)->Bool {
        guard generated.isFinite,localComic.isFinite,
              generated>=0,localComic>=0 else {return true}
        // A large semantic change beyond the style-only baseline indicates
        // possible subject/object/location substitution. Calibration uses the
        // exact original frame, not other generated manga images.
        return generated > max(localComic*1.8,localComic+0.5)
    }
}
