import Foundation

@main struct GenerationIntegrityTests {
    static func main() {
        let a = UUID(), b = UUID(), c = UUID(), d = UUID()
        let pins = [a,b,c,d]
        func complete(_ ids:[UUID], _ pages:Int=1, _ processing:Bool=false)->Bool {
            GenerationIntegrity.isComplete(completedIDs:ids,plannedIDs:pins,pageCount:pages,expectedPageCount:1,isGenerating:processing)
        }
        func resume(_ ids:[UUID],_ sameStyle:Bool=true,_ sameColor:Bool=true)->Bool {
            GenerationIntegrity.canResume(completedIDs:ids,plannedIDs:pins,sameStyle:sameStyle,sameColor:sameColor)
        }
        precondition(complete(pins),"finished manga accepted")
        precondition(!complete([]),"no results cannot complete")
        precondition(!complete([a,b,c]),"unfinished cannot complete")
        precondition(!complete([a,c,b,d]),"wrong order cannot complete")
        precondition(!complete([a,b,b,d]),"repeated card cannot hide missing one")
        precondition(!complete(pins,2),"wrong page count cannot complete")
        precondition(!complete(pins,1,true),"in-flight generation cannot complete")
        precondition(resume([a,b]),"successful prefix can resume")
        precondition(!resume([]),"empty starts from scratch")
        precondition(!resume(pins),"fully generated comic regenerates from scratch")
        precondition(!resume([a,c]),"wrong pin order cannot resume")
        precondition(!resume([a,b],false),"old style cannot resume")
        precondition(!resume([a,b],true,false),"old colour cannot resume")
        let sameTimestampCards=[a,b]
        precondition(GenerationIntegrity.isComplete(completedIDs:sameTimestampCards,plannedIDs:sameTimestampCards,pageCount:1,expectedPageCount:1,isGenerating:false),"cards at the same timestamp remain independent")
        print("PASS: generation integrity — 14 deterministic cases")
    }
}
