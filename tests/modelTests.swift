import Foundation

@main struct ModelTests {
    static func main() throws {
        let path=CommandLine.arguments[1]
        let cards=try JSONDecoder().decode([PinDefinition].self,
            from:Data(contentsOf:URL(fileURLWithPath:path)))
        precondition(cards.count==85 && Set(cards.map(\.id)).count==85)
        precondition(cards.contains{$0.id=="dramatic"})
        precondition(cards.contains{$0.id=="horror"})
        for deck in StudioData().decks {
            precondition(deck.cardIDs.allSatisfy { code in cards.contains{$0.id==code} })
        }

        // Core regression from the real iPhone report:
        // two emotional cards at the same scene must become ONE comic panel.
        let lead=MangaPin(cardID:"intro",seconds:0,snapshotFile:"0.jpg")
        let dramatic=MangaPin(cardID:"dramatic",seconds:40,snapshotFile:"40a.jpg")
        let horror=MangaPin(cardID:"horror",seconds:40,snapshotFile:"40b.jpg")
        let next=MangaPin(cardID:"reaction",seconds:75,snapshotFile:"75.jpg")
        let ending=MangaPin(cardID:"ending",seconds:115,snapshotFile:"115.jpg")
        let scenePlan=ScenePlan(pins:[horror,ending,next,lead,dramatic])
        precondition(scenePlan.orderedPins.count==5,"All 5 user cards must remain intact")
        precondition(scenePlan.scenes.count==4,"Dramatic + horror must share ONE scene")
        precondition(scenePlan.pages==1,"Four scenes fit on one page")
        precondition(scenePlan.scenes[1].cardIDs==["horror","dramatic"],
                     "Same-timestamp card input order must be retained")
        precondition(scenePlan.scenes[1].pinIDs==[horror.id,dramatic.id],
                     "Both cards must be represented inside the same scene")
        precondition(scenePlan.scenes.flatMap(\.pinIDs).count==5,
                     "No user card may be dropped during scene fusion")
        precondition(scenePlan.renderPins.map(\.id)==[lead.id,horror.id,next.id,ending.id],
                     "Use one stable representative ID per render scene")

        // Truly distinct five story moments must still generate TWO pages:
        // a fifth scene must not be silently lost or duplicate page one.
        let separate=(0..<5).map { i in
            MangaPin(cardID:i==4 ? "ending" : "intro",seconds:Double(i*15),
                     snapshotFile:"scene\(i).jpg")
        }
        let distinctPlan=ScenePlan(pins:separate)
        precondition(distinctPlan.renderedPanelCount==5 && distinctPlan.pages==2)
        precondition(distinctPlan.scenes[4].pinIDs==[separate[4].id])
        precondition(distinctPlan.renderPins[4].id==separate[4].id)

        let twelve=(0..<12).map { i in
            MangaPin(cardID:i%2==0 ? "intro" : "punch",
                     seconds:Double(i*5),snapshotFile:"\(i).jpg")
        }
        let plan12=ScenePlan(pins:twelve)
        precondition(plan12.renderedPanelCount==12 && plan12.pages==3)
        precondition(plan12.orderedPins.count==12)

        // Nearby card marks are merged but not transitively chain-merged.
        let near=[0.0,1.0,2.0].map {
            MangaPin(cardID:"dramatic",seconds:$0,snapshotFile:"\($0).jpg")
        }
        let planNear=ScenePlan(pins:near)
        precondition(planNear.renderedPanelCount==2 && planNear.scenes[0].pins.count==2)
        precondition(planNear.scenes[1].pins.count==1)
        let backup=try JSONEncoder().encode(StudioData())
        let restored=try JSONDecoder().decode(StudioData.self,from:backup)
        precondition(restored.decks.count==4)
        print("PASS: 85 cards, same-scene dramatic+horror fusion, 5 distinct scenes -> 2 pages, 12 scenes -> 3 pages")
    }
}
