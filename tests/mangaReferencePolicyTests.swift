import Foundation

@main struct MangaReferencePolicyTests {
    static func main() {
        precondition(MangaReferencePolicy.drawingIndices(for: 0).isEmpty)
        precondition(MangaReferencePolicy.drawingIndices(for: 1) == [0])
        precondition(MangaReferencePolicy.drawingIndices(for: 2) == [1, 0])
        precondition(MangaReferencePolicy.drawingIndices(for: 4) == [3, 0])
        precondition(MangaReferencePolicy.drawingIndices(for: 11) == [10, 0])
        precondition(Set(MangaReferencePolicy.drawingIndices(for: 2)).count == 2)
        precondition(MangaReferencePolicy.drawingIndices(for: -1).isEmpty)
        print("PASS: short and long manga use current video, preceding panel and stable opening panel without duplicates")
    }
}
