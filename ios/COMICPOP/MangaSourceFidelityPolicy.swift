import Foundation

/// Video-first editing policy. AI story text may guide captions but never
/// override the actual filmed identity, prop, motion or location.
enum MangaSourceFidelityPolicy {
    static let storageKey="pop.generation.sourceLocked.v1"
    static func sourceLocked(defaults:UserDefaults = .standard) -> Bool {
        // This is a NEW preference key. Existing users must default to faithful
        // restyling even if an older optional fidelity hint used to be OFF.
        defaults.object(forKey:storageKey) as? Bool ?? true
    }

    static let lockedSourceRule =
        "SOURCE-LOCKED IMAGE EDIT OF input_image_0. It is the ONLY factual visual source. " +
        "Draw THIS exact video frame as manga, not a new scene. Preserve each person's " +
        "apparent age, face, hair, build, clothes, pose and count; preserve the exact " +
        "object/vehicle shape, hand grip, background, horizon, time of day, lighting " +
        "and camera framing. NO substitute person, added objects, new actions or " +
        "redesigned vehicles. Change ONLY ink, screen tones and line art. " +
        "Ignore conflicting AI screenplay descriptions."

    static let sourceReference =
        "input_image_0 = CURRENT VIDEO FRAME ONLY. Never copy an AI-drawn prior panel."

    static let sceneMood =
        "Use cards only for ink intensity, screentones, emphasis and atmosphere. " +
        "Do not add people, props, events or different body poses."

    static func useEarlierMangaAsVisualReference(locked:Bool)->Bool {
        !locked
    }
}
