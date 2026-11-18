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
assert "PopBrandHeader" in popui and "PopStepNavigation(stage:$stage, canReview:" in popui
assert "PopEditorScreen" in popui and "PopGenreScreen" in popui and "PopReviewScreen" in popui
assert "PopAVPlayerSurface(player:store.player)" in editor and "PopTimeline(store:store,onDelete:requestDelete)" in editor
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

assert "await store.addPin(card:definition)" in editor
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
assert 'MangaVisibleLetteringPolicy.pageTitle(userTitle:data.workTitle)' in store
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
assert "PopYellowButton(title: \"新しい動画で漫画を作る\"" in journey
assert "PhotosPicker(selection: $chosenPhoto" in journey
assert "await store.replaceVideo(movie.url,allowDiscard:allowDiscard)" in journey
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
# Only explicitly unsupported vision models may fall back to a second
# inference call; never use a second API request after malformed JSON or 5xx.
visualPolicy=(root / "ios/COMICPOP/MangaVisualStoryRetryPolicy.swift").read_text(encoding="utf-8")
visualPolicyTests=(root / "tests/mangaVisualStoryRetryPolicyTests.swift").read_text(encoding="utf-8")
assert "MangaVisualStoryRetryPolicy.failure(" in observations
assert "catch MangaVisualStoryError.invalidResponse" in observations
assert "where MangaVisualStoryRetryPolicy.allowsAutomaticTextFallback(after:failure)" in observations
assert "throw MangaVisualStoryError.invalidResponse" in observations
assert "case 404,405,415,422: return .unsupported" in visualPolicy
assert "default: return .serverFailure" in visualPolicy
assert "Do not silently spend more free quota" in visualPolicyTests
assert "mangaVisualStoryRetryPolicyTests.swift" in (root / "tests/run.sh").read_text(encoding="utf-8")
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
assert 'userSceneNoteJP:clip(source.userNote,800)' in story
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
assert "requiresCausalLink:beat.index>1" in draft
assert "MangaStoryQualityAudit.warnings" in draft
assert "confirmDrawWithWarnings" in draft
assert "nearlySame(" in quality and "isGeneric(" in quality
assert "mangaNarrativeDirectorTests.swift" in (root / "tests/run.sh").read_text(encoding="utf-8")
print("PASS: narrative arc responsibilities, causality, merged cards, editable scripts and pre-draw warnings")

# A paid, in-flight image call must not be invalidated by editor mutations.
# Video replacement is committed to disk before the previous source is deleted.
replaceVideo=store.split("func replaceVideo(_ importedURL:URL,allowDiscard:Bool = false) async {",1)[1].split("func scrub(to seconds:Double)",1)[0]
assert "guard !isGenerating" in replaceVideo
assert replaceVideo.index("guard persist() else {") < replaceVideo.index("for file in oldSnapshots")
assert "data=oldData" in replaceVideo and "removeItem(at:dest)" in replaceVideo
assert "guard !isGenerating" in store.split("func addPin(card:PinDefinition,allowDiscard:Bool = false) async {",1)[1].split("func updatePinStory(",1)[0]
assert "処理中のカード追加は見送りました" in store
for mutator, following in (
    ("func removePin(", "func clearPins(allowDiscard:Bool = false)"),
    ("func clearPins(allowDiscard:Bool = false)", "func snapshot(for pin:"),
    ("func updateStyle(", "func updateColor("),
    ("func updateColor(", "func updateTitle("),
    ("func chooseOriginal(", "private func refreshArtworkSimilarityWarnings()"),
):
    operation=store.split(mutator,1)[1].split(following,1)[0]
    assert "guard !isGenerating" in operation, mutator
