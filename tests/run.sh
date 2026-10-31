#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$(mktemp)"
trap 'rm -f "$BIN"' EXIT
swiftc "$ROOT/ios/COMICPOP/Models.swift" "$ROOT/tests/modelTests.swift" -o "$BIN"
"$BIN" "$ROOT/ios/COMICPOP/Resources/cards.json"
for source in "$ROOT"/ios/COMICPOP/*.swift; do swiftc -frontend -parse "$source"; done
python3 "$ROOT/tests/verify_sources.py"
