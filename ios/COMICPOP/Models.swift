import Foundation

struct PinDefinition: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let category: String
    let art: Int
    let color: String
}

struct MangaPin: Codable, Identifiable, Hashable {
    let id: UUID
    let cardID: String
    let seconds: Double
    let snapshotFile: String
    var note: String
    var dialogue: String
    init(cardID: String, seconds: Double, snapshotFile: String, note: String = "", dialogue: String = "") {
        id = UUID(); self.cardID = cardID; self.seconds = seconds; self.snapshotFile = snapshotFile
        self.note = note; self.dialogue = dialogue
    }
}

struct UserDeck: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var cardIDs: [String]
    init(name: String, cardIDs: [String]) {
        id = UUID(); self.name = name; self.cardIDs = cardIDs
    }
}

struct SavedWork: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var files: [String]
    var createdAt: Date
    var sceneCount: Int
    var style: String
}

struct StudioData: Codable {
    var videoFile: String?
    var videoTitle = ""
    var pins: [MangaPin] = []
    var decks: [UserDeck] = [
        UserDeck(name:"いつもの",cardIDs:["intro","funny","punch","dramatic","reaction","ending"]),
        UserDeck(name:"料理レビュー",cardIDs:["intro","recipe","foodzoom","taste","reaction","finishfood","punch"]),
        UserDeck(name:"日常ギャグ",cardIDs:["intro","setup","funny","surprise","tsukkomi","punch"]),
        UserDeck(name:"スポーツ",cardIDs:["challenge","action","slow","freeze","climax","success"])
    ]
    var activeDeckID: UUID?
    var works: [SavedWork] = []
    var style = "shonen"
    var colorMode = "mono"
    var workTitle = ""
}

enum MangaStyles {
    static let all: [(id:String,title:String,prompt:String,defaultColor:String)] = [
        ("shonen","熱血少年漫画","bold black ink outlines, high-contrast classic Japanese action manga, consistent crosshatching","mono"),
        ("shojo","少女漫画","fine graceful ink contours, delicate expressive shojo manga, elegant screentone","mono"),
        ("american","アメコミ","strong graphic outlines, bright flat comic primary colors, graphic halftone","color"),
        ("gag","ギャグ漫画","expressive simplified original Japanese comedy comic ink drawing","mono"),
        ("suspense","サスペンス","noir manga suspense, ominous shadows, cinematic mystery, consistently tense ink illustration","mono"),
        ("seinen","劇画","realistic Japanese gekiga penwork, careful ink shading and fine hatch lines","mono"),
        ("daily","日常漫画","gentle warm pastel slice-of-life manga, soft clean outlines","color"),
        ("horror","ホラー漫画","striking black ink horror manga, intense shadow contrasts","mono"),
        ("retro","レトロ漫画","classic vintage printed monochrome Japanese comic and fine halftone","mono"),
        ("fantasy","幻想漫画","ornate original fantasy comic, clean penwork and harmonized soft colors","color"),
        ("kids","児童漫画","cheerful bright cartoon manga with clear original hand-drawn shapes","color")
    ]
    static func prompt(for id:String) -> String { all.first(where:{$0.id==id})?.prompt ?? all[0].prompt }
}

struct ScenePlan: Equatable {
    let orderedPins: [MangaPin]
    let pages: Int
    let panelsPerPage: Int
    init(pins: [MangaPin], panelsPerPage: Int = 4) {
        self.panelsPerPage = max(1,panelsPerPage)
        self.orderedPins = pins.enumerated().sorted { a,b in
            a.element.seconds == b.element.seconds ? a.offset < b.offset : a.element.seconds < b.element.seconds
        }.map(\.element)
        self.pages = Int(ceil(Double(pins.count)/Double(self.panelsPerPage)))
    }
}