# No fabricated narration when there is no video evidence or user-supplied text.
# Production directions belong to the artwork prompt, never literal narration.
captionPolicy=(root / "ios/COMICPOP/MangaCaptionNotePolicy.swift").read_text(encoding="utf-8")
captionTests=(root / "tests/mangaCaptionNotePolicyTests.swift").read_text(encoding="utf-8")
assert "MangaCaptionNotePolicy.trustedFallback(" in story
assert "enum MangaCaptionNotePolicy" in captionPolicy
assert "productionMarkers" in captionPolicy and "productionEndings" in captionPolicy
assert "mangaCaptionNotePolicyTests.swift" in (root / "tests/run.sh").read_text(encoding="utf-8")
assert "Creative notes are never fallback narration" in (root / "tests/mangaStoryTests.swift").read_text(encoding="utf-8")
assert "On-device speech should replace a creative instruction" in captionTests
assert 'plotDescriptionJP:""' in story
# A failed save must not delete existing pins, snapshots, or story notes.
atomicStore=(root / "ios/COMICPOP/StudioAtomicPersistence.swift").read_text(encoding="utf-8")
atomicTests=(root / "tests/studioAtomicPersistenceTests.swift").read_text(encoding="utf-8")
assert "StudioAtomicPersistence.write(snapshot ?? data,to:modelURL)" in store
assert "try JSONEncoder().encode(value)" in atomicStore
assert "encoded.write(to: destination, options: .atomic)" in atomicStore
assert "ForcedFailure.encodingRefused" in atomicTests
assert "Nonfinite JSON numbers must be rejected" in atomicTests
assert "studioAtomicPersistenceTests.swift" in (root / "tests/run.sh").read_text(encoding="utf-8")
commit=store.split("private func commit(_ candidate: StudioData) -> Bool {",1)[1].split("private func loadDuration()",1)[0]
assert commit.index("guard persist(candidate) else {return false}") < commit.index("data=candidate")
add=store.split("func addPin(card:PinDefinition,allowDiscard:Bool = false) async {",1)[1].split("func updatePinStory(",1)[0]
assert add.index("guard commit(candidate) else {") < add.index("pinsRevision = UUID()")
assert add.index("guard commit(candidate) else {") < add.index("clearGenerated()")
assert "try? fm.removeItem(at:snapshotURL)" in add
notes=store.split("func updatePinStory(",1)[1].split("func updatePanelText(",1)[0]
assert notes.index("guard commit(candidate) else {return false}") < notes.index("clearGenerated()")
remove=store.split("func removePin(",1)[1].split("func clearPins(allowDiscard:Bool = false)",1)[0]
assert remove.index("guard commit(candidate) else {return}") < remove.index("removeItem(at:")
clear=store.split("func clearPins(allowDiscard:Bool = false)",1)[1].split("func snapshot(for pin:",1)[0]
assert clear.index("guard commit(candidate) else {return}") < clear.index("removeItem(at:")
assert 'userSceneNoteJP:clip(source.userNote,800)' in story
# A creative/emotional note is an instruction, not proof that a physical
# action occurred in the video. The reviewed plot remains independently editable.
assert 'plotDescriptionJP:""' in story
assert 'otherwise:"",\n                    limit:100)' in story
assert 'story?.plotDescriptionJP ?? ""' in ai
assert "userSceneNoteJP:old.userSceneNoteJP" in store
assert "挿入カードのメモ（優先）" in draft
drawingPrompt=(root / "ios/COMICPOP/MangaDrawingPrompt.swift").read_text(encoding="utf-8")
promptTests=(root / "tests/mangaDrawingPromptTests.swift").read_text(encoding="utf-8")
assert "MangaDrawingPrompt.compose(MangaDrawingPromptInput(" in ai
assert 'form.add(name:"prompt",value:prompt)' in ai
assert "String(prompt.prefix(2400))" not in ai
assert "USER'S ORIGINAL CARD NOTE (HIGH PRIORITY)" in drawingPrompt
assert "HIGHEST PRIORITY USER DIRECTION" in drawingPrompt
assert drawingPrompt.index("USER'S ORIGINAL CARD NOTE (HIGH PRIORITY)") < drawingPrompt.index("DRAW THIS SPECIFIC EVENT AND COMPOSITION")
assert drawingPrompt.index('HIGHEST PRIORITY USER DIRECTION') < drawingPrompt.index('DRAW THIS SPECIFIC EVENT AND COMPOSITION')
assert drawingPrompt.index('ALL INSERTED CARD IDS (ONE SHARED SCENE)') < drawingPrompt.index('DRAW THIS SPECIFIC EVENT AND COMPOSITION')
assert "maxCharacters=2400" in drawingPrompt and 'noLettering=' in drawingPrompt
assert "mangaDrawingPromptTests.swift" in (root / "tests/run.sh").read_text(encoding="utf-8")
assert "MangaDrawingPromptInput(" in ai and "MangaDrawingPrompt.compose(" in ai
assert 'form.add(name:"prompt",value:prompt)' in ai
assert "maxCharacters=2400" in drawingPrompt
assert "ALL INSERTED CARD IDS (ONE SHARED SCENE)" in drawingPrompt
assert "CAUSE" in drawingPrompt and "IMAGE REFS" in drawingPrompt
assert drawingPrompt.index("HIGHEST PRIORITY USER DIRECTION") < drawingPrompt.index("COMBINED CARD DIRECTIVES (ONE PANEL)")
assert "packed.count<=MangaDrawingPrompt.maxCharacters" in promptTests
# Detect distant accidental copy-paste scenes before paying for artwork,
# while preserving deliberate flashback/replay cards.
quality=(root / "ios/COMICPOP/MangaStoryQualityAudit.swift").read_text(encoding="utf-8")
qualityTests=(root / "tests/mangaStoryQualityAuditTests.swift").read_text(encoding="utf-8")
assert "isIntentionalReplay:Bool = false" in quality
assert "offset>1 && !scene.isIntentionalReplay" in quality
assert "sameAction && sameShot" in quality
assert "offset>0 && !scene.isIntentionalReplay" in quality
assert "isIntentionalReplay:replay" in draft
assert "MangaReplayIntent.isIntentional(cardIDs:" in draft
assert "enum MangaReplayIntent" in story
assert "if MangaReplayIntent.isIntentional(cardIDs:ids) {continue}" in story
assert story.count("MangaReplayIntent.isIntentional(")>=1
assert store.count("MangaReplayIntent.isIntentional(cardIDs:")>=2
assert "An explicit flashback must not be discarded" in (root / "tests/mangaStoryTests.swift").read_text(encoding="utf-8")
assert "Non-adjacent repeats must be flagged" in qualityTests
assert "An explicitly requested adjacent replay" in qualityTests
print("PASS: priority packed card prompts and cross-scene repetition review before image inference")
assert "allIDs.joined(separator:" in promptTests
assert "CAUSE_OF_NEXT_SCENE_" in promptTests
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
assert color.index("guard commit(candidate) else {return}") < color.rindex('UserDefaults.standard.set(true')
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
# Screen navigation must not mistake a finished drawing for a fresh AI job.
generationRoute=(root / "ios/COMICPOP/MangaGenerationRoute.swift").read_text(encoding="utf-8")
routeTests=(root / "tests/mangaGenerationRouteTests.swift").read_text(encoding="utf-8")
preflight=(root / "tests/run.sh").read_text(encoding="utf-8")
assert "enum MangaGenerationRoute" in generationRoute
assert "if hasCompleteComic { return .viewCompleted }" in generationRoute
assert "if generatedPanelCount > 0" in generationRoute
assert ".resumeOffline" in generationRoute and ".resumeOnline" in generationRoute
assert "MangaGenerationRoute.resolve(" in genre
assert "generationRoute == .viewCompleted" in genre
assert "generationRoute == .resumeOnline || generationRoute == .resumeOffline" in genre
assert "generationRoute == .reviewStoryboard" in genre
assert "完成した漫画を見る" in genre
assert "続きを生成する" in genre
assert "生成結果を破棄して作り直す" in genre
assert "store.discardGenerated()" in genre
assert "mangaGenerationRouteTests.swift" in preflight
assert "7 deterministic manga-generation route scenarios" in routeTests
# Style/colour selection must not silently invalidate a paid screenplay
# or unsaved comic: block it in the store, and require explicit UI consent.
appearance=(root / "ios/COMICPOP/MangaAppearanceChangePolicy.swift").read_text(encoding="utf-8")
appearanceTests=(root / "tests/mangaAppearanceChangePolicyTests.swift").read_text(encoding="utf-8")
assert "enum MangaAppearanceChangePolicy" in appearance
assert "if hasUncommittedGeneration { return .needsDiscardConfirmation }" in appearance
assert "if isGenerating { return .blockedWhileGenerating }" in appearance
assert "6 editor/generation states" in appearanceTests
assert "mangaAppearanceChangePolicyTests.swift" in preflight
assert "var hasUncommittedGeneration: Bool" in store
assert "guard !hasUncommittedGeneration else" in style
assert "guard data.colorMode == value || !hasUncommittedGeneration else" in color
assert "MangaAppearanceChangePolicy.decide(" in genre
assert "requestAppearance(.style(genre.id))" in genre
assert 'requestAppearance(.color("mono"))' in genre
assert 'requestAppearance(.color("color"))' in genre
assert "askAppearanceReset" in genre and "pendingAppearance" in genre
assert "生成結果を破棄して設定を変更" in genre
assert "store.discardGenerated()" in genre
print("PASS: style/colour changes require explicit consent before discarding unsaved artwork")

