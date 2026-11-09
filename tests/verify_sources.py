"""CI preflight using Python standard library only (works on clean Codemagic macOS)."""
from pathlib import Path
import json
import plistlib
import struct
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
src = root / "ios" / "COMICPOP"
cards = json.loads((src / "Resources" / "cards.json").read_text(encoding="utf-8"))
assert len(cards) == 85 and len({c["id"] for c in cards}) == 85
assert all(c["title"] and c["category"] for c in cards)

api = (src / "VideoAndAI.swift").read_text(encoding="utf-8")
store = (src / "StudioStore.swift").read_text(encoding="utf-8")
ui = (src / "StudioUI.swift").read_text(encoding="utf-8")
assert "https://api.cloudflare.com/client/v4" in api
assert "comic-pop-preview.vercel.app" not in api
assert "input_image_0" in api and "multipart/form-data" in api
assert (src / "Security.swift").read_text().count("kSecClassGenericPassword") >= 3
assert "CloudflareCredentialVault.save(token)" in store
assert "capturedSession == videoSession &&" in store and "capturedReset == pinsResetEpoch &&" in store and "capturedRevision == pinsRevision" in store
assert "startingSession == videoSession && startingRevision == pinsRevision" in store
assert "data.pins=[]" in store
assert "iOS v2.1" in ui

# Check Swift's whitespace-sensitive boolean/unary-operator combinations before paid CI build time.
# swiftc -frontend -parse alone does not flag these.
import re
for swift_source in src.glob("*.swift"):
    content = swift_source.read_text(encoding="utf-8")
    assert not re.search(r"(?:\|\||&&)!", content), f"Missing whitespace before ! in {swift_source.name}"

ci = (root / "codemagic.yaml").read_text(encoding="utf-8")
project = (root / "ios" / "project.yml").read_text(encoding="utf-8")
assert "ios-unsigned-check:" in ci and "CODE_SIGNING_ALLOWED=NO build" in ci
assert "tests/run.sh" in ci and "ios-build.log" in ci
assert "COMICPOP:" in project and "Resources/cards.json" in project

with (src / "Info.plist").open("rb") as f:
    info = plistlib.load(f)
assert info["CFBundleName"] == "COMICPOP"

# App Store Connect error 90475/90474 regression guard.
# XcodeGen regenerates Info.plist, so verify BOTH generated-property source and storyboard.
expected_orientations = {
    "UIInterfaceOrientationPortrait",
    "UIInterfaceOrientationPortraitUpsideDown",
    "UIInterfaceOrientationLandscapeLeft",
    "UIInterfaceOrientationLandscapeRight",
}
assert info["UILaunchStoryboardName"] == "LaunchScreen"
assert set(info["UISupportedInterfaceOrientations"]) == expected_orientations
assert info["UISupportedInterfaceOrientations~iphone"] == ["UIInterfaceOrientationPortrait"]
assert "UILaunchStoryboardName: LaunchScreen" in project, "XcodeGen must generate the launch storyboard property"
for orientation in sorted(expected_orientations):
    assert f"- {orientation}" in project, f"XcodeGen missing iPad orientation: {orientation}"
assert "UISupportedInterfaceOrientations~iphone" in project
assert "NSPhotoLibraryUsageDescription:" in project
storyboard = src / "LaunchScreen.storyboard"
assert storyboard.exists(), "LaunchScreen.storyboard must be included in app target"
xml = ET.parse(storyboard).getroot()
assert xml.attrib.get("launchScreen") == "YES", "Storyboard must be designated as a launch screen"
assert xml.attrib.get("initialViewController"), "Storyboard must have a launch controller"
assert "LaunchScreen.storyboard" not in project.split("excludes:", 1)[-1].split("info:", 1)[0], "Launch screen cannot be excluded from target"

icon = (src / "Assets.xcassets" / "AppIcon.appiconset" / "app-icon.png").read_bytes()
assert icon[:8] == b"\x89PNG\r\n\x1a\n"
assert struct.unpack(">II", icon[16:24]) == (1024, 1024)
assert icon[24] == 8 and icon[25] == 2, "App Store icon must be 8-bit truecolor RGB PNG (not palette PNG or RGBA)"
print("PASS: 85 cards, personal Cloudflare, stale-task guards, unsigned CI, plist and app icon")
