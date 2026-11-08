"""MOVIKOMA native redesign preflight (Python standard library only)."""
from pathlib import Path
import base64
import re

root = Path(__file__).resolve().parents[1]
app = (root / "ios/COMICPOP/COMICPOPApp.swift").read_text(encoding="utf-8")
ui = (root / "ios/COMICPOP/MovikomaUI.swift").read_text(encoding="utf-8")
art = (root / "ios/COMICPOP/RexAtlas.swift").read_text(encoding="utf-8")
store = (root / "ios/COMICPOP/StudioStore.swift").read_text(encoding="utf-8")
project = (root / "ios/project.yml").read_text(encoding="utf-8")
assert "WindowGroup { MovikomaPopRootView() }" in app
popui = (root / "ios/COMICPOP/PopApp.swift").read_text(encoding="utf-8")
editor = (root / "ios/COMICPOP/PopEditor.swift").read_text(encoding="utf-8")
genre = (root / "ios/COMICPOP/PopGenre.swift").read_text(encoding="utf-8")
review = (root / "ios/COMICPOP/PopReview.swift").read_text(encoding="utf-8")
theme = (root / "ios/COMICPOP/PopTheme.swift").read_text(encoding="utf-8")
finisher = (root / "ios/COMICPOP/PopPageFinisher.swift").read_text(encoding="utf-8")
assert "PopBrandHeader" in popui and "PopStepNavigation(stage:$stage)" in popui
assert "PopEditorScreen" in popui and "PopGenreScreen" in popui and "PopReviewScreen" in popui
assert "PopAVPlayerSurface(player:store.player)" in editor and "PopTimeline(store:store)" in editor
# Every inserted card must appear at the correct time on the *live* editor bar.
markers = (root / "ios/COMICPOP/TimelinePinLayout.swift").read_text(encoding="utf-8")
assert 'timelineInsertedCardMarkers' in editor
assert 'timelinePinMarker' in editor
assert 'TimelinePinLayout.clusters' in editor and 'store.scenePlan.orderedPins.map' in editor
assert 'store.scrub(to:pin.seconds)' in editor, "A marker must jump to its real video time"
assert 'pendingCluster = group' in editor and 'group.count > 1' in editor
assert 'group.points' in editor and 'MangaPin' in editor
assert 'TimelinePinPoint' in markers and 'struct TimelinePinCluster' in markers
assert 'pending.append(point)' in markers and 'centerX' in markers

assert "await store.addPin(card:def)" in editor
assert "ForEach(Array(ids.prefix(12)).indices" in editor
assert '"マイデッキ"' in editor and '"お気に入り"' in editor and '"おすすめ"' in editor
assert "PopIllustratedCard" in genre and "この画風で漫画を作る" in genre
assert "await store.generateOffline()" in genre and "await store.generate()" in genre
assert "Cloudflare AI：まず脚本を確認してから漫画化" in genre
assert "store.applyFinishing" in review and "store.regeneratePanel" in review
assert "store.saveWork()" in review and "ShareLink(item:url)" in popui
assert "CIColorControls" in finisher and "CISharpenLuminance" in finisher
assert "func applyFinishing(" in store and "func regeneratePanel(" in store
assert "PopCardAtlas" in theme and "PopGenreAtlas" in theme and "PopHero" in theme
for asset in ("PopCardAtlas", "PopGenreAtlas", "PopHero", "PopLogo"):
    base = root / "ios/COMICPOP/Assets.xcassets" / (asset + ".imageset")
    assert (base / (asset + ".jpg")).is_file(), asset
    assert (base / "Contents.json").is_file(), asset
assert "PopBackground" in theme and "Canvas" in theme

