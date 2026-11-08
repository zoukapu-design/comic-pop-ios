import Foundation

@main struct MangaStoryQualityAuditTests {
    static func main() {
        let first=StoryReviewScene(
            index:1,plot:"そばを作り始める。",caption:"開始",
            imagePrompt:"wide opening shot",transition:""
        )
        let repeatScene=StoryReviewScene(
            index:2,plot:"そばを作り始める",caption:"違うセリフ",
            imagePrompt:"wide opening shot",transition:"next"
        )
        let issues=MangaStoryQualityAudit.warnings(for:[first,repeatScene])
        precondition(issues.count==2,"Duplicated action and art must be flagged")
        precondition(issues.allSatisfy{$0.sceneNumber==2})
        let corrected=StoryReviewScene(
            index:2,plot:"手が滑り、主人公が青ざめる",caption:"大変だ！",
            imagePrompt:"closeup shocked face dramatic horror",
            transition:"after the first action"
        )
        precondition(MangaStoryQualityAudit.warnings(for:[first,corrected]).isEmpty)
        let empty=StoryReviewScene(index:1,plot:"",caption:"",
                                    imagePrompt:"",transition:"")
        precondition(MangaStoryQualityAudit.warnings(for:[empty]).count==2)
        print("PASS: screenplay missing action, duplicated plot, duplicated composition and user correction")
    }
}
