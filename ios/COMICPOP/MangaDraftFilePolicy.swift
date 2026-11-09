import Foundation

/// Small, offline-verifiable rules for on-device artwork checkpoints.
/// Checking only the JSON entry is insufficient: its PNG may have gone missing.
enum MangaDraftFilePolicy {
    static func needsWrite(existingFile: String?, isDirty: Bool,
                           fileExists: (String) -> Bool) -> Bool {
        guard !isDirty, let existingFile else { return true }
        return !fileExists(existingFile)
    }

    /// Only temporary draft artwork is eligible for cleanup. Original video,
    /// saved manga pages and pin snapshots are never candidates.
    static func orphanFiles(available: [String], referenced: Set<String>) -> [String] {
        available.filter { name in
            name.hasPrefix("draft-art-") && name.hasSuffix(".png") &&
            !name.contains("/") && !name.contains("\\") && !name.contains("..") &&
            !referenced.contains(name)
        }
    }
}
