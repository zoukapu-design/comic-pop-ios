import Foundation

@main struct MangaVisibleLetteringPolicyTests {
    static func main() {
        // AI-made captions, imagined quotes, and unconfirmed on-device
        // speech do not become printed manga text simply by being Japanese.
        precondition(MangaVisibleLetteringPolicy.caption(reviewed:nil,originalNote:"").isEmpty)
        precondition(MangaVisibleLetteringPolicy.dialogue(reviewed:nil,userDialogue:"").isEmpty)
        precondition(MangaVisibleLetteringPolicy.caption(
            reviewed:nil,originalNote:"主人公がカメラを落とした")=="主人公がカメラを落とした")
        precondition(MangaVisibleLetteringPolicy.caption(
            reviewed:nil,originalNote:"怖い演出にして").isEmpty)
        precondition(MangaVisibleLetteringPolicy.dialogue(
            reviewed:nil,userDialogue:"ちょっと待って！")=="ちょっと待って！")

        // Explicit confirmation in the screenplay editor overrides the AI
        // suggestion. Empty string is also deliberate (no narration).
        precondition(MangaVisibleLetteringPolicy.caption(
            reviewed:"元動画の場所で止まった。",originalNote:"別のメモ")=="元動画の場所で止まった。")
        precondition(MangaVisibleLetteringPolicy.dialogue(
            reviewed:"うわっ！",userDialogue:"これは違う")=="うわっ！")
        precondition(MangaVisibleLetteringPolicy.caption(
            reviewed:"",originalNote:"主人公がカメラを落とした").isEmpty)
        precondition(MangaVisibleLetteringPolicy.dialogue(
            reviewed:"",userDialogue:"ちょっと待って！").isEmpty)
        precondition(MangaVisibleLetteringPolicy.caption(
            reviewed:"bad caption ABC123",originalNote:"手が滑った").isEmpty)
        precondition(MangaVisibleLetteringPolicy.pageTitle(userTitle:" ")=="ムビコマ")
        precondition(MangaVisibleLetteringPolicy.pageTitle(userTitle:"釣りの思い出")=="釣りの思い出")
        print("PASS: only user-authored or explicitly approved Japanese is printed; unreviewed AI titles and quotes stay off the page")
    }
}