assert "MVEditorView" in ui and "MVMangaView" in ui
assert "MVCardView" in ui and "MVTimelineView" in ui
assert "MVCatalogView" in ui and "MVDeckView" in ui
assert "MVWorksView" in ui and "MVSettingsView" in ui
assert "MVSprite(tile:" in ui and "UIImage(cgImage: tile)" in art
assert "VideoPlayer(player: store.player)" in ui
assert "await store.addPin(card:" in ui
assert "await store.generate()" in ui
assert "store.saveWork()" in ui
assert "store.hasCompleteComic" in ui
assert "store.discardGenerated()" in ui
assert "GenerationIntegrity.isComplete" in store and "GenerationIntegrity.canResume" in store
assert ".safeAreaInset(edge: .bottom) { cardDock }" in ui, "The card deck must remain accessible during playback"
assert "compact: true" in ui, "Compact pinned cards are required for narrow iPhones"
assert "generateOffline()" in ui and "func generateOffline() async" in store
offline = (root / "ios/COMICPOP/OfflineComicFilter.swift").read_text(encoding="utf-8")
assert 'CIFilter(name: "CIComicEffect")' in offline
assert "URLSession" not in offline, "Offline trial must never upload user video"
assert "generatedMode == \"offline\"" in store and 'generatedMode="online"' in store
assert ".task(id:" in ui
assert "ムビコマ" in app + ui + store
assert 'storyPlan?.title ?? "ムビコマ"' in store
assert "- path: COMICPOP" in project, "New SwiftUI source must be included by XcodeGen"
m = re.search(r"static let base64 = \"\"\"(.*?)\"\"\"", art, re.S)
assert m, "Missing in-source Rex artwork"
jpeg = base64.b64decode("".join(m.group(1).split()), validate=True)
assert len(jpeg) > 20000 and jpeg[:2] == bytes.fromhex("ffd8") and jpeg[-2:] == bytes.fromhex("ffd9")
# Active production journey, not just the legacy unused SwiftUI prototype.
journey = (root / "ios/COMICPOP/PopJourney.swift").read_text(encoding="utf-8")
welcome = (root / "ios/COMICPOP/PopWelcome.swift").read_text(encoding="utf-8")
settings = (root / "ios/COMICPOP/PopSettingsPanel.swift").read_text(encoding="utf-8")
share = (root / "ios/COMICPOP/PopFileShareSheet.swift").read_text(encoding="utf-8")
assert "PopHomeScreen(store:store" in popui and "PopVideoChooseScreen(store:store" in popui
assert "PopSavedConfirmation(store:store" in popui and "PopWelcomeScreen" in popui
assert "PopSettingsPanel(store:store)" in popui
assert "pop.didSeeWelcome" in popui and "onChange(of:stage)" in popui
assert "PopYellowButton(title: \"動画からマンガを作る\"" in journey
assert "PhotosPicker(selection: $chosenPhoto" in journey
assert "await store.replaceVideo(movie.url)" in journey
assert "変更してカードをリセット" in journey
assert "この動画で編集を始める" in journey
assert "popStartEditing" in journey
assert "PopArtwork(kind:.hero)" in welcome
assert "PopYellowButton(title:\"はじめる\"" in welcome
assert "goToWorks" in journey and "exportPDF(saved)" in journey
assert "store.exportPDF(work)" in popui and "store.deleteWork(id)" in popui
assert "store.moveDeckCard(id,by:-1)" in popui
assert "func exportPDF(_ work:SavedWork)" in store
assert "func deleteWork(_ id:UUID)" in store
assert "isAddingPin" in editor and "isAddingPin=true" in store
assert "importingFile" not in editor and "changeVideo" in editor
assert "PopFileShareSheet(files:[pdfURL])" in journey and "UIActivityViewController" in share
assert "Cloudflare" in settings and "token" in settings
assert "生成中：" in genre and "store.generated.count" in genre
assert "panelChooser" in review and "修正するコマを選ぶ" in review
assert not (root / "ios/COMICPOP/Assets.xcassets/EntireReferenceScreen.imageset").exists()

