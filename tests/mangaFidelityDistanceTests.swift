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
        // OCR cannot read the fake vertical Japanese inside an AI speech
        // balloon. Vision's TEXT REGION detector must still reject it.
        let fakeBubble=MangaDetectedTextRegion(
            centerX:0.72,centerY:0.58,width:0.17,height:0.31)
        let originalSign=MangaDetectedTextRegion(
            centerX:0.10,centerY:0.90,width:0.23,height:0.05)
        let stableSign=MangaDetectedTextRegion(
            centerX:0.105,centerY:0.895,width:0.22,height:0.06)
        precondition(MangaFidelityDistancePolicy.hasUnexpectedTextRegions(
            generated:[fakeBubble],original:[]),
            "Source without text cannot gain an AI speech balloon")
        precondition(MangaFidelityDistancePolicy.hasUnexpectedTextRegions(
            generated:[stableSign,fakeBubble],original:[originalSign]),
            "Existing signage is not permission to paint a new balloon")
        precondition(!MangaFidelityDistancePolicy.hasUnexpectedTextRegions(
            generated:[stableSign],original:[originalSign]),
            "Original filmed words must remain permitted")
        precondition(!MangaFidelityDistancePolicy.hasUnexpectedTextRegions(
            generated:[MangaDetectedTextRegion(centerX:0.2,centerY:0.4,
                                                width:0.008,height:0.004)],
            original:[]),
            "Tiny speckle noise is not a readable text region")
        print("PASS: even unreadable AI pseudo-kanji and vertical balloon glyph regions cannot silently enter manga")
        print("PASS: untrusted glyphs baked into AI manga trigger original-video replacement")
        print("PASS: avoid uncontrolled AI scene drift with an on-device source-relative fallback policy")
    }
}