# Page rasterization is expensive: save title immediately, rasterize only
# on submit/navigation/save, not on each TextField character change.
titleEdit=store.split("func updateTitle(_ value:String)",1)[1].split("func refreshPageTitle()",1)[0]
assert "guard commit(candidate) else {return}" in titleEdit
assert "rebuildPages()" not in titleEdit
assert "func refreshPageTitle()" in store
assert ".onSubmit {store.refreshPageTitle()}" in genre
assert ".onDisappear {store.refreshPageTitle()}" in genre
assert "refreshPageTitle()" in store.split("func saveWork() -> Bool",1)[1]
print("PASS: actual UI state machine for complete/partial/script; title page rasterization deferred")
print("PASS: decks are committed atomically before the published collection changes")
print("PASS: user-confirmed storyboard rewrite only, no accidental double image charge, atomic style and title edits")
print("PASS: failed pin saves preserve originals; manual scene directions outrank AI guesses")
print("PASS: no in-flight quota waste, safe video replacement and evidence-only offline captions")

# Restart-safe manga checkpoint: the screenplay and every successful artwork
# are persisted locally before another Cloudflare image request is sent.
checkpoint=(root / "ios/COMICPOP/MangaDraftCheckpoint.swift").read_text(encoding="utf-8")
checkpointTests=(root / "tests/mangaDraftCheckpointTests.swift").read_text(encoding="utf-8")
assert "struct MangaDraftCheckpoint: Codable" in checkpoint
assert "sourcePins == currentPins" in checkpoint
assert "sceneIDs == currentSceneIDs" in checkpoint
assert 'mode == "online" || mode == "offline"' in checkpoint
assert '(mode == "online") == plan.isAIStory' in checkpoint
assert "Never mistake an AI screenplay for an offline draft" in checkpointTests
assert "Never mistake an offline script for an online AI draft" in checkpointTests
retake=store.split("func regeneratePanel(",1)[1].split("isGenerating=true",1)[0]
assert "guard saveDraftCheckpoint() else {return}" in retake
retakeCommit=store.split("func regeneratePanel(",1)[1].split("func chooseOriginal(",1)[0]
# A failed PNG/JSON checkpoint must restore both the prior image and the
# in-memory state; the retry seed must not advance when nothing was saved.
for before in ("let previousDrawing=generated[index].drawing",
               "let previousFinishingBase=finishingBase[id]",
               "let previousRetryCount=panelRetryCount[id]",
               "let previousDirty=dirtyArtworkIDs"):
    assert before in retakeCommit,before
