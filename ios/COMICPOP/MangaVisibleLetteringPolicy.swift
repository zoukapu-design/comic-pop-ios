import Foundation

/// Text shown on a manga page must have an explicit, attributable source.
/// AI screenplay captions and on-device speech recognition are editable
/// SUGGESTIONS. Merely containing Japanese characters does not make them
/// trustworthy prose or proof that a person said those words.
enum MangaVisibleLetteringPolicy {
    static func caption(reviewed:String?,originalNote:String)->String {
        if let reviewed {
            return MangaJapaneseLettering.clean(reviewed,fallback:"",limit:100)
        }
        let authored=MangaCaptionNotePolicy.captionCandidate(originalNote)
        return MangaJapaneseLettering.clean(authored,fallback:"",limit:46)
    }

    static func dialogue(reviewed:String?,userDialogue:String)->String {
        if let reviewed {
            return MangaJapaneseLettering.clean(reviewed,fallback:"",limit:80)
        }
        return MangaJapaneseLettering.clean(userDialogue,fallback:"",limit:80)
    }

    static func pageTitle(userTitle:String)->String {
        let value=userTitle.trimmingCharacters(in:.whitespacesAndNewlines)
        // Never print unreviewed AI titles into the actual page header.
        return value.isEmpty ? "ムビコマ" : String(value.prefix(60))
    }
}
