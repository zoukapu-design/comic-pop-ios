import Foundation

@main struct MangaDraftFilePolicyTests {
    static func main() {
        let existing="draft-art-older.png"
        let known:Set<String>=[existing]
        func exists(_ file:String)->Bool { known.contains(file) }
        precondition(!MangaDraftFilePolicy.needsWrite(
            existingFile:existing,isDirty:false,fileExists:exists),
            "A clean, present PNG should not be encoded again")
        precondition(MangaDraftFilePolicy.needsWrite(
            existingFile:existing,isDirty:true,fileExists:exists),
            "Changed image must be re-encoded")
        precondition(MangaDraftFilePolicy.needsWrite(
            existingFile:nil,isDirty:false,fileExists:exists),
            "New manga panel must be written")
        precondition(MangaDraftFilePolicy.needsWrite(
            existingFile:"draft-art-missing.png",isDirty:false,fileExists:exists),
            "A checkpoint must repair PNG files missing from disk")

        let available=[
            existing,"draft-art-abandoned.png","draft-art-old.png",
            "comic-saved.png","pin-user.jpg","video-user.mov",
            "draft-art-../outside.png","draft-art-danger.png/../../escape",
            "draft-art-untouched.jpg"
        ]
        let orphans=MangaDraftFilePolicy.orphanFiles(
            available:available,referenced:known)
        precondition(Set(orphans)==["draft-art-abandoned.png","draft-art-old.png"],
                     "Cleanup can delete only unreferenced temporary PNG files")
        precondition(!orphans.contains(existing),
                     "Never delete the referenced last-good image")
        precondition(!orphans.contains("comic-saved.png"),
                     "Never delete a saved comic or original media")
        print("PASS: manga draft file policy — missing PNG repair and safe orphan cleanup")
    }
}
