# COMIC POP! iOS v2.1 — SwiftUI native technical prototype
2026-10-31 / iPhone iOS 17.0+

## This is a native iOS codebase, not a wrapper of the Vercel website

Main features implemented at source-code level:
- Video from Photos (PhotosPicker) or Files (fileImporter) copied into the app sandbox; custom playhead slider with ±1s and ±5s seek.
- Insert any of 84 pin cards while watching a video. A frame is captured at each pin's timestamp using AVFoundation and stored locally per pin.
- Switching videos removes **old video's pins and captured frames**, but keeps named decks and saved works.
- Multiple decks, with four initial presets, up to 20 decks and up to 12 cards per deck. Edit, move, remove, change active deck.
- Scene plan preserves each pin, including pins with identical timestamps. 4 panels per page; 5 pins -> 2 pages.
- Image editing via **the current user's own Cloudflare Workers AI** account and FLUX.2 klein 4B. iPhone -> Cloudflare REST API directly. No developer account, Vercel proxy, intermediate Colab files or paid API fallback.
- API token in the iOS Keychain (`ThisDeviceOnly`); Account ID in local device preferences. It is never put in the saved comics or the outgoing PNG.
- Preview original and AI-redrawn frames side by side; warn when distinct source frames have unusually similar generated frames; select original for individual panels if needed.
- Multi-page manga page images and local saved works; iOS Share Sheet for exported PNG pages.
- No ads, in-app purchases or automatic billing in this technical prototype.

## Changes in v2.1
- Added video-session and pin-revision invalidation: an asynchronous AVFoundation capture or AI result from an older video cannot be appended after changing the video.
- Added Codemagic test gate and persistent build log artifact.
- Explicit Cloudflare Workers Paid caution in UI, even though no paid API fallback exists.

## Important limitations
- **Not compiled with Apple Xcode here:** Linux Swift parser + shared Foundation model unit tests pass, but SwiftUI/UIKit compilation, iPhone camera/Photos APIs, Keychain and on-device generation are **unverified** until a Codemagic build and iPhone TestFlight test succeeds.
- A Cloudflare token can be valid but not authorized for the chosen Account ID/model. Account plan cannot be verified by the app. Users should only connect their own **Workers Free** plan. Workers Paid accounts may incur Cloudflare charges.
- The current account-connection screen still asks for a technical API token. A user-friendly Cloudflare OAuth flow requires registering an OAuth client, callback verification and a security review; **not implemented**.
- AI scene consistency cannot be guaranteed by text prompts alone. The source remains visible in the review. ControlNet/structure-based models may be needed for strict pose or scene preservation.
- `com.example.comicpop.dev` is a **placeholder bundle ID**. Replace with your real Apple App Identifier before device signing.
- An Apple developer certificate/Apple account must be configured by the project owner before TestFlight distribution. No build or submission has been triggered in your account.
- App Store release requires privacy disclosures, legal review of AI model licenses/terms, User Generated Content policies if shared, token permission review, an AdMob integration and privacy consent where applicable.

## Build on Windows via Codemagic
1. Create a **private GitHub repository** for COMIC POP! or use your dedicated one, and commit the contents of this directory (with `codemagic.yaml` at repository root).
2. Connect the repo to Codemagic and select the `ios-unsigned-check` workflow.
3. Codemagic installs `xcodegen`, generates `ios/COMICPOP.xcodeproj`, then runs an **unsigned iOS Simulator build**. This is the compilation gate; resolve any build errors before signing.
4. Replace the placeholder bundle ID in `ios/project.yml`, then configure App Store Connect + code signing in Codemagic. Create a signed iOS build and distribute through TestFlight.
5. On iPhone: import a short video; insert 3 cards; switch to another video and confirm old pins disappear; verify deck remains; use a personal Cloudflare Workers Free token; generate one frame; inspect source vs output; generate 5 cards and confirm 2 pages; save/export.

## Files
- `ios/project.yml`: XcodeGen project configuration, no committed `.xcodeproj` required.
- `ios/COMICPOP`: complete SwiftUI application code, catalog and AppIcon asset.
- `codemagic.yaml`: unsigned first compile pipeline. Does **not** publish to TestFlight without explicit signing configuration.
- `tests/modelTests.swift`: Foundation-model tests runnable with Linux Swift; see `tests/run.sh`.

## Revenue plan (not implemented yet)
Free iOS app / personal Cloudflare Workers Free / Google AdMob. Keep all ads **off the video editor, pin cards and generation progress screens**. Candidate placements are the completed works browser and optional rewarded decoration (not GPU quota). Integrate the AdMob iOS SDK only after creating an approved publisher account, privacy policy, ATT/consent choices and using test ad units for development.

## v2.1.1 GitHub upload preparation
- First commit to private GitHub can be done with the included upload script. The iOS code is unchanged except for a late-video-duration race fix.
- Before submitting to App Store, set a unique bundle identifier, verify Cloudflare credentials and the account subscription tier, and perform signed iPhone tests.
