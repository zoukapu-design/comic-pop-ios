import Foundation

@main struct MangaDraftEditGuardTests {
    static func main() {
        func can(_ running:Bool,_ draft:Bool,_ confirmed:Bool,_ changed:Bool)->Bool {
            MangaDraftEditGuard.mayApply(
                isGenerating:running,hasDraft:draft,
                confirmed:confirmed,hasActualChange:changed
            )
        }
        precondition(can(false,false,false,true),
                     "A new project can insert cards without confirmation")
        precondition(!can(false,true,false,true),
                     "Adding a card cannot silently destroy AI artwork")
        precondition(can(false,true,true,true),
                     "User-confirmed card edits can proceed")
        precondition(!can(true,false,false,true),
                     "An in-flight generation blocks even fresh pin changes")
        precondition(!can(true,true,true,true),
                     "Confirmation must not bypass active AI generation")
        precondition(can(false,true,false,false),
                     "Unchanged story notes must not require a destructive reset")
        precondition(!MangaDraftEditGuard.allowsChange(hasDraft:true,confirmed:false),
                     "Direct store calls need the same consent as SwiftUI")
        precondition(MangaDraftEditGuard.allowsChange(hasDraft:false,confirmed:false),
                     "Existing card-only projects should edit normally")
        print("PASS: 8 manga draft editing authorization scenarios")
    }
}
