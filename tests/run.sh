#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Asset gate: the approved mascot PNG is indexed (color type 3), not RGBA.
# Convert losslessly to truecolor RGB (type 2) before verify_sources.py and XcodeGen.
python3 "$ROOT/tests/normalize_app_icon.py" "$ROOT/ios/COMICPOP/Assets.xcassets/AppIcon.appiconset/app-icon.png"
BIN="$(mktemp)"
trap 'rm -f "$BIN"' EXIT
swiftc "$ROOT/ios/COMICPOP/CardSceneGrouping.swift" "$ROOT/ios/COMICPOP/Models.swift" \
  "$ROOT/ios/COMICPOP/MangaSceneCapacity.swift" "$ROOT/tests/modelTests.swift" -o "$BIN"
"$BIN" "$ROOT/ios/COMICPOP/Resources/cards.json"
# Validate all-pin completion, ordering, and quota-safe recovery before iOS build.
swiftc "$ROOT/ios/COMICPOP/GenerationIntegrity.swift" "$ROOT/tests/generationIntegrityTests.swift" -o "$BIN"
"$BIN"
# Cloudflare setup appears only once; saved credentials never ask for a token again.
swiftc "$ROOT/ios/COMICPOP/CloudflareSetupPolicy.swift" \
  "$ROOT/tests/cloudflareSetupPolicyTests.swift" -o "$BIN"
"$BIN"
# Data loss regression: a failed JSON encode/write must not corrupt saved pins.
swiftc "$ROOT/ios/COMICPOP/StudioAtomicPersistence.swift" "$ROOT/tests/studioAtomicPersistenceTests.swift" -o "$BIN"
"$BIN"
# Changing genre or colour must never silently delete an unsaved manga.
swiftc "$ROOT/ios/COMICPOP/MangaAppearanceChangePolicy.swift" "$ROOT/tests/mangaAppearanceChangePolicyTests.swift" -o "$BIN"
"$BIN"
# Card/video changes require explicit consent if an AI draft or image exists.
swiftc "$ROOT/ios/COMICPOP/MangaDraftEditGuard.swift" \
  "$ROOT/tests/mangaDraftEditGuardTests.swift" -o "$BIN"
"$BIN"
# The genre screen must open an already completed manga without rerunning AI,
# and resume only missing panels after a partial failure.
swiftc "$ROOT/ios/COMICPOP/MangaGenerationRoute.swift" "$ROOT/tests/mangaGenerationRouteTests.swift" -o "$BIN"
"$BIN"
# Default source-first mode is deterministic and never uses other AI panels
# as physical visual evidence. Runs entirely offline with no GPU quota.
swiftc "$ROOT/ios/COMICPOP/MangaSourceFidelityPolicy.swift" \
  "$ROOT/tests/mangaSourceFidelityPolicyTests.swift" -o "$BIN"
"$BIN"
# The AI output must not silently replace the filmed person or setting.
# The on-device fallback decision uses the same source-to-comic baseline.
swiftc "$ROOT/ios/COMICPOP/MangaFidelityDistancePolicy.swift" \
  "$ROOT/tests/mangaFidelityDistanceTests.swift" -o "$BIN"
"$BIN"
# Both creative and source-locked prompts must stay below 2400 characters.
swiftc "$ROOT/ios/COMICPOP/MangaSourceFidelityPolicy.swift" \
  "$ROOT/ios/COMICPOP/MangaDrawingPrompt.swift" \
  "$ROOT/tests/mangaDrawingPromptTests.swift" -o "$BIN"
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
# Do not silently consume a second free AI request after malformed visual
# model output, temporary server errors, authentication or quota failures.
swiftc "$ROOT/ios/COMICPOP/MangaVisualStoryRetryPolicy.swift" \
  "$ROOT/tests/mangaVisualStoryRetryPolicyTests.swift" -o "$BIN"
