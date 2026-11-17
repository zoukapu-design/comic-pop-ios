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
        precondition(!MangaFidelityDistancePolicy.hasUnexpectedText(
            generated:["海辺"],original:["海辺"]))
        precondition(!MangaFidelityDistancePolicy.hasUnexpectedText(
            generated:["海辺"],original:["夕焼けの海辺"]))
        precondition(!MangaFidelityDistancePolicy.hasUnexpectedText(
            generated:["!","1"],original:[]))
        precondition(MangaFidelityDistancePolicy.hasUnexpectedText(
            generated:["なぞの謎文字"],original:["海辺"]))
        precondition(MangaFidelityDistancePolicy.hasUnexpectedText(
            generated:["こんなセリフは言ってない"],original:[]))
        precondition(MangaFidelityDistancePolicy.hasUnexpectedText(
            generated:["New Dialogue"],original:["Beach"]))
        print("PASS: untrusted glyphs baked into AI manga trigger original-video replacement")
        print("PASS: avoid uncontrolled AI scene drift with an on-device source-relative fallback policy")
    }
}
