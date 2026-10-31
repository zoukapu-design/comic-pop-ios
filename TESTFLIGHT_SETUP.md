# COMIC POP! — TestFlight preparation (2026-10-31)

The **unsigned simulator build has already succeeded**. The next step is a signed iPhone IPA. This repository has two Codemagic workflows:
- `ios-unsigned-check`: the known-good, unsigned Simulator build; unchanged.
- `ios-signed-ipa`: manual Apple Distribution signing and IPA export; **no publishing to TestFlight or App Store**.

## Before starting the signed workflow

1. In [Apple Developer Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list), register a **unique explicit iOS App ID** for COMIC POP!. Pick a stable bundle ID (for example `com.yourdomain.comicpop`), and ensure it does **not** already belong to another app. The ID is not configured in the Git repository and must be supplied at build time.
2. In [App Store Connect](https://appstoreconnect.apple.com/apps), create **New App** with name `COMIC POP!`, platform iOS, the **same bundle ID**, and a unique SKU. App Store publication is NOT required for TestFlight.
3. In [App Store Connect > Users and Access > Integrations](https://appstoreconnect.apple.com/access/integrations), create a **dedicated API key** authorized to manage builds (Codemagic recommends App Manager). Save its .p8 **privately**; do not send it in chat, screenshots or commit it to Git.
4. Codemagic > app `comic-pop-ios` > Environment variables: create group `ios_config` with one normal variable `BUNDLE_ID` equal to the exact registered Apple ID.
5. In the Codemagic app's Environment variables, create group `appstore_credentials`, with the following **Secret** variables:
   - `APP_STORE_CONNECT_ISSUER_ID`
   - `APP_STORE_CONNECT_KEY_IDENTIFIER`
   - `APP_STORE_CONNECT_PRIVATE_KEY` (content of the .p8 private key)
   - `CERTIFICATE_PRIVATE_KEY` (long-lived RSA PEM private key used to create/reuse Apple Distribution signing certificate; requires a secure source, e.g. the private key of a certificate your team manages)
   Alternative to manually managing the PEM: the official Codemagic UI supports stored signing identities; that is a separate configuration path and should not be mixed into this YAML without adjusting its code-signing steps.
6. Confirm your Apple Developer Program is active and that the App Store Connect API key has permission for the selected Apple team.

## Signed build

Codemagic > `comic-pop-ios` > Start new build > branch `main` > workflow `ios-signed-ipa`. It validates inputs, runs the Swift model tests, inserts your bundle ID **only into a temporary build copy**, assigns a build number, obtains Apple Distribution profiles, and exports an IPA.

**The workflow does not upload the IPA anywhere.** Do not pick it until the above Apple settings and secret variables are configured. Check the artifact list for the signed `.ipa` and the logs before enabling publishing.

## Then: TestFlight

Once signed IPA succeeds, enable Codemagic's App Store Connect publishing using the **exact integration reference name** selected in the Codemagic UI; do not guess the reference name. Configure `publishing.app_store_connect.auth: integration` and initially `submit_to_app_store: false`. The App Store Connect record must already exist. Upload the IPA, wait for processing, then add yourself as an internal TestFlight tester. Do not start App Store review.

Apple and Codemagic official references:
- https://docs.codemagic.io/yaml-code-signing/alternative-code-signing-methods/
- https://docs.codemagic.io/yaml-publishing/app-store-connect/
- https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/
- https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/

## Security

Never print environment variables into build logs, share .p8/PEM keys, commit certificates/tokens, or put Cloudflare API tokens in Git. A **successful Simulator build** does not imply a signed IPA or successful TestFlight processing.

## Initial iPhone smoke test

- Select a video and insert a card.
- Switch to a different video; ensure earlier pin images disappear but My Deck remains.
- Insert 5 cards; verify every pinned scene is kept and spreads over two pages.
- Connect only your own Cloudflare Workers **Free** account for small test generations. Verify actual AI output against original frames.
