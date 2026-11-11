import Foundation

@main struct MangaVisualStoryRetryPolicyTests {
    static func main() {
        precondition(MangaVisualStoryRetryPolicy.failure(forHTTPStatus:200) == nil)
        precondition(MangaVisualStoryRetryPolicy.failure(forHTTPStatus:299) == nil)
        let classifications:[Int:MangaVisualStoryError]=[
            400:.serverFailure, 401:.credentials, 402:.quota, 403:.credentials,
            404:.unsupported, 405:.unsupported, 408:.serverFailure,
            415:.unsupported, 422:.unsupported, 429:.quota,
            500:.serverFailure, 502:.serverFailure, 503:.serverFailure
        ]
        for (code,expected) in classifications {
            precondition(MangaVisualStoryRetryPolicy.failure(forHTTPStatus:code) == expected,
                         "Unexpected automatic fallback classification for HTTP \(code)")
        }
        for error in [
            MangaVisualStoryError.invalidResponse,.serverFailure,.quota,.credentials
        ] {
            precondition(!MangaVisualStoryRetryPolicy.allowsAutomaticTextFallback(after:error),
                         "Do not silently spend more free quota on failed visual inference")
        }
        precondition(MangaVisualStoryRetryPolicy.allowsAutomaticTextFallback(after:.unsupported),
                     "A genuinely missing image model may use text-only storyboard analysis")
        print("PASS: visual story retry policy — no fallback on malformed result, quota, auth or transient errors")
    }
}
