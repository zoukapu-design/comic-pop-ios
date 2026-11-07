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
assert "Cloudflare AIで漫画化" in genre
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
assert 'title:data.workTitle.isEmpty ? "ムビコマ"' in store
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
print("PASS: Rex onboarding, video picker/confirm, pin guard, deck reorder, PDF share, generated-panel editing")
print("PASS: MOVIKOMA 3 reference-faithful native screens, real Rex sprite assets and connected interactions")
