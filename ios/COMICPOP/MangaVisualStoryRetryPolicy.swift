import Foundation

/// Treat a failed image-understanding request as potentially quota-consuming.
/// Another text model call is safe to AUTOMATICALLY attempt only when the
/// endpoint/model is explicitly unsupported, not on malformed output, 5xx,
/// timeout, authentication or exhausted free quota.
enum MangaVisualStoryError: Error, Equatable {
    case unsupported
    case quota
    case credentials
    case invalidResponse
    case serverFailure
}

enum MangaVisualStoryRetryPolicy {
    static func failure(forHTTPStatus code:Int) -> MangaVisualStoryError? {
        if (200...299).contains(code) {return nil}
        switch code {
        case 401,403: return .credentials
        case 402,429: return .quota
        case 404,405,415,422: return .unsupported
        default: return .serverFailure
        }
    }

    static func allowsAutomaticTextFallback(after failure:MangaVisualStoryError) -> Bool {
        failure == .unsupported
    }
}
