import Foundation

/// Conservatively compares the generative drawing against a device-local
/// comic rendering of the SAME original frame. Never infer fidelity from
/// caption/story text. Feature distances are heuristic, not a guarantee.
enum MangaFidelityDistancePolicy {
    /// A diffusion model can draw fake Japanese glyphs *inside the image*.
    /// Native lettering cannot erase those baked-in strokes. Fall back to a
    /// faithful local comic effect when OCR finds NEW legible text that was
    /// absent from the actual video. This is intentionally conservative:
    /// short punctuation/noise is ignored, but exact signs from the video
    /// are allowed. OCR can still miss nonsense-looking pseudo-glyphs.
    static func hasUnexpectedText(generated:[String],original:[String])->Bool {
        func normalize(_ raw:String)->String {
            raw.lowercased().unicodeScalars
                .filter {CharacterSet.alphanumerics.contains($0)}
                .map(String.init).joined()
        }
        let originalWords=original.map(normalize).filter{!$0.isEmpty}
        let source=originalWords.joined(separator:" ")
        return generated.map(normalize).contains { word in
            guard word.count>=3 else {return false}
            if originalWords.contains(where:{$0==word || $0.contains(word)}) {
                return false
            }
            return !source.contains(word)
        }
    }

    static func isUnreliable(generated:Float,localComic:Float)->Bool {
        guard generated.isFinite,localComic.isFinite,
              generated>=0,localComic>=0 else {return true}
        // A large semantic change beyond the style-only baseline indicates
        // possible subject/object/location substitution. Calibration uses the
        // exact original frame, not other generated manga images.
        return generated > max(localComic*1.8,localComic+0.5)
    }
}
