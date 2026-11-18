import Foundation

@main struct MangaNarrativeDirectorTests {
    static func main() {
        func evidence(_ id:String,_ time:Double,ids:[String]=[]) -> MangaStoryEvidence {
            MangaStoryEvidence(
                pinID:UUID(),seconds:time,cardID:id,cardTitle:id,
                cardHint:"user-selected narrative card",
                visual:"person working with soba",neighborVisual:"hands move",
                heard:"",userNote:"",userDialogue:"",allCardIDs:ids
            )
        }
        let scenes=[
            evidence("intro",0),
            evidence("dramatic",20,ids:["dramatic","horror"]),
            evidence("reaction",40),
            evidence("ending",60)
        ]
        let arcs=MangaNarrativeDirector.cues(for:scenes)
        precondition(arcs.count==4)
        precondition(arcs.map(\.role)==[.introduction,.crisis,.reaction,.payoff])
        precondition(arcs[1].allCardIDs==["dramatic","horror"])
        precondition(arcs[1].isCombinedMoment)
        precondition(arcs[1].role.narrativeRequirement.contains("恐怖"))
        precondition(arcs[2].causalDuty.contains("シーン2"))
        precondition(arcs[3].role.narrativeRequirement.contains("結果"))
        precondition(MangaNarrativeDirector.cues(for:[evidence("dramatic",0)])[0].role == .standalone)
        let noEnding=MangaNarrativeDirector.cues(for:[
            evidence("intro",0),evidence("random",20)
        ])
        precondition(noEnding.last?.role == .openEnding,
                     "Do not invent a successful ending from unobserved footage")
        // Food/process clips need a real action arc, not generic emotions.
        let cooking=[
            evidence("challenge",0),
            evidence("recipe",10),
            evidence("failure",20),
            evidence("reaction",30),
            evidence("finishfood",40)
        ]
        let foodRoles=MangaNarrativeDirector.cues(for:cooking).map(\.role)
        precondition(foodRoles==[.introduction,.development,.crisis,
                                .reaction,.payoff])
        let constraints=MangaNarrativeDirector.cues(for:[
            evidence("intro",0),
            evidence("exact",20,ids:["dramatic","exact","noextra","quote","must"])
        ])
        precondition(constraints[1].evidenceRestrictions.contains("勝手に追加しない"))
        precondition(constraints[1].evidenceRestrictions.contains("引用セリフ"))
        precondition(constraints[1].evidenceRestrictions.contains("必ず"))
        let json=MangaStoryPlanner.evidenceJSON(scenes)
        precondition(json.contains("storyFunction"))
        precondition(json.contains("connectionToPrevious"))
        precondition(json.contains("suggestedShot"))
        precondition(json.contains("evidenceRestrictions"))
        precondition(json.contains("dramatic"))
        precondition(json.contains("horror"))
        let fallback=MangaStoryPlanner.fallback(scenes)
        precondition(fallback.beats.map(\.id)==scenes.map(\.pinID))
        precondition(fallback.beats.map(\.narrativeDutyJP) ==
            arcs.map{ $0.role.japanese })
        precondition(fallback.beats[1].imagePrompt.contains("恐怖"))
        print("PASS: intro, combined crisis, reaction, payoff, causal duties, and truthful open ending")
    }
}