assert "generated[index].drawing=previousDrawing" in retakeCommit
assert "finishingBase[id]=previousFinishingBase" in retakeCommit
assert "panelRetryCount[id]=previousRetryCount" in retakeCommit
assert "dirtyArtworkIDs=previousDirty" in retakeCommit
assert retakeCommit.index("guard saveDraftCheckpoint() else {\n                generated[index].drawing=previousDrawing") < retakeCommit.index("refreshArtworkSimilarityWarnings()")
assert "guard saveDraftCheckpoint() else {return false}" in store.split("func saveWork() -> Bool",1)[1]
assert 'artworks.map(\\.id) == Array(sceneIDs.prefix(artworks.count))' in checkpoint
assert "!$0.contains(" in checkpoint
assert "struct MangaStoryPlan: Codable" in story
assert "struct MangaStoryBeat: Identifiable, Codable" in story
assert "mangaDraftCheckpointTests.swift" in preflight
assert "Valid partial AI draft should resume" in checkpointTests
assert "Editing notes must invalidate old storyboard" in checkpointTests
assert "Reject path traversal" in checkpointTests
# Successful retake attempts are durable and cannot repeat the old seed after
# app restart. Old v1 checkpoints without the optional field still decode.
assert "var retryCounts: [UUID: Int]? = nil" in checkpoint
assert "let validRetries=retryCounts?.allSatisfy" in checkpoint
assert "panelRetryCount=(saved.retryCounts ?? [:]).filter" in store
assert "retryCounts:panelRetryCount.filter" in store
assert "Retake seeds must survive app restarts" in checkpointTests
assert "Legacy version-1 checkpoint without retry counts" in checkpointTests
assert "restoreDraftCheckpoint()" in store
assert "private func saveDraftCheckpoint() -> Bool" in store
assert "StudioAtomicPersistence.write(checkpoint,to:draftURL)" in store
assert "draft-art-" in store and "png.write" in store
assert "removeDraftCheckpoint()" in store
assert "hasRecoverableDraft" in store and "hasRecoverableDraft" in genre
for start,nextMethod in (
    ("private func prepareStoryboard(force:Bool) async {", "func updateStoryboardBeat("),
    ("func updateStoryboardBeat(", "func generate() async {"),
    ("func generate() async {", "func generateOffline() async {"),
    ("func generateOffline() async {", "func applyFinishing("),
    ("func applyFinishing(", "func regeneratePanel("),
    ("func regeneratePanel(", "func chooseOriginal("),
    ("func chooseOriginal(", "private func refreshArtworkSimilarityWarnings()")
):
    scope=store.split(start,1)[1].split(nextMethod,1)[0]
    assert "saveDraftCheckpoint()" in scope,start
