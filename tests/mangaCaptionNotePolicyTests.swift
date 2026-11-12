import Foundation

@main struct MangaCaptionNotePolicyTests {
    static func main() {
        let instructions = [
            "怖く演出して", "面白いオチにしたい", "カメラを斜め下から",
            "暗い雰囲気の構図で", "恐怖の効果音を入れて",
            "少女漫画風のタッチ", "結末を強調して",
            "ここは大きく描いて", "光を強調してください"
        ]
        for note in instructions {
            precondition(MangaCaptionNotePolicy.captionCandidate(note).isEmpty,
                         "Creative card direction must not be printed as narration: \(note)")
        }
        let sceneDescriptions = [
            "主人公が鍋を持ち上げる", "最初はうまくいくと思った",
            "完成した作品に大爆笑", "また挑戦しよう",
            "今すぐ帰ってきて"
        ]
        for note in sceneDescriptions {
            precondition(MangaCaptionNotePolicy.captionCandidate(note) == note,
                         "A real scene or natural spoken quote can be a caption: \(note)")
        }
        precondition(MangaCaptionNotePolicy.trustedFallback(
            note:"怖く演出して",heard:"うわっ！") == "うわっ！",
            "On-device speech should replace a creative instruction")
        precondition(MangaCaptionNotePolicy.trustedFallback(
            note:"怖く演出して",heard:"").isEmpty,
            "Do not fabricate a caption if only an art direction exists")
        precondition(MangaCaptionNotePolicy.trustedFallback(
            note:"茶碗を置いた",heard:"うわっ！") == "茶碗を置いた",
            "Scene descriptions may intentionally override transcription")
        print("PASS: creative card notes stay visual, scene observations stay readable")
    }
}
