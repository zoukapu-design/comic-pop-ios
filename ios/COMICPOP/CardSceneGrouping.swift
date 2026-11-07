import Foundation

/// A card controls the storytelling of a scene. Multiple cards placed at the
/// same moment are COMBINED into one scene (not duplicated as separate pictures).
struct TimedCardRef: Equatable {
    let id: UUID
    let seconds: Double
}

enum CardSceneGrouping {
    /// 1.5 s groups near-identical timestamps while keeping real cuts distinct.
    /// Compare with the FIRST timestamp in the group to prevent chain-merging.
    static let sameMomentTolerance = 1.5

    static func groups(_ refs: [TimedCardRef],
                       tolerance: Double = sameMomentTolerance) -> [[UUID]] {
        let valid = refs.enumerated().filter { $0.element.seconds.isFinite }
        let sorted = valid.sorted { a,b in
            a.element.seconds == b.element.seconds
                ? a.offset < b.offset
                : a.element.seconds < b.element.seconds
        }.map(\.element)
        guard !sorted.isEmpty else { return [] }
        let separation=max(0,tolerance)
        var result:[[UUID]]=[]
        var current:[UUID]=[]
        var anchor=0.0
        for ref in sorted {
            if !current.isEmpty && ref.seconds-anchor > separation {
                result.append(current)
                current=[]
            }
            if current.isEmpty { anchor=ref.seconds }
            current.append(ref.id)
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
}
