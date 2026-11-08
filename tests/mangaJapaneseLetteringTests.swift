import Foundation

@main struct MangaJapaneseLetteringTests {
    static func main() {
        func checked(_ value:String)->String {
            MangaJapaneseLettering.clean(value,fallback:"自然な日本語に修正してください。",limit:60)
        }
        precondition(checked("手が滑り、思わず声が出た！")=="手が滑り、思わず声が出た！")
        precondition(checked("やったー！！") == "やったー！！")
        precondition(checked("『ここで一気に決める！』")=="『ここで一気に決める！』")
        precondition(checked("るABCDEFGHIJKL nonsense gibberish")=="自然な日本語に修正してください。")
        precondition(checked("ﾊﾞｶﾔﾛｰ!")=="ﾊﾞｶﾔﾛｰ!")
        precondition(checked("ぎゃああああああああああああ")=="自然な日本語に修正してください。")
        precondition(checked("そば\u{FFFD}を切った")=="自然な日本語に修正してください。")
        precondition(checked("https://bad.example/こんにちは")=="自然な日本語に修正してください。")
        precondition(checked("\tこんにちは") == "こんにちは")
        precondition(MangaJapaneseLettering.clean("大変だ!",fallback:"",limit:3)=="大変だ")
        print("PASS: Japanese lettering accepts manga speech while rejecting garbled, mostly-English and URL text")
    }
}