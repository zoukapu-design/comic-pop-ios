import Foundation

/// Time-based placement for the native card markers above the video frames.
///
/// - Every pin remains in the data model, including pins at identical timestamps.
/// - Pins that would visually overlap at a particular screen width are represented
///   as a selectable cluster; clustering never deletes or merges the underlying pins.
/// - Geometry is deterministic and independent of UIKit, making it unit-testable.
struct TimelinePinPoint: Identifiable, Equatable {
    let id: UUID
    let seconds: Double
}

struct TimelinePinCluster: Identifiable {
    let points: [TimelinePinPoint]
    let centerX: Double

    var id: UUID { points[0].id }
    var count: Int { points.count }
}

enum TimelinePinLayout {
    static func clusters(
        points: [TimelinePinPoint],
        duration: Double,
        width: Double,
        markerWidth: Double = 48,
        minimumGap: Double = 4
    ) -> [TimelinePinCluster] {
        guard duration.isFinite, duration > 0, width.isFinite, width > 0 else {
            return []
        }

        let left = min(markerWidth / 2, width / 2)
        let right = max(left, width - left)
        let usableWidth = max(0, right - left)
        let gap = max(0, markerWidth + minimumGap)

        // Preserve insertion order for cards at the same timestamp.
        let ordered = points.enumerated()
            .filter { $0.element.seconds.isFinite }
            .sorted { a, b in
                a.element.seconds == b.element.seconds
                    ? a.offset < b.offset
                    : a.element.seconds < b.element.seconds
            }
            .map { $0.element }

        func x(_ point: TimelinePinPoint) -> Double {
            let fraction = max(0, min(1, point.seconds / duration))
            return left + usableWidth * fraction
        }

        var clusters: [TimelinePinCluster] = []
        var pending: [TimelinePinPoint] = []
        var anchor = 0.0

        for point in ordered {
            let location = x(point)
            if !pending.isEmpty && location - anchor >= gap {
                clusters.append(TimelinePinCluster(points: pending, centerX: anchor))
                pending = []
            }
            if pending.isEmpty { anchor = location }
            pending.append(point)
        }

        if !pending.isEmpty {
            clusters.append(TimelinePinCluster(points: pending, centerX: anchor))
        }
        return clusters
    }
}
