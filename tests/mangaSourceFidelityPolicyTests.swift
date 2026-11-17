import Foundation

@main struct MangaSourceFidelityPolicyTests {
    static func main() {
        let suite="movikoma.source.fidelity.test.\(UUID().uuidString)"
        let defaults=UserDefaults(suiteName:suite)!
        defer {defaults.removePersistentDomain(forName:suite)}
        precondition(MangaSourceFidelityPolicy.sourceLocked(defaults:defaults),
                     "New and existing users must default to original-video fidelity")
        defaults.set(false,forKey:MangaSourceFidelityPolicy.storageKey)
        precondition(!MangaSourceFidelityPolicy.sourceLocked(defaults:defaults),
                     "Only a deliberate creative-mode choice may disable the lock")
        defaults.set(true,forKey:MangaSourceFidelityPolicy.storageKey)
        precondition(MangaSourceFidelityPolicy.sourceLocked(defaults:defaults))
        let rule=MangaSourceFidelityPolicy.lockedSourceRule
        for item in ["input_image_0","apparent age","clothes","object/vehicle shape",
                     "time of day","camera framing","NO substitute person",
                     "NO", "ONLY ink", "Ignore conflicting AI screenplay"] {
            precondition(rule.contains(item), "Must preserve \(item)")
        }
        precondition(!MangaSourceFidelityPolicy.useEarlierMangaAsVisualReference(locked:true))
        precondition(MangaSourceFidelityPolicy.useEarlierMangaAsVisualReference(locked:false))
        print("PASS: original video visual identity, objects, poses, environment and camera locked by default")
    }
}