generateScope=store.split("func generate() async {",1)[1].split("func generateOffline() async {",1)[0]
assert generateScope.index("guard saveDraftCheckpoint() else {return}") < generateScope.index("let startIndex=generated.count")
assert "追加のAI呼出しは停止しました" in generateScope
assert "dirtyArtworkIDs.insert(pin.id)" in generateScope
# Even an indexed, clean PNG may disappear from disk. Retry its local
# write instead of claiming the checkpoint is safely persisted.
filePolicy=(root / "ios/COMICPOP/MangaDraftFilePolicy.swift").read_text(encoding="utf-8")
fileTests=(root / "tests/mangaDraftFilePolicyTests.swift").read_text(encoding="utf-8")
assert "enum MangaDraftFilePolicy" in filePolicy
assert "static func needsWrite(" in filePolicy
assert "static func orphanFiles(" in filePolicy
assert "fileExists(existingFile)" in filePolicy
assert "MangaDraftFilePolicy.needsWrite(" in store
assert "MangaDraftFilePolicy.orphanFiles(" in store
assert "cleanupUnreferencedDraftArtwork()" in store
assert "mangaDraftFilePolicyTests.swift" in preflight
assert "A checkpoint must repair PNG files missing from disk" in fileTests
assert "Never delete the referenced last-good image" in fileTests
# If editing fails to persist, the editor should not display unsaved changes
# as if the user's previously approved Japanese wording was safely stored.
lettering=store.split("func updatePanelText(",1)[1].split("func removePin(",1)[0]
assert "let previousPanel=generated[index]" in lettering
assert "generated[index]=previousPanel" in lettering
scriptEdit=store.split("func updateStoryboardBeat(",1)[1].split("func generate() async {",1)[0]
assert "storyPlan=plan" in scriptEdit
finishing=store.split("func applyFinishing(",1)[1].split("func regeneratePanel(",1)[0]
assert "let previousPanels=generated" in finishing
assert "generated=previousPanels" in finishing
assert "finishingBase=previousFinishingBase" in finishing
original=store.split("func chooseOriginal(",1)[1].split("private func refreshArtworkSimilarityWarnings()",1)[0]
assert "generated[i].drawing=previousDrawing" in original
assert "dirtyArtworkIDs=previousDirty" in original
print("PASS: repair missing PNG backup, clean orphan drafts, roll back edits after disk failure")

print("PASS: interrupted comic and edited screenplay persist across restart; mismatched video and notes rejected")

print("PASS: story-first generation, real Japanese lettering, and reading every stored manga page")

print("PASS: Rex onboarding, video picker/confirm, pin guard, deck reorder, PDF share, generated-panel editing")
# Editing a card after generating artwork must never silently delete the
# screenplay or render. User consent is scoped to an actual mutation, and a
# failed JSON commit cannot discard a costly draft.
draftEdit=(root / "ios/COMICPOP/MangaDraftEditGuard.swift").read_text(encoding="utf-8")
draftEditTests=(root / "tests/mangaDraftEditGuardTests.swift").read_text(encoding="utf-8")
assert "enum MangaDraftEditGuard" in draftEdit
assert "!hasDraft || confirmed" in draftEdit
assert "return !isGenerating && allowsChange(" in draftEdit
assert "mangaDraftEditGuardTests.swift" in preflight
assert "8 manga draft editing authorization scenarios" in draftEditTests
assert store.count("MangaDraftEditGuard.allowsChange(") == 6
for first,last in (
    ("func replaceVideo(", "func scrub("),
    ("func addPin(", "func updatePinStory("),
    ("func updatePinStory(", "func updatePanelText("),
    ("func removePin(", "func clearPins("),
    ("func clearPins(", "func snapshot(for pin:")
):
    section=store.split(first,1)[1].split(last,1)[0]
    assert "MangaDraftEditGuard.allowsChange(" in section,first
    assert section.index("guard commit(candidate)") < section.index("clearGenerated()") if first not in (
        "func replaceVideo(", "func addPin("
    ) else True
