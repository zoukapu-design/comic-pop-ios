#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Asset gate: the approved mascot PNG is indexed (color type 3), not RGBA.
# Convert losslessly to truecolor RGB (type 2) before verify_sources.py and XcodeGen.
python3 "$ROOT/tests/normalize_app_icon.py" "$ROOT/ios/COMICPOP/Assets.xcassets/AppIcon.appiconset/app-icon.png"
BIN="$(mktemp)"
trap 'rm -f "$BIN"' EXIT
swiftc "$ROOT/ios/COMICPOP/CardSceneGrouping.swift" "$ROOT/ios/COMICPOP/Models.swift" "$ROOT/tests/modelTests.swift" -o "$BIN"
"$BIN" "$ROOT/ios/COMICPOP/Resources/cards.json"
# Validate all-pin completion, ordering, and quota-safe recovery before iOS build.
swiftc "$ROOT/ios/COMICPOP/GenerationIntegrity.swift" "$ROOT/tests/generationIntegrityTests.swift" -o "$BIN"
"$BIN"
# Data loss regression: a failed JSON encode/write must not corrupt saved pins.
swiftc "$ROOT/ios/COMICPOP/StudioAtomicPersistence.swift" "$ROOT/tests/studioAtomicPersistenceTests.swift" -o "$BIN"
"$BIN"
# The genre screen must open an already completed manga without rerunning AI,
# and resume only missing panels after a partial failure.
swiftc "$ROOT/ios/COMICPOP/MangaGenerationRoute.swift" "$ROOT/tests/mangaGenerationRouteTests.swift" -o "$BIN"
"$BIN"
# Verify emotional card fusion does not inject horror into unrelated scenes.
swiftc "$ROOT/ios/COMICPOP/MangaCardFusion.swift" "$ROOT/tests/mangaCardFusionTests.swift" -o "$BIN"
"$BIN"
# Pick prior and stable opening artwork references without duplicate images.
swiftc "$ROOT/ios/COMICPOP/MangaReferencePolicy.swift" "$ROOT/tests/mangaReferencePolicyTests.swift" -o "$BIN"
"$BIN"
# Repeated drawings must be found across page boundaries, excluding replay cards.
swiftc "$ROOT/ios/COMICPOP/MangaArtworkUniqueness.swift" "$ROOT/tests/mangaArtworkUniquenessTests.swift" -o "$BIN"
"$BIN"
# Every stored comic page must have distinct nonempty PNG content.
swiftc "$ROOT/ios/COMICPOP/MangaPageIntegrity.swift" "$ROOT/tests/mangaPageIntegrityTests.swift" -o "$BIN"
"$BIN"
# Pure-Foundation Cloudflare text envelope regression (no network and no credits).
swiftc "$ROOT/ios/COMICPOP/CloudflareStoryResponse.swift" "$ROOT/tests/cloudflareStoryResponseTests.swift" -o "$BIN"
"$BIN"
# Timeline pin markers: preserve all card IDs and group only overlapping UI positions.
swiftc "$ROOT/ios/COMICPOP/TimelinePinLayout.swift" "$ROOT/tests/timelinePinLayoutTests.swift" -o "$BIN"
"$BIN"
# Native Japanese text preflight, no Cloudflare usage.
swiftc "$ROOT/ios/COMICPOP/MangaJapaneseLettering.swift" "$ROOT/tests/mangaJapaneseLetteringTests.swift" -o "$BIN"
"$BIN"
# Inspect screenplay structure without API calls or image quota.
swiftc "$ROOT/ios/COMICPOP/MangaStoryQualityAudit.swift" "$ROOT/tests/mangaStoryQualityAuditTests.swift" -o "$BIN"
"$BIN"
# Verify exactly one story beat per inserted card and natural Japanese captions.
swiftc "$ROOT/ios/COMICPOP/MangaJapaneseLettering.swift" "$ROOT/ios/COMICPOP/MangaNarrativeDirector.swift" "$ROOT/ios/COMICPOP/MangaStory.swift" "$ROOT/tests/mangaStoryTests.swift" -o "$BIN"
"$BIN"
swiftc "$ROOT/ios/COMICPOP/MangaJapaneseLettering.swift" "$ROOT/ios/COMICPOP/MangaNarrativeDirector.swift" "$ROOT/ios/COMICPOP/MangaStory.swift" "$ROOT/tests/mangaNarrativeDirectorTests.swift" -o "$BIN"
"$BIN"
for source in "$ROOT"/ios/COMICPOP/*.swift; do swiftc -frontend -parse "$source"; done
python3 "$ROOT/tests/verify_sources.py"

python3 "$ROOT/tests/verify_ui_reference.py"
