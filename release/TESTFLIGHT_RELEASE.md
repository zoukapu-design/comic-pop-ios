# ムビコマ TestFlight release trigger

- Source: `feat/movikoma-rex-reference-ui` / `61c8b6fe7a9adabfd452b7da78cae3f3b81b3d9a`
- Trigger: `ios-testflight-upload` on GitHub push to `release/testflight`
- Goal: App Store Connect/TestFlight upload (internal testing)
- Build ID: Codemagic `PROJECT_BUILD_NUMBER` increments automatically
- iOS bundle ID: `com.zoukapu.comicpop`
- App Store external release: disabled
- Beta review submission: disabled (no accidental external beta-review request)
- Existing Codemagic webhook and Apple distribution integration required.

Created to request exactly one TestFlight release build from GitHub.
