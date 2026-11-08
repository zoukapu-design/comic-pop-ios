import Foundation

/// A cheap, deterministic screening step before any image generation.
/// It cannot judge artistic quality; it detects structural mistakes a human
/// can correct in the screenplay review at zero extra image-GPU cost.
struct StoryReviewScene {
    let index:Int
    let plot:String
    let caption:String
    let imagePrompt:String
    let transition:String
}

struct StoryReviewWarning: Identifiable, Equatable {
    let sceneNumber:Int
    let message:String
    var id:String {"scene-\(sceneNumber)-\(message)"}
}

enum MangaStoryQualityAudit {
    static func warnings(for scenes:[StoryReviewScene])->[StoryReviewWarning] {
        var warnings:[StoryReviewWarning]=[]
        for (offset,scene) in scenes.enumerated() {
            let plot=normalize(scene.plot)
            let visual=normalize(scene.imagePrompt)
            if plot.isEmpty {
                warnings.append(StoryReviewWarning(
                    sceneNumber:scene.index,
                    message:"このコマで起きる出来事が未設定です。行動とその結果を具体的にしてください。"
                ))
            }
            if visual.isEmpty {
                warnings.append(StoryReviewWarning(
                    sceneNumber:scene.index,
                    message:"作画の指示が空です。どんな行動・構図を描くか指定してください。"
                ))
            }
            if offset>0 {
                let before=scenes[offset-1]
                if !plot.isEmpty && plot==normalize(before.plot) {
                    warnings.append(StoryReviewWarning(
                        sceneNumber:scene.index,
                        message:"直前のコマと出来事が同じです。新しい展開やリアクションを加えてください。"
                    ))
                }
                if !visual.isEmpty && visual==normalize(before.imagePrompt) {
                    warnings.append(StoryReviewWarning(
                        sceneNumber:scene.index,
                        message:"直前のコマと絵の指示が同じです。別の動作や構図を指定してください。"
                    ))
                }
            }
        }
        return warnings
    }
    private static func normalize(_ text:String)->String {
        String(text.lowercased().unicodeScalars.filter{
            !CharacterSet.whitespacesAndNewlines.contains($0) &&
            !CharacterSet.punctuationCharacters.contains($0)
        })
    }
}
