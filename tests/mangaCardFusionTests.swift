import Foundation

@main struct MangaCardFusionTests {
    static func main() {
        let dramaticFear=MangaCardFusion.instruction(
            cardIDs:["dramatic","horror"],title:"ドラマティック＋恐怖",
            subtitle:"盛り上がり / ぞくっと")
        precondition(dramaticFear.contains("DRAMATIC") &&
                     dramaticFear.contains("HORROR"))
        precondition(dramaticFear.contains("ONE SINGLE VIDEO MOMENT"))

        let food=MangaCardFusion.instruction(
            cardIDs:["success","foodzoom"],title:"成功＋料理アップ",
            subtitle:"やった！ / 食材を見せる")
        precondition(food.contains("成功＋料理アップ"))
        precondition(!food.lowercased().contains("horror") &&
                     !food.lowercased().contains("fear"),
                     "Food success prompt must not even mention unrelated horror or fear")
        precondition(food.contains("Combine ONLY these inserted cards"))

        let one=MangaCardFusion.instruction(
            cardIDs:["funny"],title:"面白",subtitle:"笑える")
        precondition(one.contains("Express ONLY this inserted card"))
        precondition(!one.contains("Combine ONLY"))
        let reordered=MangaCardFusion.instruction(
            cardIDs:["horror","dramatic","dramatic"],
            title:"恐怖＋ドラマティック",subtitle:"不穏 / 緊張")
        precondition(reordered.contains("Blend DRAMATIC and HORROR"))
        print("PASS: combined dramatic+horror, non-horror food fusion, one-card and duplicate-ID behavior")
    }
}
