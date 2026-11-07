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
             "dialogue":"これはどうなる？","scene":"pottery studio beat \(index)",
             "imagePrompt":"draw the pottery scene moment \(index), changing camera distance",
             "transition":"this follows the previous action"] as [String:Any]
        }
        let json=try JSONSerialization.data(withJSONObject:["title":"陶芸初挑戦","premise":"最初は順調だったが、最後に大逆転が待っていた。","panels":beats])
        let outline=try MangaStoryPlanner.decodeAIStory(String(decoding:json,as:UTF8.self),evidence:inputs)
        precondition(outline.isAIStory && outline.beats.count==5)
        precondition(outline.beats.map(\.id)==inputs.map(\.pinID))
        precondition(outline.beats[2].dialogue=="あれ、曲がってる！", "user dialogue overrides speculation")
        precondition(outline.title=="陶芸初挑戦")
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
        let source=MangaStoryPlanner.evidenceJSON(inputs)
        precondition(source.contains("陶" ) == false || source.contains("card"))
        precondition(source.contains("粘土を回し始める"))
        print("PASS: story-first mapping 5 cards, human Japanese dialogue priority, invalid glyph replacement, missing panels rejection")
    }
}