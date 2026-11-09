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
        // A distant clone should be caught before paying for four drawings,
        // not only once a duplicated final image has been returned.
        let sceneA=StoryReviewScene(
            index:1,plot:"主人公が茶碗をテーブルの中央に置く",
            caption:"最初の茶碗",imagePrompt:"medium shot of blue-jacket hero setting a bowl on the table",
            transition:"opening"
        )
        let sceneB=StoryReviewScene(
            index:2,plot:"友人が陶器の焼き色を確かめる",
            caption:"大丈夫かな",imagePrompt:"close view of a friend inspecting a fired bowl",
            transition:"next scene"
        )
        let sceneC=StoryReviewScene(
            index:3,plot:"主人公が失敗に気づいて目を丸くする",
            caption:"しまった",imagePrompt:"dramatic close-up surprise on a blue-jacket protagonist",
            transition:"after inspection"
        )
        let repeatedD=StoryReviewScene(
            index:4,plot:"主人公が茶碗をテーブルの中央に置く",
            caption:"同じ動作を繰り返す",imagePrompt:"medium shot of blue-jacket hero setting a bowl on the table",
            transition:"next scene"
        )
        let distantWarnings=MangaStoryQualityAudit.warnings(
            for:[sceneA,sceneB,sceneC,repeatedD])
        precondition(distantWarnings.contains(where:{
            $0.sceneNumber==4 && $0.message.contains("シーン1")
        }),"Non-adjacent repeats must be flagged before image GPU requests")
        var flashback=repeatedD
        flashback.isIntentionalReplay=true
        precondition(MangaStoryQualityAudit.warnings(
            for:[sceneA,sceneB,sceneC,flashback]).isEmpty,
            "Explicit flashback cards are allowed to reprise an older composition")
        var adjacentFlashback=sceneA
        adjacentFlashback.isIntentionalReplay=true
        precondition(MangaStoryQualityAudit.warnings(
            for:[sceneA,adjacentFlashback]).isEmpty,
            "An explicitly requested adjacent replay is not accidental duplication")
        let differentEvent=StoryReviewScene(
            index:4,plot:"主人公が茶碗を頭上に掲げて喜ぶ",
            caption:"大成功",imagePrompt:repeatedD.imagePrompt,
            transition:"after learning"
        )
        precondition(MangaStoryQualityAudit.warnings(
            for:[sceneA,sceneB,sceneC,differentEvent]).isEmpty,
            "Same room and shot with a new action must not be rejected")
        print("PASS: distant repeated manga beats detected; explicit flashbacks exempt")
        print("PASS: screenplay missing action, duplicated plot, duplicated composition and user correction")
    }
}