# 2026-11-08: story must be planned before image calls, lettered by UIKit
# and every SavedWork file must be reachable from an actual reading screen.
story=(root / "ios/COMICPOP/MangaStory.swift").read_text(encoding="utf-8")
observations=(root / "ios/COMICPOP/MangaStoryServices.swift").read_text(encoding="utf-8")
lettering=(root / "ios/COMICPOP/ComicRenderer.swift").read_text(encoding="utf-8")
reader=(root / "ios/COMICPOP/PopComicReader.swift").read_text(encoding="utf-8")
story_forms=(root / "ios/COMICPOP/PopStoryEditing.swift").read_text(encoding="utf-8")
ai=(root / "ios/COMICPOP/VideoAndAI.swift").read_text(encoding="utf-8")
assert "MangaStoryPlanner.decodeAIStory" in observations
assert "MangaStoryAIService.createPlan" in store
assert "prepareStory(pins:pins,online:true" in store
assert "CloudflareAIService.redraw(" in store and "story:beat" in store
assert "story?.imagePrompt" in ai and "seriesPremise" in ai
assert "absolute source of truth" not in ai
assert "MangaSpeechEvidence" in observations and "requiresOnDeviceRecognition=true" in observations
assert "VNRecognizeTextRequest" in observations and "ja-JP" in observations
assert "pop.story.useVoice" in genre and "NSSpeechRecognitionUsageDescription" in project
assert 'panel.caption' in lettering and 'panel.dialogue' in lettering
assert "usesLineFragmentOrigin" in lettering and "Japanese" in lettering
assert "PopPinStorySheet" in editor and "updatePinStory" in store
assert "PopPanelLetteringSheet" in review and "updatePanelText" in store
assert "PopComicReader(store:store,work:work)" in popui
assert "fullScreenCover(item:$readingWork)" in popui
assert "ForEach(0..<total,id:" in reader and "work.files.count" in reader
assert "TabView(selection:$page)" in reader and "continuous" in reader
assert "store.existingWorkURL(work.files[index])" in reader
assert "mangaStoryTests.swift" in (root / "tests/run.sh").read_text(encoding="utf-8")
# Production invariant: cards describe emotions and scenes, not the
# number of images. Several cards at the same instant make ONE scene.
model=(root / "ios/COMICPOP/Models.swift").read_text(encoding="utf-8")
grouping=(root / "ios/COMICPOP/CardSceneGrouping.swift").read_text(encoding="utf-8")
vision=(root / "ios/COMICPOP/MangaSceneContactSheet.swift").read_text(encoding="utf-8")
runner=(root / "tests/run.sh").read_text(encoding="utf-8")
assert "let scenes:[ComicScene]" in model and "var renderPins:[MangaPin]" in model
assert "scenes.count" in model and "CardSceneGrouping.groups" in model
assert "sameMomentTolerance = 1.5" in grouping
assert "CardSceneGrouping.swift" in runner
assert "scenePlan.renderPins.map" in store and "let pins=scenePlan.renderPins" in store
assert "combinedCard(for:pin)" in store and "let combinedTitle=" in store
assert "combinedDirections" in story and "DRAMATIC + HORROR" in observations
assert "MangaSceneContactSheet.motionJPEG" in observations
assert "llama-4-scout-17b-16e-instruct" in observations
assert "ai/v1/chat/completions" in observations
assert "frames:pins.compactMap" in store
assert "storyPlan?.beats.map" in store
assert "repetitiveScenes" in story and "shotHint(for:index)" in story
assert "alternateComposition:true" in store and "combinedEmotion" in ai
fusion=(root / "ios/COMICPOP/MangaCardFusion.swift").read_text(encoding="utf-8")
assert "MangaCardFusion.instruction(" in ai
referencePolicy=(root / "ios/COMICPOP/MangaReferencePolicy.swift").read_text(encoding="utf-8")
assert "enum MangaReferencePolicy" in referencePolicy
assert "MangaReferencePolicy.drawingIndices(for:index)" in store
assert store.count("openingDrawing:MangaReferencePolicy.drawingIndices(for:index)") == 2
assert "input_image_2" in ai and "openingDrawing:UIImage?=nil" in ai
assert "mangaReferencePolicyTests.swift" in (root / "tests/run.sh").read_text(encoding="utf-8")
assert "combinedCardIDs:" in store and "scenePlan.scenes.first(where:" in store
assert "MangaCardFusion" in fusion and "joinedIDs" not in fusion
assert "mangaCardFusionTests.swift" in (root / "tests/run.sh").read_text(encoding="utf-8")
assert "finishedImage=PopPageFinisher.render(" in store
assert "似すぎたコマを検出しました" in review
assert "scenePlan.renderedPanelCount" in review and "scenePlan.renderedPanelCount" in genre
assert "cardSceneGrouping" not in (root / "ios/COMICPOP/Info.plist").read_text(encoding="utf-8")
assert "5 distinct scenes" in (root / "tests/modelTests.swift").read_text(encoding="utf-8")
# Story-screen quality gate: the user must be able to inspect each beat
# before image generation and correct dialogue without another image call.
draft=(root / "ios/COMICPOP/PopStoryboardDraft.swift").read_text(encoding="utf-8")
response_parser=(root / "ios/COMICPOP/CloudflareStoryResponse.swift").read_text(encoding="utf-8")
assert "func prepareStoryboard() async" in store
assert "func recreateStoryboard() async" in store
assert "await prepareStoryboard(force:true)" in store
assert "guard force || !storyboardReady else" in store
assert "await store.recreateStoryboard()" in draft
assert "var storyboardReady: Bool" in store
assert "func updateStoryboardBeat(" in store
assert "if !resumable && !preparedDraft {clearGenerated()}" in store
assert "PopStoryboardDraft(store:store)" in genre
assert "await store.prepareStoryboard()" in genre
assert "この脚本で漫画の絵を描く" in draft
assert "PopStoryboardTextEditor" in draft and "updateStoryboardBeat" in draft
assert "popStoryboardReviewBeforeDrawing" in draft
assert "plotDescriptionJP" in story and "plotDescriptionJP" in observations
assert "このコマの出来事：" in draft
assert "userVisualDirection" in story and "userVisualDirection" in ai
assert "visualDirection:" in store and "visualDirection" in draft
assert "plotDescriptionJP" in ai and "plotDescription:" in store
assert "TextEditor(text:$plotDescription)" in draft
assert "MangaStoryQualityAudit.warnings" in draft
assert "mangaStoryQualityAuditTests.swift" in (root / "tests/run.sh").read_text(encoding="utf-8")
assert '@AppStorage("pop.hint.scene") private var sceneHint = true' in genre
assert "MangaVisualStoryError.credentials" in observations
assert "CloudflareStoryResponse.text(from:data)" in observations
assert "choices" in response_parser and "response" in response_parser
assert "cloudflareStoryResponseTests.swift" in (root / "tests/run.sh").read_text(encoding="utf-8")
assert "MangaPageIntegrity.firstDuplicatePage(encodedPages)" in store
assert "MangaArtworkUniqueness.firstUnintendedDuplicate(visualComparisons)" in store
assert "MangaArtworkUniqueness.firstUnintendedSimilarity(comparisons)" in store
assert "private func refreshArtworkSimilarityWarnings()" in store
assert "コマ\\(match.earlier+1)" in store
assert store.count("refreshArtworkSimilarityWarnings()") >= 5
artSimilarity=(root / "ios/COMICPOP/MangaArtworkUniqueness.swift").read_text(encoding="utf-8")
assert "similarReviewThreshold" in artSimilarity
assert "firstUnintendedSimilarity" in artSimilarity
assert "mangaArtworkUniquenessTests.swift" in (root / "tests/run.sh").read_text(encoding="utf-8")
assert 'plotDescriptionJP:source.userNote.trimmingCharacters' in story
assert "mangaPageIntegrityTests.swift" in (root / "tests/run.sh").read_text(encoding="utf-8")
assert "PopStoryboardDraft(store:store)" in genre
assert "MangaSceneContactSheet.motionJPEG" in observations
assert "video:movie,duration:duration" in store
print("PASS: review Japanese manga screenplay before image quota, parse Cloudflare envelopes and reject duplicate saved pages")

