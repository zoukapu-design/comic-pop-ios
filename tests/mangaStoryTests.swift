import Foundation

@main struct StoryTests {
    static func main() throws {
        let cards:[(String,String,String)] = [
          ("intro","導入","最初はうまくいくと思った"),
          ("slow","スロー","粘土を回し始める"),
          ("reaction","リアクション","あれ？曲がっている？"),
          ("punch","オチ","完成した作品に大爆笑"),
          ("ending","結末","また挑戦しよう")
        ]
        let inputs=cards.enumerated().map { i,t in
            MangaStoryEvidence(pinID:UUID(),seconds:Double(i)*20,cardID:t.0,cardTitle:t.1,
                cardHint:"",visual:"a person doing pottery",neighborVisual:"ceramic wheel",
                heard:"",userNote:t.2,userDialogue:i==2 ? "あれ、曲がってる！" : "")
        }
        let fallback=MangaStoryPlanner.fallback(inputs)
        precondition(fallback.beats.count==5)
        precondition(fallback.beats.map(\.id)==inputs.map(\.pinID))
        precondition(fallback.beats[2].dialogue=="あれ、曲がってる！")
        precondition(!fallback.isAIStory)
        precondition(MangaStoryPlanner.role(for:"punch").contains("オチ"))
        let beats=(1...5).map { index in
            ["index":index,"caption":"そして展開が動いた\(index)。",
             "dialogue":"これはどうなる？",
             "causalLinkJP":index==1 ? "" : "前の作業が進んだため、次の行動に移った。",
             "scene":"pottery studio beat \(index)",
             "imagePrompt":"draw the pottery scene moment \(index), changing camera distance",
             "transition":"this follows the previous action"] as [String:Any]
        }
        let json=try JSONSerialization.data(withJSONObject:["title":"陶芸初挑戦","premise":"最初は順調だったが、最後に大逆転が待っていた。","panels":beats])
        let outline=try MangaStoryPlanner.decodeAIStory(String(decoding:json,as:UTF8.self),evidence:inputs)
        precondition(outline.isAIStory && outline.beats.count==5)
        precondition(outline.beats.map(\.id)==inputs.map(\.pinID))
        precondition(outline.beats[2].dialogue=="あれ、曲がってる！", "user dialogue overrides speculation")
        // AI may produce grammatically valid but contradictory content. User
        // notes remain the exact event shown in the final drawing prompt.
        var contradictory=beats
        contradictory[0]["plotDescriptionJP"]="主人公が突然サッカー場で走り始める。"
        let contradictedJSON=try JSONSerialization.data(withJSONObject:[
            "title":"陶芸初挑戦","premise":"陶芸に取り組む物語","panels":contradictory
        ])
        let userPriority=try MangaStoryPlanner.decodeAIStory(
            String(decoding:contradictedJSON,as:UTF8.self),evidence:inputs)
        precondition(userPriority.beats[0].plotDescriptionJP==inputs[0].userNote,
                     "AI cannot replace explicit user action with unrelated event")
        // Without observed action or a user note, the LLM's missing plot
        // must stay visibly empty for human review. A generic dramatic filler
        // is not evidence of a coherent scene.
        let noEvidence=MangaStoryEvidence(
            pinID:UUID(),seconds:5,cardID:"dramatic",cardTitle:"ドラマティック",
            cardHint:"緊張",visual:"unclassified frame",neighborVisual:"",
            heard:"",userNote:"",userDialogue:""
        )
        let evidenceFree=MangaStoryPlanner.fallback([noEvidence])
        precondition(evidenceFree.beats.count==1)
        precondition(evidenceFree.beats[0].caption.isEmpty,
                     "Offline manga must not invent narration without user notes or speech")
        precondition(evidenceFree.beats[0].plotDescriptionJP.isEmpty,
                     "Narrative duty is not factual evidence of an event")
        precondition(evidenceFree.beats[0].narrativeDutyJP=="一場面の見せ場",
                     "The emotional card still retains its stylistic intent")
        let missingPlotJSON=try JSONSerialization.data(withJSONObject:[
            "title":"出来事","premise":"緊張が走る",
            "panels":[[
                "index":1,"caption":"一瞬、空気が変わった。",
                "dialogue":"","scene":"cinematic interior",
                "imagePrompt":"person reacts in a new cinematic composition",
                "transition":"opening"
            ]]
        ])
        let missingPlot=try MangaStoryPlanner.decodeAIStory(
            String(decoding:missingPlotJSON,as:UTF8.self),evidence:[noEvidence])
        precondition(missingPlot.beats[0].plotDescriptionJP.isEmpty,
                     "Unobserved plot events must not be disguised with generic prose")
        precondition(missingPlot.beats[0].caption=="一瞬、空気が変わった。")
        precondition(outline.title=="陶芸初挑戦")
        precondition(outline.beats[0].narrativeDutyJP.contains("導入"))
        precondition(outline.beats[1].causalLinkJP.contains("前の作業"))
        precondition(outline.beats.last?.narrativeDutyJP.contains("結末")==true)
        precondition(!outline.beats[0].plotDescriptionJP.isEmpty,
                     "Every panel should have a Japanese action summary")
        let englishCaption=try JSONSerialization.data(withJSONObject:["title":"English only","premise":"Something","panels":beats.enumerated().map { i,row in var v=row;v["caption"]="random glyph 123";return v}])
        let repaired=try MangaStoryPlanner.decodeAIStory(String(decoding:englishCaption,as:UTF8.self),evidence:inputs)
        precondition(repaired.beats[0].caption==inputs[0].userNote,"gibberish captions must be rejected")
        precondition(repaired.title=="動画から生まれた物語")
        let missing=try JSONSerialization.data(withJSONObject:["title":"漫画","premise":"物語","panels":Array(beats.prefix(4))])
        do {
           _=try MangaStoryPlanner.decodeAIStory(String(decoding:missing,as:UTF8.self),evidence:inputs)
           preconditionFailure("missing beat cannot be accepted")
        } catch MangaStoryError.missingPanels {}
        // An AI text model that repeats identical actions and narration for
        // consecutive scenes must be rejected before wasting image GPU quota.
        let repeated=try JSONSerialization.data(withJSONObject:[
            "title":"陶芸の物語","premise":"成長する物語",
            "panels":(1...5).map { index in
                ["index":index,"caption":"毎回まったく同じ展開。",
                 "dialogue":"同じセリフ","scene":"same repeated pose",
                 "imagePrompt":"exact same repeated image",
                 "transition":"none"] as [String:Any]
            }
        ])
        do {
            _=try MangaStoryPlanner.decodeAIStory(
                String(decoding:repeated,as:UTF8.self),evidence:inputs)
            preconditionFailure("duplicated adjacent panels must be rejected")
        } catch MangaStoryError.repetitiveScenes {}
        precondition(MangaStoryPlanner.role(for:"horror").contains("恐怖"))
        // Combined cards are ONE story row with multiple directions.
        let combined=MangaStoryEvidence(
            pinID:UUID(),seconds:45,cardID:"dramatic",
            cardTitle:"ドラマティック＋恐怖",
            cardHint:"ドラマティック: 強い山場 | 恐怖: 恐ろしい反応",
            visual:"person in a noodle kitchen",neighborVisual:"",
            heard:"",userNote:"急に怖い出来事が発生",
            userDialogue:"えっ、何！？"
        )
        let single=MangaStoryPlanner.fallback([combined])
        precondition(single.beats.count==1)
        precondition(single.beats[0].imagePrompt.contains("ドラマティック"))
        precondition(single.beats[0].imagePrompt.contains("恐怖"))
        precondition(single.beats[0].dialogue=="えっ、何！？")
        precondition(MangaStoryPlanner.evidenceJSON([combined])
                     .contains("combinedDirections"))
        // A user-approved scene direction must be held separately from the
        // AI's existing script and survive reconstruction without another API.
        var approved=single.beats[0]
        approved.userVisualDirection="大きな恐怖の表情、ドラマティックな集中線"
        precondition(approved.id==combined.pinID)
        precondition(approved.userVisualDirection.contains("恐怖"))
        precondition(approved.imagePrompt.contains("ドラマティック"))
        let remade=MangaStoryBeat(
            id:approved.id,index:approved.index,caption:"予期せぬ出来事が起きた。",
            dialogue:"どうしよう！",scene:approved.scene,
            imagePrompt:approved.imagePrompt,transition:approved.transition,
            userVisualDirection:approved.userVisualDirection
        )
        precondition(remade.userVisualDirection==approved.userVisualDirection,
                     "Manual visual instructions must persist after copy-on-edit")
        let source=MangaStoryPlanner.evidenceJSON(inputs)
        precondition(source.contains("陶" ) == false || source.contains("card"))
        precondition(source.contains("粘土を回し始める"))
        precondition(source.contains("storyFunction"))
        precondition(source.contains("connectionToPrevious"))
        print("PASS: story-first mapping 5 cards, human Japanese dialogue priority, invalid glyph replacement, missing panels rejection")
    }
}