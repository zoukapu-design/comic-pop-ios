import Foundation

@main struct MangaAppearanceChangePolicyTests {
    static func main() {
        typealias Policy=MangaAppearanceChangePolicy
        func decide(_ running:Bool,_ existing:Bool,_ same:Bool)->Policy {
            Policy.decide(isGenerating:running,hasUncommittedGeneration:existing,isSameSelection:same)
        }
        precondition(decide(false,false,false) == .applyNow)
        precondition(decide(false,true,false) == .needsDiscardConfirmation)
        precondition(decide(true,true,false) == .blockedWhileGenerating)
        precondition(decide(true,false,false) == .blockedWhileGenerating)
        precondition(decide(false,true,true) == .unchanged)
        precondition(decide(true,true,true) == .unchanged)
        print("PASS: appearance change protects 6 editor/generation states")
    }
}
