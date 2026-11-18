import Foundation

@main struct MangaDraftCheckpointTests {
    static func main() throws {
        let first=MangaPin(cardID:"intro",seconds:1,snapshotFile:"a.jpg",note:"始まり")
        let second=MangaPin(cardID:"punch",seconds:12,snapshotFile:"b.jpg",dialogue:"びっくり！")
        let pins=[first,second], ids=[first.id,second.id]
        let beats=[
            MangaStoryBeat(id:first.id,index:1,caption:"始まる",dialogue:"",
                           scene:"room",imagePrompt:"room wide",transition:"opening",
                           userSceneNoteJP:"始まり"),
            MangaStoryBeat(id:second.id,index:2,caption:"オチ",dialogue:"びっくり！",
                           scene:"surprise",imagePrompt:"surprise close-up",transition:"reaction")
        ]
        let plan=MangaStoryPlan(title:"続きから読む",premise:"前半と後半",
                                beats:beats,isAIStory:true,usedVisualEvidence:true)
        let art=MangaDraftArtwork(id:first.id,drawingFile:"draft-art-test1.png",
                                  cardTitle:"導入",caption:"始まる",dialogue:"",
                                  storyPrompt:"room wide",storyScene:"room")
        func checkpoint(
            version:Int=1,video:String="video.mov",sourcePins:[MangaPin]?=nil,
            sceneIDs:[UUID]?=nil,style:String="shonen",color:String="mono",
            mode:String="online",plan suppliedPlan:MangaStoryPlan?=nil,
            artworks:[MangaDraftArtwork]?=nil,
            retries:[UUID:Int]?=nil
        )->MangaDraftCheckpoint {
            MangaDraftCheckpoint(version:version,videoFile:video,
                                 sourcePins:sourcePins ?? pins,sceneIDs:sceneIDs ?? ids,
                                 style:style,colorMode:color,mode:mode,
                                 plan:suppliedPlan ?? plan,summary:"前半と後半",
                                 creationMode:"画像AI分析",artworks:artworks ?? [art],
                                 retryCounts:retries)
        }
        func valid(_ draft:MangaDraftCheckpoint)->Bool {
            draft.isCompatible(videoFile:"video.mov",pins:pins,sceneIDs:ids,
                               style:"shonen",colorMode:"mono")
        }
        precondition(valid(checkpoint()),"Valid partial AI draft should resume")
        let encoded=try JSONEncoder().encode(checkpoint())
        let decoded=try JSONDecoder().decode(MangaDraftCheckpoint.self,from:encoded)
        precondition(valid(decoded) && decoded.plan.beats[0].userSceneNoteJP=="始まり",
                     "Story and user directions must survive JSON round trip")
        precondition(decoded.artworks.first?.drawingFile=="draft-art-test1.png")
        // Existing JSON from previous app builds lacks this optional field.
        // It must continue to load without losing the storyboard or images.
        let legacy=try JSONDecoder().decode(MangaDraftCheckpoint.self,from:encoded)
        precondition(valid(legacy) && legacy.retryCounts == nil,
                     "Legacy version-1 checkpoint without retry counts must load")
        let retried=checkpoint(retries:[first.id:3])
        let retriedData=try JSONEncoder().encode(retried)
        let resumed=try JSONDecoder().decode(MangaDraftCheckpoint.self,from:retriedData)
        precondition(valid(resumed) && resumed.retryCounts?[first.id] == 3,
                     "Retake seeds must survive app restarts to avoid duplicate GPU calls")
        precondition(!valid(checkpoint(retries:[second.id:1])),
                     "A non-rendered panel cannot carry a retake count")
        precondition(!valid(checkpoint(retries:[UUID():1])),
                     "Foreign card IDs cannot contribute retake seed state")
        precondition(!valid(checkpoint(retries:[first.id:-1])),
                     "Negative retry attempts must never enter generation")
        precondition(!valid(checkpoint(retries:[first.id:100_001])),
                     "Out-of-range retry counts must be rejected")
        precondition(valid(checkpoint(artworks:[])),
                     "Script-only checkpoint should resume without image calls")
        let offlinePlan=MangaStoryPlan(title:plan.title,premise:plan.premise,
                                        beats:beats,isAIStory:false)
        precondition(valid(checkpoint(mode:"offline",plan:offlinePlan)),
                     "Offline partial manga should resume without Cloudflare")
        precondition(!valid(checkpoint(mode:"offline")),
                     "Never mistake an AI screenplay for an offline draft")
        precondition(!valid(checkpoint(plan:offlinePlan)),
                     "Never mistake an offline script for an online AI draft")
        precondition(!valid(checkpoint(version:2)),"Reject unknown checkpoint version")
        precondition(!valid(checkpoint(video:"other.mov")),"Never restore another movie")
        var editedPins=pins
        editedPins[0].note="別のオチ"
        precondition(!checkpoint().isCompatible(videoFile:"video.mov",
                     pins:editedPins,sceneIDs:ids,style:"shonen",colorMode:"mono"),
                     "Editing notes must invalidate old storyboard")
        precondition(!valid(checkpoint(sourcePins:[first])),"Missing card cannot resume")
        precondition(!valid(checkpoint(sceneIDs:[second.id,first.id])),
                     "Scene order must match the plan")
        precondition(!valid(checkpoint(style:"shojo")),"Style change invalidates images")
        precondition(!valid(checkpoint(color:"color")),"Colour change invalidates images")
        precondition(!valid(checkpoint(mode:"unknown")),"Reject invalid rendering mode")
        let cloneArt=MangaDraftArtwork(id:first.id,drawingFile:"draft-art-second.png",
                                       cardTitle:"誤った複製",caption:"",dialogue:"",
                                       storyPrompt:"",storyScene:"")
        precondition(!valid(checkpoint(artworks:[art,cloneArt])),
                     "Generated artworks must be a correct ordered prefix")
        let escape=MangaDraftArtwork(id:first.id,drawingFile:"draft-art-../outside.png",
                                     cardTitle:"",caption:"",dialogue:"",
                                     storyPrompt:"",storyScene:"")
        precondition(!valid(checkpoint(artworks:[escape])),
                     "Reject path traversal in local draft file names")
        let wrongPlan=MangaStoryPlan(title:"x",premise:"y",
                                     beats:[beats[0]],isAIStory:true)
        precondition(!valid(checkpoint(plan:wrongPlan)),
                     "Never attach an incomplete screenplay to full scene set")
        let extraArt=MangaDraftArtwork(id:second.id,drawingFile:"draft-art-test1.png",
                                       cardTitle:"オチ",caption:"",dialogue:"",
                                       storyPrompt:"",storyScene:"")
        precondition(!valid(checkpoint(artworks:[art,extraArt])),
                     "Reject duplicate image file references")
        print("PASS: manga draft checkpoint — restart-safe retake seeds, modes, exact pin identity, scene order, path safety")
    }
}