print("PASS: same-time cards combine into one comic scene, cinematic scene continuity and accurate paging")
# Narrative duties must reach both AI screenplay and image prompts, while
# merged emotional cards remain ONE render scene.
narrative=(root / "ios/COMICPOP/MangaNarrativeDirector.swift").read_text(encoding="utf-8")
quality=(root / "ios/COMICPOP/MangaStoryQualityAudit.swift").read_text(encoding="utf-8")
assert "enum MangaNarrativeDirector" in narrative
assert "MangaNarrativeRole" in narrative
assert "same" not in narrative or "isCombinedMoment" in narrative
assert "causalDuty" in narrative and "openEnding" in narrative
assert "allCardIDs:scene.cardIDs" in store
assert "MangaNarrativeDirector.cues(for:evidence)" in story
assert '"storyFunctionJP":cue.role.japanese' in story
assert '"connectionToPrevious":cue.causalDuty' in story
assert "narrativeDutyJP" in story and "causalLinkJP" in story
assert "MangaJapaneseLettering.clean" in story
assert "mangaJapaneseLetteringTests.swift" in (root / "tests/run.sh").read_text(encoding="utf-8")
assert "story?.narrativeDutyJP" in ai and "story?.causalLinkJP" in ai
assert "前のコマとのつながり" in draft
assert "causalLink:causal" in draft
assert "requiresCausalLink:$0.index>1" in draft
assert "MangaStoryQualityAudit.warnings" in draft
assert "confirmDrawWithWarnings" in draft
assert "nearlySame(" in quality and "isGeneric(" in quality
assert "mangaNarrativeDirectorTests.swift" in (root / "tests/run.sh").read_text(encoding="utf-8")
print("PASS: narrative arc responsibilities, causality, merged cards, editable scripts and pre-draw warnings")

# A paid, in-flight image call must not be invalidated by editor mutations.
# Video replacement is committed to disk before the previous source is deleted.
replaceVideo=store.split("func replaceVideo(_ importedURL:URL) async {",1)[1].split("func scrub(to seconds:Double)",1)[0]
assert "guard !isGenerating" in replaceVideo
assert replaceVideo.index("guard persist() else {") < replaceVideo.index("for file in oldSnapshots")
assert "data=oldData" in replaceVideo and "removeItem(at:dest)" in replaceVideo
assert "guard !isGenerating" in store.split("func addPin(card:PinDefinition) async {",1)[1].split("func updatePinStory(",1)[0]
assert "処理中のカード追加は見送りました" in store
for mutator, following in (
    ("func removePin(", "func clearPins()"),
    ("func clearPins()", "func snapshot(for pin:"),
    ("func updateStyle(", "func updateColor("),
    ("func updateColor(", "func updateTitle("),
    ("func chooseOriginal(", "private func refreshArtworkSimilarityWarnings()"),
):
    operation=store.split(mutator,1)[1].split(following,1)[0]
    assert "guard !isGenerating" in operation, mutator
