import Foundation

/// Pure-Foundation durable writer used for user-authored editor state.
/// Encode first, then atomically replace the destination; a failing encode or
/// write must not truncate the previous editing session on disk.
enum StudioAtomicPersistence {
    static func write<Value: Encodable>(_ value: Value, to destination: URL) throws {
        let encoded = try JSONEncoder().encode(value)
        try encoded.write(to: destination, options: .atomic)
    }
}
