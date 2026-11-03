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
assert "WindowGroup { MovikomaRootView() }" in app
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
print("PASS: MOVIKOMA native editor, Rex card art, genres, timeline, manga preview, works and settings")
