import Foundation

@main struct MangaGenerationRouteTests {
    static func main() {
        typealias Route = MangaGenerationRoute
        func route(_ complete:Bool,_ count:Int,_ offline:Bool,_ script:Bool)->Route {
            Route.resolve(hasCompleteComic:complete,generatedPanelCount:count,
                          generatedOffline:offline,storyboardReady:script)
        }
        precondition(route(false,0,false,false) == .chooseMode,
                     "New projects should offer mode selection")
        precondition(route(false,0,false,true) == .reviewStoryboard,
                     "Completed AI script should be reviewed before drawing")
        precondition(route(false,2,false,false) == .resumeOnline,
                     "Incomplete online generation must reuse finished images")
        precondition(route(false,2,true,false) == .resumeOffline,
                     "Incomplete offline generation must continue locally")
        precondition(route(true,4,false,false) == .viewCompleted,
                     "A completed online comic should open review, not re-run AI")
        precondition(route(true,4,true,false) == .viewCompleted,
                     "A completed offline comic should open review")
        precondition(route(true,4,false,true) == .viewCompleted,
                     "Completion takes precedence over any stale screenplay state")
        print("PASS: 7 deterministic manga-generation route scenarios")
    }
}
