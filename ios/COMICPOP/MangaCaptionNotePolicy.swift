import Foundation

/// A card's free-form note may be an instruction to the manga artist rather
/// than text the fictional narrator should speak. Keep it in the visual/story
/// prompt in either case; auto-letter it only when it reads as a scene note.
/// The user can always author exact captions in the storyboard editor.
enum MangaCaptionNotePolicy {
    static func captionCandidate(_ note: String) -> String {
        let value = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return "" }

        // Conservative: classify unmistakable production vocabulary rather
        // than filtering arbitrary imperative speech from the source video.
        let productionMarkers = [
            "演出", "アングル", "構図", "ズーム",
            "エフェクト", "画風", "漫画風", "絵のタッチ", "集中線",
            "効果音", "色調", "ライティング", "フォント",
            "スクリーントーン", "ぼかし", "絵柄", "作画",
            "カメラワーク", "カメラアングル", "カメラ目線",
            "カメラ位置", "カメラを斜め", "カメラを寄せ",
            "背景を描いて", "背景をぼかして"
        ]
        if productionMarkers.contains(where: { value.contains($0) }) { return "" }

        // Creative wishes are not observed events or spoken narration.
        let productionEndings = [
            "したい", "してほしい", "して欲しい", "してください",
            "描いて", "描いてほしい", "描いて欲しい", "強調して",
            "見せてほしい", "見せて欲しい"
        ]
        if productionEndings.contains(where: { value.hasSuffix($0) }) { return "" }

        return value
    }

    static func trustedFallback(note: String, heard: String) -> String {
        let candidate = captionCandidate(note)
        return candidate.isEmpty ? heard : candidate
    }
}
