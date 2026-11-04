import Foundation

@main struct ModelTests {
    static func main() throws {
        let path=CommandLine.arguments[1]
        let source=try Data(contentsOf:URL(fileURLWithPath:path))
        let cards=try JSONDecoder().decode([PinDefinition].self,from:source)
        precondition(cards.count==85,"Expected 85 cards")
        precondition(Set(cards.map(\.id)).count==85,"Unique card IDs")
        for deck in StudioData().decks {precondition(deck.cardIDs.allSatisfy{code in cards.contains{$0.id==code}})}
        let p1=MangaPin(cardID:"intro",seconds:1,snapshotFile:"1.jpg")
        let p2=MangaPin(cardID:"punch",seconds:1,snapshotFile:"2.jpg")
        let p3=MangaPin(cardID:"reaction",seconds:1,snapshotFile:"3.jpg")
        let p4=MangaPin(cardID:"dramatic",seconds:6,snapshotFile:"4.jpg")
        let p5=MangaPin(cardID:"ending",seconds:11,snapshotFile:"5.jpg")
        let plan=ScenePlan(pins:[p4,p3,p1,p5,p2])
        precondition(plan.pages==2,"5 cards => 2 pages")
        precondition(plan.orderedPins.count==5,"No card dropped")
        precondition(plan.orderedPins.map(\.id)==[p3.id,p1.id,p2.id,p4.id,p5.id],"Same timestamp: original insertion order")
        let backup=try JSONEncoder().encode(StudioData())
        let restored=try JSONDecoder().decode(StudioData.self,from:backup)
        precondition(restored.decks.count==4,"Default decks persisted")
        print("PASS: 85 unique cards, 4 decks, 5 pins/2 pages, same-timestamp stable ordering, persistence")
    }
}