# No fabricated narration when there is no video evidence or user-supplied text.
assert 'else {caption=""}' in story
assert "plotDescriptionJP:clip(e.userNote,100)" in story
# A failed save must not delete existing pins, snapshots, or story notes.
commit=store.split("private func commit(_ candidate: StudioData) -> Bool {",1)[1].split("private func loadDuration()",1)[0]
assert commit.index("guard persist(candidate) else {return false}") < commit.index("data=candidate")
add=store.split("func addPin(card:PinDefinition) async {",1)[1].split("func updatePinStory(",1)[0]
assert add.index("guard commit(candidate) else {") < add.index("pinsRevision = UUID()")
assert add.index("guard commit(candidate) else {") < add.index("clearGenerated()")
assert "try? fm.removeItem(at:snapshotURL)" in add
notes=store.split("func updatePinStory(",1)[1].split("func updatePanelText(",1)[0]
assert notes.index("guard commit(candidate) else {return}") < notes.index("clearGenerated()")
remove=store.split("func removePin(",1)[1].split("func clearPins()",1)[0]
assert remove.index("guard commit(candidate) else {return}") < remove.index("removeItem(at:")
clear=store.split("func clearPins()",1)[1].split("func snapshot(for pin:",1)[0]
assert clear.index("guard commit(candidate) else {return}") < clear.index("removeItem(at:")
assert 'plotDescriptionJP:source.userNote.trimmingCharacters' in story
assert ai.index('HIGHEST PRIORITY USER DIRECTION') < ai.index('DRAW THIS SPECIFIC EVENT AND COMPOSITION')
# Prevent accidental repeat inference; only the review screen's confirmed
# "rewrite screenplay" control may intentionally spend text/vision quota again.
storyPreparation=store.split("private func prepareStoryboard(force:Bool) async {",1)[1].split("func updateStoryboardBeat(",1)[0]
assert "guard force || !storyboardReady else" in storyPreparation
assert "await prepareStoryboard(force:false)" in store
assert "await prepareStoryboard(force:true)" in store
renderStart=store.split("func generate() async {",1)[1].split("func generateOffline() async {",1)[0]
assert 'hasCompleteComic && generatedMode == "online"' in renderStart
assert "生成結果を明示的にリセット" in renderStart
style=store.split("func updateStyle(_ style:String)",1)[1].split("func updateColor(",1)[0]
color=store.split("func updateColor(_ value:String)",1)[1].split("func updateTitle(",1)[0]
title=store.split("func updateTitle(_ value:String)",1)[1].split("func selectDeck(",1)[0]
assert style.index("guard commit(candidate) else {return}") < style.index("clearGenerated()")
assert color.index("guard commit(candidate) else {return}") < color.index('UserDefaults.standard.set(true')
assert title.index("guard commit(candidate) else {return}") < title.index("rebuildPages()")
for deckAction, nextAction in (
    ("func selectDeck(", "func addDeck("),
    ("func addDeck(", "func renameDeck("),
    ("func renameDeck(", "func deleteDeck("),
    ("func deleteDeck(", "func toggleDeckCard("),
    ("func toggleDeckCard(", "func moveDeckCard("),
    ("func moveDeckCard(", "func connect(token:")
):
    operation=store.split(deckAction,1)[1].split(nextAction,1)[0]
    assert "var candidate=data" in operation, deckAction
    assert "commit(candidate)" in operation, deckAction
    assert "data.decks.append(" not in operation and "data.decks.removeAll" not in operation
print("PASS: decks are committed atomically before the published collection changes")
print("PASS: user-confirmed storyboard rewrite only, no accidental double image charge, atomic style and title edits")
print("PASS: failed pin saves preserve originals; manual scene directions outrank AI guesses")
print("PASS: no in-flight quota waste, safe video replacement and evidence-only offline captions")

print("PASS: story-first generation, real Japanese lettering, and reading every stored manga page")

print("PASS: Rex onboarding, video picker/confirm, pin guard, deck reorder, PDF share, generated-panel editing")
print("PASS: MOVIKOMA 3 reference-faithful native screens, real Rex sprite assets and connected interactions")
