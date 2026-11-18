import Foundation

@main struct MangaPageIntegrityTests {
    static func main() {
        let one=Data("page one".utf8)
        let two=Data("page two".utf8)
        let three=Data("page three".utf8)
        precondition(MangaPageIntegrity.validates([one],expectedCount:1))
        precondition(MangaPageIntegrity.validates([one,two],expectedCount:2))
        precondition(MangaPageIntegrity.validates([one,two,three],expectedCount:3))
        precondition(!MangaPageIntegrity.validates([one,one],expectedCount:2))
        precondition(MangaPageIntegrity.firstDuplicatePage([one,one])==1)
        precondition(MangaPageIntegrity.firstDuplicatePage([one,two,one])==2)
        precondition(MangaPageIntegrity.firstDuplicatePage([one,two,three])==nil)
        precondition(!MangaPageIntegrity.validates([one,two],expectedCount:3))
        precondition(!MangaPageIntegrity.validates([Data()],expectedCount:1))
        precondition(!MangaPageIntegrity.validates([],expectedCount:0))
        print("PASS: all-page identity, page count, missing images, duplicate page rejection")
    }
}
