#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Asset gate: the approved mascot PNG is indexed (color type 3), not RGBA.
# Convert losslessly to truecolor RGB (type 2) before verify_sources.py and XcodeGen.
python3 "$ROOT/tests/normalize_app_icon.py" "$ROOT/ios/COMICPOP/Assets.xcassets/AppIcon.appiconset/app-icon.png"
BIN="$(mktemp)"
trap 'rm -f "$BIN"' EXIT
swiftc "$ROOT/ios/COMICPOP/Models.swift" "$ROOT/tests/modelTests.swift" -o "$BIN"
"$BIN" "$ROOT/ios/COMICPOP/Resources/cards.json"
# Validate all-pin completion, ordering, and quota-safe recovery before iOS build.
swiftc "$ROOT/ios/COMICPOP/GenerationIntegrity.swift" "$ROOT/tests/generationIntegrityTests.swift" -o "$BIN"
"$BIN"
for source in "$ROOT"/ios/COMICPOP/*.swift; do swiftc -frontend -parse "$source"; done
python3 "$ROOT/tests/verify_sources.py"

python3 "$ROOT/tests/verify_ui_reference.py"