adding=store.split("func addPin(",1)[1].split("func updatePinStory(",1)[0]
assert adding.count("MangaDraftEditGuard.allowsChange(")==2
assert "capturedRevision == pinsRevision" in adding
assert "capturedDraftRevision == draftRevision" in adding
assert "let capturedDraftRevision=draftRevision" in adding
assert "draftRevision=UUID()" in store
assert adding.index("guard commit(candidate)") < adding.index("clearGenerated()")
notes=store.split("func updatePinStory(",1)[1].split("func updatePanelText(",1)[0]
assert "return false" in notes and "return true" in notes
assert "pendingDraftAction" in editor and "askDiscardDraft" in editor
assert "PopTimeline(store:store,onDelete:requestDelete)" in editor
assert "store.removePin(pin,allowDiscard:true)" in editor
assert "store.clearPins(allowDiscard:true)" in editor
assert "store.addPin(card:definition,allowDiscard:true)" in editor
assert "onDelete(pin)" in editor
assert "askDiscardDraft" in story_forms
assert "saveNotes(allowDiscard:true)" in story_forms
assert "if store.updatePinStory(" in story_forms
assert "store.replaceVideo(movie.url,allowDiscard:allowDiscard)" in journey
assert "store.replaceVideo(url,allowDiscard:allowDiscard)" in journey
assert "importPhoto(photo,allowDiscard:true)" in journey
assert "importVideo(url,allowDiscard:true)" in journey
print("PASS: editor/video/pin story changes require consent and commit before wiping manga drafts")
assert "continueManga: () -> Void" in journey
assert "continueManga:{" in popui
assert "stage = store.hasCompleteComic ? .review : .styles" in popui
assert "作りかけの漫画を再開" in journey
assert "popResumeComic" in journey
assert "store.hasRecoverableDraft" in journey
print("PASS: app home exposes resumable manga without asserting a failed backup succeeded")


print("PASS: MOVIKOMA 3 reference-faithful native screens, real Rex sprite assets and connected interactions")

# Launchable UI and real comic cover art: do not "fix" an unused SwiftUI root.
journey=(root / "ios/COMICPOP/PopJourney.swift").read_text(encoding="utf-8")
assert "WindowGroup { MovikomaPopRootView() }" in app
assert "struct PopHomeScreen: View" in journey
assert "popCreateFromVideo" in journey and "popResumeComic" in journey
assert "PopArtwork(kind: .hero)" in journey
assert "PopArtwork(kind: .cards, index: art)" in journey
assert "CGImageSourceCreateThumbnailAtIndex" in journey
assert "PopWorkCover.image(at: url)" in journey
assert "var canReview: Bool = false" in theme
assert 'Label("作品に保存"' in theme
# Scene quota is not the number of cards: 12 scenes with up to 3 combined
# pin-card notes each, no card loss or fake separate panels.
capacity=(root / "ios/COMICPOP/MangaSceneCapacity.swift").read_text(encoding="utf-8")
capacityTests=(root / "tests/modelTests.swift").read_text(encoding="utf-8")
assert "maxScenes=12" in capacity and "maxCardsPerScene=3" in capacity
assert "ScenePlan(pins:pins+[planned]).scenes" in capacity
assert store.count("MangaSceneCapacity.canInsert(")>=2
assert editor.count("MangaSceneCapacity.canInsert(")>=2
assert "MangaSceneCapacity.swift" in preflight
assert "Thirteen actual scenes" in capacityTests
assert "More than three cards" in capacityTests
assert "denseNotes=input.userNote.count>160" in drawingPrompt
assert "max:denseNotes ? 800 : 160" in drawingPrompt
assert "densePrompt.contains(longNotes)" in promptTests
print("PASS: active Rex home, lightweight gallery, safe scene navigation and combined note preservation")

