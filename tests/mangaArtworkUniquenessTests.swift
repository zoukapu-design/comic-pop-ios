import Foundation

@main struct MangaArtworkUniquenessTests {
    static func main() {
        let comparisons=[
            MangaArtworkComparison(earlier:0,later:1,distance:0.18,intentionalReprise:false),
            MangaArtworkComparison(earlier:0,later:4,distance:0.001,intentionalReprise:false),
            MangaArtworkComparison(earlier:3,later:4,distance:0.075,intentionalReprise:false)
        ]
        let duplicate=MangaArtworkUniqueness.firstUnintendedDuplicate(comparisons)
        precondition(duplicate?.earlier==0 && duplicate?.later==4,
                     "Panel 5 repeating page-1 artwork must be detected despite different page headers")
        let similar=[
            MangaArtworkComparison(earlier:2,later:3,distance:0.02,intentionalReprise:false)
        ]
        precondition(MangaArtworkUniqueness.firstUnintendedDuplicate(similar)==nil,
                     "Different compositions must not be hard-blocked")
        let allowed=[
            MangaArtworkComparison(earlier:0,later:3,distance:0,intentionalReprise:true)
        ]
        precondition(MangaArtworkUniqueness.firstUnintendedDuplicate(allowed)==nil,
                     "A deliberately selected replay card is intentional repetition")
        let invalid=[
            MangaArtworkComparison(earlier:0,later:1,distance:.nan,intentionalReprise:false),
            MangaArtworkComparison(earlier:3,later:2,distance:0,intentionalReprise:false)
        ]
        precondition(MangaArtworkUniqueness.firstUnintendedDuplicate(invalid)==nil)
        print("PASS: repeated drawings across pages, genuine different shots, intentional flashback and invalid distances")
    }
}
