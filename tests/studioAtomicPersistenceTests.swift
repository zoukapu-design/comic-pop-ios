import Foundation

private struct TestStudioState: Codable, Equatable {
    var title: String
    var pins: [String]
}
private enum ForcedFailure: Error { case encodingRefused }
private struct FailingStudioState: Encodable {
    func encode(to encoder: Encoder) throws {
        throw ForcedFailure.encodingRefused
    }
}

@main struct StudioAtomicPersistenceTests {
    static func main() throws {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent("movikoma-atomic-\(UUID().uuidString)")
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        defer {try? fm.removeItem(at: folder)}
        let url = folder.appendingPathComponent("studio.json")
        let first = TestStudioState(title:"原稿",pins:["intro","dramatic"])
        try StudioAtomicPersistence.write(first,to:url)
        let baseline = try Data(contentsOf:url)
        precondition(try JSONDecoder().decode(TestStudioState.self,from:baseline)==first,
                     "First write must be a valid JSON session")
        do {
            try StudioAtomicPersistence.write(FailingStudioState(),to:url)
            preconditionFailure("Fault-injected JSON encoding should throw")
        } catch ForcedFailure.encodingRefused {}
        precondition(try Data(contentsOf:url)==baseline,
                     "Failed encoding must preserve previous persisted data")
        do {
            try StudioAtomicPersistence.write(["invalid":Double.nan],to:url)
            preconditionFailure("Nonfinite JSON numbers must be rejected")
        } catch {}
        precondition(try Data(contentsOf:url)==baseline,
                     "Invalid JSON cannot overwrite a previously good session")
        let updated=TestStudioState(title:"完成",pins:["intro","dramatic","ending"])
        try StudioAtomicPersistence.write(updated,to:url)
        precondition(try JSONDecoder().decode(TestStudioState.self,from:Data(contentsOf:url))==updated,
                     "A valid later edit should replace JSON with all cards intact")
        let missingFolder=folder.appendingPathComponent("no-such-directory")
        do {
            try StudioAtomicPersistence.write(updated,to:missingFolder.appendingPathComponent("studio.json"))
            preconditionFailure("A missing parent directory must fail explicitly")
        } catch {}
        precondition(!fm.fileExists(atPath:missingFolder.appendingPathComponent("studio.json").path),
                     "A failed write must not create an unexpected session")
        print("PASS: atomic studio persistence — valid, failing encoder, invalid JSON, update, missing directory")
    }
}
