import Foundation

/// Fast, offline checks before drawing. These are not claims of story quality.
struct StoryReviewScene {
    let index:Int
    let plot:String
    let caption:String
    let imagePrompt:String
    let transition:String
    var narrativeRole:String = ""
    var causalLink:String = ""
    var requiresCausalLink:Bool = false
    /// Flashbacks/replays may deliberately recreate a previously shown event.
    var isIntentionalReplay:Bool = false
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
                    message:"このコマで起きる出来事が未設定です。行動と結果を具体的にしてください。"
                ))
            }
            if visual.isEmpty {
                warnings.append(StoryReviewWarning(
                    sceneNumber:scene.index,
                    message:"作画の指示が空です。どんな動作・構図を描くか指定してください。"
                ))
            }
            if scene.requiresCausalLink && offset>0 &&
               normalize(scene.causalLink).isEmpty {
                warnings.append(StoryReviewWarning(
                    sceneNumber:scene.index,
                    message:"前のコマと何でつながるか未設定です。原因・反応・結果を確認してください。"
                ))
            }
            if !scene.narrativeRole.isEmpty && isGeneric(scene.plot) {
                warnings.append(StoryReviewWarning(
                    sceneNumber:scene.index,
                    message:"物語の役割に対して出来事が曖昧です。何をして何が変化するのか記入してください。"
                ))
            }
            // Distant scenes can accidentally become the *same* picture even
            // when their neighbors differ. Warn only when both the visible
            // event AND image composition are near-clones; a repeated setting
            // alone is not a story defect. Do not reject intentional replays.
            if offset>1 && !scene.isIntentionalReplay {
                for earlierIndex in 0..<(offset-1) {
                    let earlier=scenes[earlierIndex]
                    guard !earlier.isIntentionalReplay else {continue}
                    let olderPlot=normalize(earlier.plot)
                    let olderVisual=normalize(earlier.imagePrompt)
                    let sameAction=plot.count>=8 && olderPlot.count>=8 &&
                        (plot==olderPlot || nearlySame(plot,olderPlot))
                    let sameShot=visual.count>=12 && olderVisual.count>=12 &&
                        (visual==olderVisual || nearlySame(visual,olderVisual))
                    if sameAction && sameShot {
                        warnings.append(StoryReviewWarning(
                            sceneNumber:scene.index,
                            message:"シーン\(earlier.index)と出来事・構図が重複しています。意図的な回想でなければ新しい展開に修正してください。"
                        ))
                        break
                    }
                }
            }
            if offset>0 {
                let before=scenes[offset-1]
                let previousPlot=normalize(before.plot)
                let previousVisual=normalize(before.imagePrompt)
                if !plot.isEmpty && !previousPlot.isEmpty &&
                   (plot==previousPlot || nearlySame(plot,previousPlot)) {
                    warnings.append(StoryReviewWarning(
                        sceneNumber:scene.index,
                        message:"直前のコマと出来事が同じか非常に似ています。新しい展開やリアクションを加えてください。"
                    ))
                }
                if !visual.isEmpty && !previousVisual.isEmpty &&
                   visual==previousVisual {
                    warnings.append(StoryReviewWarning(
                        sceneNumber:scene.index,
                        message:"直前のコマと絵の指示が同じです。別の動作や構図を指定してください。"
                    ))
                }
            }
        }
        return warnings
    }

    private static func isGeneric(_ value:String)->Bool {
        let text=normalize(value)
        let clichés=[
            "そのとき思わぬ展開が",
            "次の瞬間状況が動いた",
            "そして物語が進んだ",
            "こうして物語が始まった",
            "劇的な場面になった",
            "恐怖を感じる場面"
        ]
        return clichés.contains(text)
    }

    private static func normalize(_ text:String)->String {
        String(text.lowercased().unicodeScalars.filter{
            !CharacterSet.whitespacesAndNewlines.contains($0) &&
            !CharacterSet.punctuationCharacters.contains($0)
        })
    }

    /// High threshold deliberately only catches near clones; distinct story
    /// beats about the same subject should not be marked as duplicate.
    private static func nearlySame(_ first:String,_ second:String)->Bool {
        let a=Array(first), b=Array(second)
        guard a.count>=13 && b.count>=13 else {return false}
        func grams(_ letters:[Character])->Set<String> {
            Set((0..<(letters.count-1)).map { index in
                String(letters[index...index+1])
            })
        }
        let left=grams(a),right=grams(b)
        let shared=left.intersection(right).count
        let union=left.union(right).count
        return union>0 && Double(shared)/Double(union)>=0.88
    }
}
