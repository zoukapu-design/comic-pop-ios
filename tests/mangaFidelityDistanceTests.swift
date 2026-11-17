import Foundation

@main struct MangaFidelityDistanceTests {
    static func main() {
        precondition(!MangaFidelityDistancePolicy.isUnreliable(generated:2,localComic:2))
        precondition(!MangaFidelityDistancePolicy.isUnreliable(generated:3,localComic:2))
        precondition(MangaFidelityDistancePolicy.isUnreliable(generated:7,localComic:2))
        precondition(MangaFidelityDistancePolicy.isUnreliable(generated:1,localComic:0))
        precondition(MangaFidelityDistancePolicy.isUnreliable(generated:.nan,localComic:1))
        precondition(MangaFidelityDistancePolicy.isUnreliable(generated:1,localComic:.infinity))
        precondition(MangaFidelityDistancePolicy.isUnreliable(generated:-1,localComic:1))
        print("PASS: avoid uncontrolled AI scene drift with an on-device source-relative fallback policy")
    }
}