# Simulator diagnostics must capture the actual production home, not only the
# welcome modal that obscures it on a clean install.
codemagic=(root / "codemagic.yaml").read_text(encoding="utf-8")
assert 'movikoma-welcome.png' in codemagic
assert 'movikoma-home.png' in codemagic
assert 'com.example.comicpop.dev -pop.didSeeWelcome YES' in codemagic
assert 'ios-unsigned-check:' in codemagic
assert 'ios-testflight-upload:' in codemagic
# Reinstalling a TestFlight build must not make a stored Keychain token
# appear missing simply because the text field is blank.
assert "store.tokenExists && !editingCredentials" in settings
assert "保存済みトークンで接続確認" in settings
assert "reconnectSavedCloudflare(account:selectedAccountID)" in settings
assert "CloudflareSetupPolicy.isValidAccountID(selectedAccountID)" in settings
assert "新しいトークンに変更" in settings
assert 'cfWorkersFreeConfirmed' in store
savedTokenReconnect=store.split("func reconnectSavedCloudflare(account candidate:String) async -> Bool {",1)[1].split("func disconnect()",1)[0]
assert "CloudflareCredentialVault.load()" in savedTokenReconnect
assert "CloudflareAIService.verify(account:cleanAccount,token:savedToken)" in savedTokenReconnect
assert "CloudflareCredentialVault.save(" not in savedTokenReconnect
assert 'UserDefaults.standard.set(cleanAccount,forKey:"cfAccountId")' in savedTokenReconnect
assert "APIトークンはiPhone Keychainに保存済み。再入力は不要です。" in popui
# The shipped root must use the first-launch one-time setup (not a
# decorative settings screen), and all AI entry paths must honor saved credentials.
onboarding=(root / "ios/COMICPOP/PopCloudflareOnboarding.swift").read_text(encoding="utf-8")
policy=(root / "ios/COMICPOP/CloudflareSetupPolicy.swift").read_text(encoding="utf-8")
security=(root / "ios/COMICPOP/Security.swift").read_text(encoding="utf-8")
setupTests=(root / "tests/cloudflareSetupPolicyTests.swift").read_text(encoding="utf-8")
assert 'pop.didCompleteCloudflareSetup' in popui
assert 'CloudflareSetupPolicy.shouldShowFirstRun(' in popui
assert 'PopCloudflareOnboarding(store:store)' in popui
assert 'if store.hasCloudflareSetup {' in popui
assert 'didCompleteCloudflareSetup=true' in popui
assert 'CloudflareSetupPolicy.shouldShowFirstRun(' in popui
assert 'PopWelcomeScreen {didSeeWelcome=true}' in popui
assert 'CloudflareSetupPolicy.mayGenerateWithAI(' in genre
assert 'var hasCloudflareSetup: Bool {' in store
assert 'isConnected=hasCloudflareSetup' in store
assert 'func connect(account candidate:String,token:String) async -> Bool' in store
saveConnect=store.split('func connect(account candidate:String,token:String) async -> Bool {',1)[1].split('func reconnectSavedCloudflare(',1)[0]
assert saveConnect.index('CloudflareAIService.verify(') < saveConnect.index('CloudflareCredentialVault.save(')
assert saveConnect.index('CloudflareCredentialVault.save(') < saveConnect.index('cloudflareAccount=cleanAccount')
assert 'SecItemUpdate(' in security
assert 'SecItemDelete(query as CFDictionary)' not in security.split('static func save(',1)[1].split('static func load()',1)[0]
assert '今は端末内のおためしで始める' in onboarding
assert 'CloudflareCredentialVault.load()' in savedTokenReconnect
assert 'reconnectSavedCloudflare(account:selectedAccountID)' in onboarding
assert 'CloudflareSetupPolicy.resolvedAccountID(' in onboarding
assert 'if !store.tokenExists {' in onboarding
assert 'CloudflareSetupPolicy.swift' in preflight and 'cloudflareSetupPolicyTests.swift' in preflight
assert 'A prior completed/declined setup never prompts again' in setupTests
assert '.navigationBarTitleDisplayMode(.inline)' in settings
assert 'askDisconnect=true' in settings and 'isPresented:$askDisconnect' in settings
assert '保存済み情報' in settings or '以前の設定を自動で使います' in settings
# The manga IMAGE must reflect the source VIDEO, not a speculative
# AI screenplay or a previously hallucinated manga panel.
sourceLock=(root / "ios/COMICPOP/MangaSourceFidelityPolicy.swift").read_text(encoding="utf-8")
distancePolicy=(root / "ios/COMICPOP/MangaFidelityDistancePolicy.swift").read_text(encoding="utf-8")
visionGuard=(root / "ios/COMICPOP/MangaVisualFidelityGuard.swift").read_text(encoding="utf-8")
drawingPrompt=(root / "ios/COMICPOP/MangaDrawingPrompt.swift").read_text(encoding="utf-8")
assert 'pop.generation.sourceLocked.v1' in sourceLock
assert '?? true' in sourceLock and 'NO substitute person' in sourceLock
assert 'sourceLocked:Bool = false' in drawingPrompt
assert 'if sourceLocked {' in drawingPrompt
assert 'MangaSourceFidelityPolicy.lockedSourceRule' in drawingPrompt
assert 'sourceLocked:sourceLocked' in ai
assert 'MangaSourceFidelityPolicy.useEarlierMangaAsVisualReference(locked:sourceLocked)' in ai
assert 'for maximumSide in [496.0,448.0,384.0]' in ai
assert 'jpeg.count<680_000' in ai
assert 'MangaSourceFidelityPolicy.sourceLocked()' in ai
assert 'MangaSourceFidelityPolicy.sourceLocked()' in store
assert 'MangaVisualFidelityGuard.protectedImage(' in store
assert 'MangaFidelityDistancePolicy.isUnreliable(' in visionGuard
assert 'VNGenerateImageFeaturePrintRequest()' in visionGuard
assert 'OfflineComicFilter.render(original,style:style,colorMode:colorMode)' in visionGuard
assert 'var fidelityFallbacks=0' in store
assert 'func chooseSourceFaithfulComic(_ id:UUID) async' in store
assert 'store.chooseSourceFaithfulComic(id)' in review
assert '元動画に忠実な漫画加工（AI追加消費なし）' in review
assert '@AppStorage("pop.generation.sourceLocked.v1") private var sourceLocked = true' in genre
assert '元動画に忠実' in genre
assert 'NEVER invent a new person' in observations
assert 'mangaSourceFidelityPolicyTests.swift' in preflight
assert 'mangaFidelityDistanceTests.swift' in preflight
assert 'sourceLocked:true' in (root / "tests/mangaDrawingPromptTests.swift").read_text(encoding="utf-8")
# AI-generated words may look like Japanese while being nonsensical.
# They are NEVER auto-lettered as final manga without explicit user review.
visibleText=(root / "ios/COMICPOP/MangaVisibleLetteringPolicy.swift").read_text(encoding="utf-8")
visibleTests=(root / "tests/mangaVisibleLetteringPolicyTests.swift").read_text(encoding="utf-8")
storyEditor=(root / "ios/COMICPOP/PopStoryboardDraft.swift").read_text(encoding="utf-8")
assert 'var reviewedCaption: String? = nil' in story
assert 'var reviewedDialogue: String? = nil' in story
assert 'approved.reviewedCaption=approved.caption' in store
assert 'approved.reviewedDialogue=approved.dialogue' in store
assert 'MangaVisibleLetteringPolicy.caption(' in store
assert 'MangaVisibleLetteringPolicy.dialogue(' in store
assert 'caption:visible.caption,dialogue:visible.dialogue' in store
assert 'func useOnlyVerifiedLettering()' in store
assert 'store.useOnlyVerifiedLettering()' in review
assert '未確認のAI日本語を非表示（無料）' in review
assert 'AIが考えた日本語は下書きです' in storyEditor
assert '日本語：確認済み・漫画に印字' in storyEditor
assert 'reviewed:nil,originalNote:""' in visibleTests
assert 'mangaVisibleLetteringPolicyTests.swift' in preflight
assert 'MangaJapaneseLettering.clean' in visibleText
assert 'VNRecognizeTextRequest()' in visionGuard
assert 'VNDetectTextRectanglesRequest()' in visionGuard
assert 'request.reportCharacterBoxes=true' in visionGuard
assert 'MangaFidelityDistancePolicy.hasUnexpectedTextRegions(' in visionGuard
assert 'static func hasUnexpectedTextRegions(' in distancePolicy
assert 'even unreadable AI pseudo-kanji' in (root / "tests/mangaFidelityDistanceTests.swift").read_text(encoding="utf-8")
assert '絵の中の偽文字を除去' in review
assert 'store.chooseSourceFaithfulComic(panel.id)' in review
assert 'MangaFidelityDistancePolicy.hasUnexpectedText(' in visionGuard
assert 'static func hasUnexpectedText(' in distancePolicy
assert 'hasUnexpectedText(' in (root / "tests/mangaFidelityDistanceTests.swift").read_text(encoding="utf-8")
print("PASS: AI Japanese is draft-only until user approval; saved manga can hide AI gibberish without new Cloudflare calls")

print("PASS: original video retained as only source image, AI semantic drift safely replaced, and recoverable faithful manga")

print("PASS: one-time Rex Cloudflare setup, persisted Keychain reuse, safe replacement, offline skip and AI entry gates")

print("PASS: saved Cloudflare Keychain token reconnects without re-entry, and explicit Free confirmation persists")

print("PASS: one-shot Codemagic QA captures both first launch and active Rex home")
