import Foundation

@main struct MangaDraftFilePolicyTests {
    static func main() throws {
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

        // Exercise the same filesystem behaviour used by StudioStore, without
        // networking or an iOS simulator. Real writes catch assumptions that
        // an in-memory list of names cannot verify.
        let fm=FileManager.default
        let folder=fm.temporaryDirectory.appendingPathComponent(
            "movikoma-draft-cleanup-\(UUID().uuidString)",isDirectory:true
        )
        try fm.createDirectory(at:folder,withIntermediateDirectories:true)
        defer {try? fm.removeItem(at:folder)}
        for file in [existing,"draft-art-abandoned.png","comic-saved.png","pin-user.jpg"] {
            try Data(file.utf8).write(to:folder.appendingPathComponent(file))
        }
        let diskFiles=try fm.contentsOfDirectory(atPath:folder.path)
        for file in MangaDraftFilePolicy.orphanFiles(
            available:diskFiles,referenced:known
        ) {
            try fm.removeItem(at:folder.appendingPathComponent(file))
        }
        precondition(fm.fileExists(atPath:folder.appendingPathComponent(existing).path),
                     "Referenced manga artwork must survive disk cleanup")
        precondition(!fm.fileExists(atPath:folder.appendingPathComponent("draft-art-abandoned.png").path),
                     "Abandoned draft must be removed from disk")
        precondition(fm.fileExists(atPath:folder.appendingPathComponent("comic-saved.png").path),
                     "Saved manga page must survive disk cleanup")
        precondition(fm.fileExists(atPath:folder.appendingPathComponent("pin-user.jpg").path),
                     "Original pinned video frame must survive disk cleanup")
        print("PASS: manga draft file policy — missing PNG repair and safe orphan cleanup")
    }
}