"$BIN"
# Timeline pin markers: preserve all card IDs and group only overlapping UI positions.
swiftc "$ROOT/ios/COMICPOP/TimelinePinLayout.swift" "$ROOT/tests/timelinePinLayoutTests.swift" -o "$BIN"
"$BIN"
# Native Japanese text preflight, no Cloudflare usage.
swiftc "$ROOT/ios/COMICPOP/MangaJapaneseLettering.swift" "$ROOT/tests/mangaJapaneseLetteringTests.swift" -o "$BIN"
"$BIN"
# Do not print a production direction ("make it scary") as narration.
swiftc "$ROOT/ios/COMICPOP/MangaCaptionNotePolicy.swift" \
  "$ROOT/tests/mangaCaptionNotePolicyTests.swift" -o "$BIN"
"$BIN"
# AI-generated Japanese must remain an unprinted suggestion until reviewed;
# user-authored text is immediately safe to typeset natively.
swiftc "$ROOT/ios/COMICPOP/MangaJapaneseLettering.swift" \
  "$ROOT/ios/COMICPOP/MangaCaptionNotePolicy.swift" \
  "$ROOT/ios/COMICPOP/MangaVisibleLetteringPolicy.swift" \
  "$ROOT/tests/mangaVisibleLetteringPolicyTests.swift" -o "$BIN"
"$BIN"
# Inspect screenplay structure without API calls or image quota.
swiftc "$ROOT/ios/COMICPOP/MangaStoryQualityAudit.swift" "$ROOT/tests/mangaStoryQualityAuditTests.swift" -o "$BIN"
"$BIN"
# A recorded draft PNG may be missing even when JSON references it.
# Re-encode missing images and collect only abandoned temporary artwork.
swiftc "$ROOT/ios/COMICPOP/MangaDraftFilePolicy.swift" \
  "$ROOT/tests/mangaDraftFilePolicyTests.swift" -o "$BIN"
"$BIN"
# Validate restart-safe in-progress manga checkpoints, including story JSON
# round trips, exact pin identity, and rejection of unrelated video/style.
swiftc "$ROOT/ios/COMICPOP/CardSceneGrouping.swift" "$ROOT/ios/COMICPOP/Models.swift" \
  "$ROOT/ios/COMICPOP/MangaJapaneseLettering.swift" \
  "$ROOT/ios/COMICPOP/MangaCaptionNotePolicy.swift" \
  "$ROOT/ios/COMICPOP/MangaNarrativeDirector.swift" "$ROOT/ios/COMICPOP/MangaStory.swift" \
  "$ROOT/ios/COMICPOP/MangaDraftCheckpoint.swift" \
  "$ROOT/tests/mangaDraftCheckpointTests.swift" -o "$BIN"
"$BIN"
# Verify exactly one story beat per inserted card and natural Japanese captions.
swiftc "$ROOT/ios/COMICPOP/MangaJapaneseLettering.swift" "$ROOT/ios/COMICPOP/MangaCaptionNotePolicy.swift" "$ROOT/ios/COMICPOP/MangaNarrativeDirector.swift" "$ROOT/ios/COMICPOP/MangaStory.swift" "$ROOT/tests/mangaStoryTests.swift" -o "$BIN"
"$BIN"
swiftc "$ROOT/ios/COMICPOP/MangaJapaneseLettering.swift" "$ROOT/ios/COMICPOP/MangaCaptionNotePolicy.swift" "$ROOT/ios/COMICPOP/MangaNarrativeDirector.swift" "$ROOT/ios/COMICPOP/MangaStory.swift" "$ROOT/tests/mangaNarrativeDirectorTests.swift" -o "$BIN"
"$BIN"
for source in "$ROOT"/ios/COMICPOP/*.swift; do swiftc -frontend -parse "$source"; done
python3 "$ROOT/tests/verify_sources.py"

python3 "$ROOT/tests/verify_ui_reference.py"
