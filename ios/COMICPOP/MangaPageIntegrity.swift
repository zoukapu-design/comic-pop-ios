import Foundation

/// Prevents saving repeated page files as different numbered manga pages.
/// Page images are compared as real PNG bytes, not by file name or page index.
enum MangaPageIntegrity {
    static func firstDuplicatePage(_ pngPages:[Data]) -> Int? {
        var encountered=Set<Data>()
        for (index,png) in pngPages.enumerated() {
            if !encountered.insert(png).inserted {return index}
        }
        return nil
    }
    static func validates(_ pages:[Data],expectedCount:Int) -> Bool {
        expectedCount>0 && pages.count==expectedCount &&
        pages.allSatisfy{!$0.isEmpty} && firstDuplicatePage(pages)==nil
    }
}
