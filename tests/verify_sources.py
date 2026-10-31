"""CI preflight using Python standard library only (works on clean Codemagic macOS)."""
from pathlib import Path
import json
import plistlib
import struct

root = Path(__file__).resolve().parents[1]
src = root / "ios" / "COMICPOP"
cards = json.loads((src / "Resources" / "cards.json").read_text(encoding="utf-8"))
assert len(cards) == 84 and len({c["id"] for c in cards}) == 84
assert all(c["title"] and c["category"] for c in cards)

api = (src / "VideoAndAI.swift").read_text(encoding="utf-8")
store = (src / "StudioStore.swift").read_text(encoding="utf-8")
ui = (src / "StudioUI.swift").read_text(encoding="utf-8")
assert "https://api.cloudflare.com/client/v4" in api
assert "comic-pop-preview.vercel.app" not in api
assert "input_image_0" in api and "multipart/form-data" in api
assert (src / "Security.swift").read_text().count("kSecClassGenericPassword") >= 3
assert "CloudflareCredentialVault.save(token)" in store
assert "guard capturedSession == videoSession && capturedReset == pinsResetEpoch" in store
assert "startingSession == videoSession && startingRevision == pinsRevision" in store
assert "data.pins=[]" in store
assert "iOS v2.1" in ui

ci = (root / "codemagic.yaml").read_text(encoding="utf-8")
project = (root / "ios" / "project.yml").read_text(encoding="utf-8")
assert "ios-unsigned-check:" in ci and "CODE_SIGNING_ALLOWED=NO build" in ci
assert "tests/run.sh" in ci and "ios-build.log" in ci
assert "COMICPOP:" in project and "Resources/cards.json" in project

with (src / "Info.plist").open("rb") as f:
    info = plistlib.load(f)
assert info["CFBundleName"] == "COMICPOP"

icon = (src / "Assets.xcassets" / "AppIcon.appiconset" / "app-icon.png").read_bytes()
assert icon[:8] == b"\x89PNG\r\n\x1a\n"
assert struct.unpack(">II", icon[16:24]) == (1024, 1024)
assert icon[25] == 2, "App Store icon must not have an alpha channel"
print("PASS: 84 cards, personal Cloudflare, stale-task guards, unsigned CI, plist and app icon")
