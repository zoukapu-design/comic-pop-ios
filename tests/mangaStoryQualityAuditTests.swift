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
        let missingLink=StoryReviewScene(
            index:2,plot:"そばを切り始めた",caption:"続き",
            imagePrompt:"closeup of moving knife",transition:"after setup",
            narrativeRole:"展開・状況の変化",
            causalLink:"",requiresCausalLink:true
        )
        let linkage=MangaStoryQualityAudit.warnings(for:[first,missingLink])
        precondition(linkage.count==1 && linkage[0].message.contains("つながる"))
        let repairedLink=StoryReviewScene(
            index:2,plot:"そばを切り始めた",caption:"続き",
            imagePrompt:"closeup of moving knife",transition:"after setup",
            narrativeRole:"展開・状況の変化",
            causalLink:"生地を伸ばし終わったので包丁を持った",
            requiresCausalLink:true
        )
        precondition(MangaStoryQualityAudit.warnings(for:[first,repairedLink]).isEmpty)
        let generic=StoryReviewScene(
            index:1,plot:"そのとき、思わぬ展開が！",caption:"",
            imagePrompt:"dramatic panel",transition:"",
            narrativeRole:"展開・状況の変化"
        )
        precondition(MangaStoryQualityAudit.warnings(for:[generic]).count==1,
                     "Vague placeholder plot must be flagged, not treated as a full story")
        print("PASS: screenplay missing action, duplicated plot, duplicated composition and user correction")
    }
}
